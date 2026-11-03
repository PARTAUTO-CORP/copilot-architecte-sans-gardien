"""Runs jev_browser against a local page in a real Chrome, with the paid model call replaced by a script.

<decision venv python> tests/test_jev_browser.py
Covers the wrapper, the dedicated profile, browser-harness and a real click. Not covered: TypeSafe's answers.
"""

import http.server
import importlib.util
import os
import shutil
import tempfile
import threading
from pathlib import Path

PAGE = b"""<!doctype html><title>Avant</title><h1>Test</h1>
<button onclick="document.title='Clique'; this.textContent='Fait'">Valider</button>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(PAGE)))
        self.end_headers()
        self.wfile.write(PAGE)


def scripted_choose(page, goal, history):
    if history:
        choice = operation = "DONE"
    else:
        choice = next(a["id"] for a in page["actions"] if a["kind"] == "click" and "Valider" in a["label"])
        operation = "CLICK"
    return {
        "choice": choice,
        "operation": operation,
        "target": None,
        "confidence": 1.0,
        "probabilities": {choice: 1.0},
        "usage": {"input_tokens": 10},
        "latency_ms": 0,
    }


def main():
    source = Path(__file__).resolve().parent.parent / "payload" / "decision" / "jev_browser.py"
    work = Path(tempfile.mkdtemp(prefix="jev-test-"))
    shutil.copy(source, work)
    spec = importlib.util.spec_from_file_location("jev_browser", work / "jev_browser.py")
    wrapper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(wrapper)

    wrapper.DEFAULTS["BU_NAME"] = "jev-copilot-test"
    wrapper.load_env(work / ".env")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_address[1]}/"

    import jev_ultrafast.agent as agent_module

    agent_module.choose = scripted_choose
    result = wrapper.run(url, "Clique sur Valider")
    print(result)
    assert result["error"] is None, result["error"]
    assert result["status"] == "done", result
    assert result["title"] == "Clique", result  # proves the click really happened in the browser
    assert [a["kind"] for a in result["actions"]] == ["click"], result
    assert result["input_tokens"] == 10, result
    assert (work / "chrome-profile").exists(), "dedicated profile not used"
    assert os.environ["BH_TELEMETRY"] == "0"
    print("RESULT: ok")


if __name__ == "__main__":
    main()
