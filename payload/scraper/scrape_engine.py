#!/usr/bin/env python3
"""Resumable bulk scraping engine: millions of URLs, one tidy project folder.

  crawl   python scrape_engine.py crawl  <project_dir> --urls urls.txt [options]
  status  python scrape_engine.py status <project_dir>
  export  python scrape_engine.py export <project_dir> --format ndjson|csv|parquet

Project folder:
  state.db        URL queue, results and extracted data (SQLite); survives a crash or Ctrl+C
  raw/ab/<hash>.gz  raw responses, compressed, stored once per distinct content
  exports/        exported data
  manifest.json   parameters and counters of the last run

Downloaded content is only ever stored, never executed.
"""
import argparse
import asyncio
import csv
import gzip
import hashlib
import json
import re
import sqlite3
import sys
import time
import urllib.robotparser
from pathlib import Path
from urllib.parse import urldefrag, urljoin, urlsplit

SCHEMA = """
CREATE TABLE IF NOT EXISTS urls(
  url TEXT PRIMARY KEY, depth INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'pending',
  tries INTEGER NOT NULL DEFAULT 0, not_before REAL NOT NULL DEFAULT 0, http_status INTEGER,
  content_type TEXT, content_hash TEXT, bytes INTEGER, fetched_at REAL, error TEXT);
CREATE INDEX IF NOT EXISTS idx_pending ON urls(not_before) WHERE status='pending';
CREATE TABLE IF NOT EXISTS items(url TEXT PRIMARY KEY, data TEXT NOT NULL);
"""
RETRYABLE = {408, 425, 429, 500, 502, 503, 504}


def open_db(project: Path) -> sqlite3.Connection:
    project.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(project / "state.db", isolation_level=None)
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA synchronous=NORMAL")
    db.executescript(SCHEMA)
    return db


def clean_url(url: str) -> str | None:
    url = urldefrag(url.strip()).url
    return url if urlsplit(url).scheme in ("http", "https") and urlsplit(url).netloc else None


def extract(html: str, selectors: dict) -> dict:
    """Selector syntax: "h1", "a@href" for an attribute; a key ending in [] collects every match."""
    from selectolax.lexbor import LexborHTMLParser

    tree = LexborHTMLParser(html)
    out = {}
    for key, selector in selectors.items():
        css, _, attr = selector.partition("@")
        values = [(n.attributes.get(attr) if attr else n.text(strip=True)) for n in tree.css(css)]
        if key.endswith("[]"):
            out[key[:-2]] = values
        else:
            out[key] = values[0] if values else None
    return out


def links_of(html: str, base: str) -> list[str]:
    from selectolax.lexbor import LexborHTMLParser

    found = (urljoin(base, a.attributes.get("href") or "") for a in LexborHTMLParser(html).css("a[href]"))
    return [u for u in map(clean_url, found) if u]


