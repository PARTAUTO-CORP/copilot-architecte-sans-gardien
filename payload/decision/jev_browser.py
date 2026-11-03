"""Runs one browser goal with Jev Ultrafast and prints one JSON result line.

python jev_browser.py --url URL --goal "A narrow goal" [--show] [--my-chrome]
Exit code: 0 done, 1 blocked or error, 2 not configured.
"""

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULTS = {
    "TYPESAFE_MODEL": "jev-latest",
    "TEXT_MODEL_BASE_URL": "https://openrouter.ai/api/v1",
    "TEXT_MODEL": "inception/mercury-2.5",
    "TEXT_MODEL_REASONING": "none",
    "BU_NAME": "jev-copilot",
    "BH_TELEMETRY": "0",  # browser-harness sends usage data by default
}


def load_env(path):
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())
    for key, value in DEFAULTS.items():
        os.environ.setdefault(key, value)


def find_chrome():
    roots = (os.environ.get("PROGRAMFILES"), os.environ.get("PROGRAMFILES(X86)"), os.environ.get("LOCALAPPDATA"))
    for root in filter(None, roots):
        candidate = Path(root) / "Google/Chrome/Application/chrome.exe"
        if candidate.exists():
            return str(candidate)
    return shutil.which("chrome") or shutil.which("google-chrome") or shutil.which("chromium")


def start_chrome(show):
    """Own profile, so the agent never sees the user's accounts unless --my-chrome is given."""
    chrome = find_chrome()
    if not chrome:
        raise RuntimeError("Chrome not found")
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    args = [
        chrome,
        f"--remote-debugging-port={port}",
        f"--user-data-dir={HERE / 'chrome-profile'}",
        "--no-first-run",
        "--no-default-browser-check",
    ]
    process = subprocess.Popen(
        args + ([] if show else ["--headless=new"]) + ["about:blank"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    os.environ["BU_CDP_URL"] = f"http://127.0.0.1:{port}"
    return process


def run(url, goal, show=False, my_chrome=False):
    result = {"status": "error", "url": url, "title": None, "elapsed_ms": 0, "actions": [], "input_tokens": 0, "error": None}
    chrome = None if my_chrome else start_chrome(show)
    # After BU_CDP_URL and BU_NAME are set: browser-harness reads them when imported.
    from browser_harness.admin import restart_daemon
    from jev_ultrafast import Agent

    state = None
    try:
        with Agent(url, goal) as agent:
            state = agent.snapshot()
            for state in agent.run():
                pass
    except Exception as error:  # the caller needs a JSON verdict whatever went wrong
        result["error"] = str(error)
    finally:
        try:
            restart_daemon(os.environ["BU_NAME"])
        except Exception:
            pass
        if chrome:
            chrome.terminate()
    if state:
        # Typed values are left out: the output ends up in logs and reports.
        result.update(
            status=state["status"] if not result["error"] else "error",
            url=state["page"]["url"],
            title=state["page"]["title"],
            elapsed_ms=state["elapsed_ms"],
            actions=[{"action": h["action"], "kind": h["kind"]} for h in state["history"]],
            input_tokens=sum(h["usage"].get("input_tokens", 0) for h in state["history"]),
        )
    return result


def main():
    parser = argparse.ArgumentParser(description="Runs one browser goal with Jev Ultrafast.")
    parser.add_argument("--url", required=True)
    parser.add_argument("--goal", required=True)
    parser.add_argument("--show", action="store_true", help="show the window")
    parser.add_argument("--my-chrome", action="store_true", help="use your own Chrome and its signed-in accounts")
    args = parser.parse_args()

    load_env(HERE / ".env")
    if not os.environ.get("TYPESAFE_API_KEY"):
        print(json.dumps({"status": "not_configured", "error": "TYPESAFE_API_KEY is missing: use the playwright MCP server"}))
        return 2
    result = run(args.url, args.goal, args.show, args.my_chrome)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["status"] == "done" else 1


if __name__ == "__main__":
    sys.exit(main())
