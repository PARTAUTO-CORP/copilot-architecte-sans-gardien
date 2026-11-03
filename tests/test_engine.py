"""End-to-end test of scrape_engine.py against a local HTTP server. Run with the kit's venv Python."""
import http.server
import json
import sqlite3
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

ENGINE = Path(__file__).parent.parent / "payload" / "scraper" / "scrape_engine.py"
hits = {}


class Site(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def send(self, code, body, kind="text/html", extra=()):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        for key, value in extra:
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path
        hits[path] = hits.get(path, 0) + 1
        if path == "/robots.txt":
            self.send(200, "User-agent: *\nDisallow: /private\n", "text/plain")
        elif path == "/flaky" and hits[path] == 1:
            self.send(503, "busy", extra=[("Retry-After", "0")])
        elif path == "/missing":
            self.send(404, "no")
        elif path.startswith("/p/"):
            self.send(200, f"<h1>Page {path[3:]}</h1><span class=price>{path[3:]}</span><a href='/seen'>x</a>")
        elif path == "/same1" or path == "/same2":
            self.send(200, "<h1>Identical</h1>")
        else:
            self.send(200, f"<h1>{path}</h1><span class=price>1</span><a href='/leaf#top'>leaf</a><a href='https://other.invalid/x'>out</a>")


def engine(*args):
    done = subprocess.run([sys.executable, str(ENGINE), *map(str, args)], capture_output=True, text=True)
    assert done.returncode == 0, done.stderr
    return done.stdout


def rows(project, query):
    db = sqlite3.connect(project / "state.db")
    try:
        return db.execute(query).fetchall()
    finally:
        db.close()


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Site)
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_address[1]}"

with tempfile.TemporaryDirectory() as temp:
    temp = Path(temp)
    project = temp / "projet"
    urls = temp / "urls.txt"
    paths = ["/start", "/flaky", "/missing", "/private/secret", "/same1", "/same2"] + [f"/p/{i}" for i in range(300)]
    urls.write_text("\n".join(base + p for p in paths) + "\nnot-a-url\nftp://bad/x\n", "utf-8")
    selectors = temp / "sel.json"
    selectors.write_text(json.dumps({"title": "h1", "price": ".price", "links[]": "a@href"}), "utf-8")

    common = ["--selectors", selectors, "--delay", "0", "--per-host", "20", "--concurrency", "20", "--timeout", "5"]
    engine("crawl", project, "--urls", urls, "--depth", "1", "--follow", "/leaf", *common)

    status = dict(rows(project, "SELECT url, status FROM urls"))
    assert status[base + "/start"] == "done"
    assert status[base + "/flaky"] == "done", "503 must be retried"
    assert hits["/flaky"] == 2
    assert status[base + "/missing"] == "failed"
    assert hits["/missing"] == 1, "a 404 must not be retried"
    assert status[base + "/private/secret"] == "blocked_robots"
    assert "/private/secret" not in hits, "robots.txt must be honoured"
    assert base + "/leaf" in status, "matching link must be followed, fragment removed"
    assert not any("other.invalid" in u for u in status), "--follow must filter links"
    assert not any("ftp://" in u or "not-a-url" in u for u in status)
    # 300 /p/ pages + /start, /flaky, /same1, /same2 and the followed /leaf
    assert sum(1 for s in status.values() if s == "done") == 300 + 5

    # Extraction, including a missing field and a list
    item = json.loads(rows(project, f"SELECT data FROM items WHERE url='{base}/p/7'")[0][0])
    assert item["title"] == "Page 7" and item["price"] == "7" and item["links"] == ["/seen"]
    same = json.loads(rows(project, f"SELECT data FROM items WHERE url='{base}/same1'")[0][0])
    assert same["price"] is None, "a missing value stays empty"

    # Identical content is stored once
    h1 = rows(project, f"SELECT content_hash FROM urls WHERE url='{base}/same1'")[0][0]
    h2 = rows(project, f"SELECT content_hash FROM urls WHERE url='{base}/same2'")[0][0]
    assert h1 == h2
    assert len(list((project / "raw").rglob("*.gz"))) == rows(project, "SELECT COUNT(DISTINCT content_hash) FROM urls")[0][0]

    # Resume: an interrupted URL restarts, finished ones are not fetched again
    before = hits["/p/1"]
    db = sqlite3.connect(project / "state.db")
    db.execute("UPDATE urls SET status='running' WHERE url=?", (base + "/p/2",))
    db.commit()
    db.close()
    second = hits["/p/2"]
    engine("crawl", project, "--urls", urls, *common)
    assert hits["/p/1"] == before, "finished URL fetched again"
    assert hits["/p/2"] == second + 1, "interrupted URL not resumed"

    # Exports
    ndjson = Path(engine("export", project, "--format", "ndjson").strip())
    lines = ndjson.read_text("utf-8").splitlines()
    assert len(lines) == rows(project, "SELECT COUNT(*) FROM items")[0][0] and json.loads(lines[0])["url"]
    assert Path(engine("export", project, "--format", "csv").strip()).stat().st_size > 0
    parquet = Path(engine("export", project, "--format", "parquet").strip())
    from pyarrow import parquet as pq

    assert pq.read_metadata(parquet).num_rows == len(lines)

    manifest = json.loads((project / "manifest.json").read_text("utf-8"))
    assert manifest["counters"]["done"] >= 300 and "selectors" in manifest["parameters"]

server.shutdown()
print("RESULT: all engine tests passed")