class Crawler:
    def __init__(self, project: Path, args):
        self.project, self.args = project, args
        self.db = open_db(project)
        self.selectors = json.loads(Path(args.selectors).read_text("utf-8")) if args.selectors else {}
        self.follow = re.compile(args.follow) if args.follow else None
        self.hosts, self.robots = {}, {}
        self.active = 0
        self.fetched = 0
        self.started = time.time()

    def add(self, urls, depth=0):
        self.db.execute("BEGIN")
        self.db.executemany("INSERT OR IGNORE INTO urls(url, depth) VALUES(?, ?)", ((u, depth) for u in urls))
        self.db.execute("COMMIT")

    def claim(self):
        row = self.db.execute(
            "SELECT url, depth, tries FROM urls WHERE status='pending' AND not_before<=? LIMIT 1", (time.time(),)
        ).fetchone()
        if row:
            self.db.execute("UPDATE urls SET status='running' WHERE url=?", (row[0],))
        return row

    def host_state(self, host):
        if host not in self.hosts:
            self.hosts[host] = {
                "sem": asyncio.Semaphore(self.args.per_host),
                "lock": asyncio.Lock(),
                "next": 0.0,
                "delay": self.args.delay,
            }
        return self.hosts[host]

    async def allowed(self, client, url) -> bool:
        if self.args.ignore_robots:
            return True
        parts = urlsplit(url)
        origin = f"{parts.scheme}://{parts.netloc}"
        if origin not in self.robots:
            parser = urllib.robotparser.RobotFileParser()
            try:
                response = await client.get(origin + "/robots.txt")
                parser.parse(response.text.splitlines() if response.status_code == 200 else [])
            except Exception:
                parser.parse([])
            self.robots[origin] = parser
            crawl_delay = parser.crawl_delay(self.args.user_agent)
            if crawl_delay:
                state = self.host_state(parts.netloc)
                state["delay"] = max(state["delay"], float(crawl_delay))
        return self.robots[origin].can_fetch(self.args.user_agent, url)

    def store(self, body: bytes) -> str:
        digest = hashlib.sha256(body).hexdigest()
        path = self.project / "raw" / digest[:2] / f"{digest}.gz"
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            temp = path.with_suffix(".tmp")
            temp.write_bytes(gzip.compress(body, 5))
            temp.replace(path)
        return digest

    def fail(self, url, tries, error, http_status=None, retry_after=None):
        if tries + 1 < self.args.retries and (http_status is None or http_status in RETRYABLE):
            wait = retry_after if retry_after is not None else min(60, 2**tries)
            self.db.execute(
                "UPDATE urls SET status='pending', tries=?, not_before=?, http_status=?, error=? WHERE url=?",
                (tries + 1, time.time() + wait, http_status, error, url),
            )
        else:
            self.db.execute(
                "UPDATE urls SET status='failed', tries=?, http_status=?, error=? WHERE url=?",
                (tries + 1, http_status, error, url),
            )

    async def fetch(self, client, url, depth, tries):
        host = urlsplit(url).netloc
        if not await self.allowed(client, url):
            self.db.execute("UPDATE urls SET status='blocked_robots' WHERE url=?", (url,))
            return
        state = self.host_state(host)
        async with state["sem"]:
            async with state["lock"]:
                now = time.monotonic()
                wait = state["next"] - now
                state["next"] = max(now, state["next"]) + state["delay"]
            if wait > 0:
                await asyncio.sleep(wait)
            try:
                async with client.stream("GET", url) as response:
                    chunks, size = [], 0
                    async for chunk in response.aiter_bytes():
                        size += len(chunk)
                        if size > self.args.max_bytes:
                            raise ValueError(f"response over {self.args.max_bytes} bytes")
                        chunks.append(chunk)
                    body = b"".join(chunks)
            except Exception as exc:
                self.fail(url, tries, f"{type(exc).__name__}: {exc}")
                return

        code = response.status_code
        if code >= 400:
            header = response.headers.get("retry-after", "")
            self.fail(url, tries, f"HTTP {code}", code, float(header) if header.isdigit() else None)
            return

        digest = self.store(body)
        content_type = response.headers.get("content-type", "")
        if "html" in content_type or "xml" in content_type:
            html = body.decode(response.encoding or "utf-8", "replace")
            if self.selectors:
                data = extract(html, self.selectors)
                self.db.execute("INSERT OR REPLACE INTO items VALUES(?, ?)", (url, json.dumps(data, ensure_ascii=False)))
            if depth < self.args.depth:
                targets = links_of(html, str(response.url))
                if self.follow:
                    targets = [t for t in targets if self.follow.search(t)]
                elif not self.args.leave_host:
                    targets = [t for t in targets if urlsplit(t).netloc == host]
                self.add(targets, depth + 1)
        self.db.execute(
            "UPDATE urls SET status='done', tries=?, http_status=?, content_type=?, content_hash=?, bytes=?, fetched_at=?, error=NULL WHERE url=?",
            (tries + 1, code, content_type, digest, len(body), time.time(), url),
        )
        self.fetched += 1
        if self.fetched % 1000 == 0:
            rate = self.fetched / max(time.time() - self.started, 0.001)
            print(f"{self.fetched} pages, {rate:.0f}/s", file=sys.stderr, flush=True)

    async def worker(self, client):
        while True:
            row = self.claim()
            if row is None:
                pending = self.db.execute("SELECT 1 FROM urls WHERE status='pending' LIMIT 1").fetchone()
                if not pending and self.active == 0:
                    return
                await asyncio.sleep(0.05)
                continue
            self.active += 1
            try:
                await self.fetch(client, *row)
            except Exception as exc:
                # One bad page must not end a crawl of millions: record it as failed.
                self.db.execute(
                    "UPDATE urls SET status='failed', tries=tries+1, error=? WHERE url=?",
                    (f"{type(exc).__name__}: {exc}", row[0]),
                )
            finally:
                self.active -= 1

    async def run(self):
        import httpx

        # Anything still 'running' was interrupted by a previous stop: put it back in the queue.
        self.db.execute("UPDATE urls SET status='pending' WHERE status='running'")
        limits = httpx.Limits(max_connections=self.args.concurrency, max_keepalive_connections=self.args.concurrency)
        async with httpx.AsyncClient(
            http2=True, follow_redirects=True, timeout=self.args.timeout, limits=limits,
            headers={"User-Agent": self.args.user_agent},
        ) as client:
            await asyncio.gather(*(self.worker(client) for _ in range(self.args.concurrency)))
        write_manifest(self.project, self.db, vars(self.args), time.time() - self.started)


