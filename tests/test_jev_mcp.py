"""Tests the Jev MCP server against a fake TypeSafe API. No paid call.

<decision venv python> tests/test_jev_mcp.py
"""

import http.server
import json
import os
import subprocess
import sys
import threading
from pathlib import Path

SOURCE = Path(__file__).resolve().parent.parent / "payload" / "decision"
sys.path.insert(0, str(SOURCE))
sys.dont_write_bytecode = True

import jev_mcp  # noqa: E402

seen, replies = [], []


class FakeApi(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def answer(self):
        length = int(self.headers.get("Content-Length") or 0)
        seen.append((self.command, self.path, self.headers.get("Authorization"), json.loads(self.rfile.read(length) or b"null")))
        status, body = replies.pop(0)
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = answer


def call(name, args=None):
    reply = jev_mcp.handle({"id": 1, "method": "tools/call", "params": {"name": name, "arguments": args or {}}})
    return reply["result"]["isError"], reply["result"]["content"][0]["text"]


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FakeApi)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    jev_mcp.API = f"http://127.0.0.1:{server.server_address[1]}/v1"
    jev_mcp.CLIENT = jev_mcp.httpx.Client(timeout=5)
    questions = {"db": {"type": "choice", "instructions": "Which database?", "criteria": {"postgresql": "", "mongodb": ""}}}
    answer = {"model": "jev-1.14.0", "answers": {"db": {"type": "choice", "choice": "postgresql", "confidence": 0.7, "probabilities": {"postgresql": 0.8, "mongodb": 0.2}}}, "usage": {"input_tokens": 12, "output_tokens": 1}}

    # No key: an error the agent can act on, and no network call
    os.environ.pop("TYPESAFE_API_KEY", None)
    failed, text = call("run_decision", {"state": "x", "questions": questions})
    assert failed and "TYPESAFE_API_KEY" in text and not seen

    # Request format, key in the header, answer passed through
    os.environ["TYPESAFE_API_KEY"] = "test-key-value"
    replies.append((200, answer))
    failed, text = call("run_decision", {"state": {"team": "small"}, "questions": questions})
    assert not failed and json.loads(text)["answers"]["db"]["choice"] == "postgresql"
    assert seen[-1] == ("POST", "/v1/systemone", "Bearer test-key-value", {"model": "jev-latest", "state": {"team": "small"}, "questions": questions}), seen[-1]

    # Overload is retried
    replies.extend([(529, {"detail": "busy"}), (200, answer)])
    assert not call("run_decision", {"state": "x", "questions": questions})[0]

    # A refused key is an error, never an answer, and the key is not echoed
    replies.append((401, {"detail": "bad key"}))
    failed, text = call("run_decision", {"state": "x", "questions": questions})
    assert failed and "401" in text and "test-key-value" not in text

    # Rate limit gives up after 3 attempts
    count = len(seen)
    replies.extend([(429, {})] * 3)
    assert call("run_decision", {"state": "x", "questions": questions})[0] and len(seen) == count + 3

    replies.append((200, {"models": [{"name": "jev-latest"}]}))
    assert "jev-latest" in call("list_models")[1] and seen[-1][:2] == ("GET", "/v1/models")
    assert call("nothing")[0]

    # The real process over stdio, as Copilot starts it
    env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
    lines = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "t", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        {"jsonrpc": "2.0", "id": 3, "method": "unknown"},
    ]
    done = subprocess.run(
        [sys.executable, "-B", str(SOURCE / "jev_mcp.py")],
        input="\n".join(map(json.dumps, lines)) + "\nnot json\n",
        capture_output=True, text=True, encoding="utf-8", timeout=30, env=env, cwd=Path(__file__).parent,
    )
    out = [json.loads(line) for line in done.stdout.splitlines()]
    assert done.returncode == 0, done.stderr
    assert [m.get("id") for m in out] == [1, 2, 3, None], out
    assert out[0]["result"]["protocolVersion"] == "2025-06-18"
    assert {t["name"] for t in out[1]["result"]["tools"]} == {"run_decision", "list_models"}
    assert out[2]["error"]["code"] == -32601 and out[3]["error"]["code"] == -32700
    print("RESULT: ok")


if __name__ == "__main__":
    main()