def counters(db) -> dict:
    return dict(db.execute("SELECT status, COUNT(*) FROM urls GROUP BY status").fetchall())


def write_manifest(project, db, params, seconds):
    manifest = {
        "finished_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "duration_seconds": round(seconds, 1),
        "parameters": {k: v for k, v in params.items() if k != "func"},
        "counters": counters(db),
        "items": db.execute("SELECT COUNT(*) FROM items").fetchone()[0],
        "raw_files_distinct": db.execute("SELECT COUNT(DISTINCT content_hash) FROM urls WHERE content_hash IS NOT NULL").fetchone()[0],
        "raw_bytes": db.execute("SELECT COALESCE(SUM(bytes), 0) FROM urls").fetchone()[0],
    }
    (project / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False, default=str), "utf-8")
    print(json.dumps({k: manifest[k] for k in ("counters", "items", "duration_seconds")}, ensure_ascii=False))


def export(project: Path, fmt: str) -> Path:
    db = open_db(project)
    target_dir = project / "exports"
    target_dir.mkdir(exist_ok=True)
    query = "SELECT u.url, u.http_status, u.fetched_at, i.data FROM items i JOIN urls u ON u.url = i.url ORDER BY u.url"
    ndjson = target_dir / "items.ndjson"
    with ndjson.open("w", encoding="utf-8") as out:
        for url, code, fetched, data in db.execute(query):
            out.write(json.dumps({"url": url, "http_status": code, "fetched_at": fetched, **json.loads(data)}, ensure_ascii=False) + "\n")
    if fmt == "ndjson":
        return ndjson
    if fmt == "parquet":
        from pyarrow import json as arrow_json, parquet

        target = target_dir / "items.parquet"
        parquet.write_table(arrow_json.read_json(ndjson), target, compression="zstd")
        return target
    target = target_dir / "items.csv"
    rows = [json.loads(line) for line in ndjson.open(encoding="utf-8")]  # shortcut: loads all rows in memory; use parquet above a few million rows
    fields = list(dict.fromkeys(k for row in rows for k in row))
    with target.open("w", newline="", encoding="utf-8-sig") as out:
        writer = csv.DictWriter(out, fields)
        writer.writeheader()
        writer.writerows({k: json.dumps(v, ensure_ascii=False) if isinstance(v, (list, dict)) else v for k, v in row.items()} for row in rows)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    crawl = commands.add_parser("crawl")
    crawl.add_argument("project", type=Path)
    crawl.add_argument("--urls", help="text file, one URL per line")
    crawl.add_argument("--selectors", help='JSON file, for example {"title":"h1","links[]":"a@href"}')
    crawl.add_argument("--concurrency", type=int, default=50, help="total simultaneous requests")
    crawl.add_argument("--per-host", type=int, default=4, help="simultaneous requests per site")
    crawl.add_argument("--delay", type=float, default=0.25, help="seconds between two requests to a site")
    crawl.add_argument("--retries", type=int, default=4)
    crawl.add_argument("--timeout", type=float, default=30)
    crawl.add_argument("--depth", type=int, default=0, help="link levels to follow")
    crawl.add_argument("--follow", help="only follow links matching this regex")
    crawl.add_argument("--leave-host", action="store_true", help="also follow links to other sites")
    crawl.add_argument("--max-bytes", type=int, default=50_000_000)
    crawl.add_argument("--ignore-robots", action="store_true")
    crawl.add_argument("--user-agent", default="CopilotArchitecteScraper/2.1")

    commands.add_parser("status").add_argument("project", type=Path)
    exporter = commands.add_parser("export")
    exporter.add_argument("project", type=Path)
    exporter.add_argument("--format", choices=["ndjson", "csv", "parquet"], default="ndjson")

    args = parser.parse_args()
    if args.command == "status":
        print(json.dumps(counters(open_db(args.project)), indent=2))
    elif args.command == "export":
        print(export(args.project, args.format))
    else:
        crawler = Crawler(args.project, args)
        if args.urls:
            with open(args.urls, encoding="utf-8") as file:
                crawler.add(u for u in map(clean_url, file) if u)
        try:
            asyncio.run(crawler.run())
        except KeyboardInterrupt:
            print("Stopped. Run the same command again to resume.", file=sys.stderr)


if __name__ == "__main__":
    main()
