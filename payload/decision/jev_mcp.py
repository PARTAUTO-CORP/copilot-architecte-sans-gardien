"""MCP server over stdio: gives agents direct access to TypeSafe's Jev decision API. Reads its key from .env."""

import json
import os
import sys
import time

import httpx

from jev_browser import HERE, load_env

API = "https://api.typesafe.ai/v1"
CLIENT = httpx.Client(http2=True, timeout=25)
TOOLS = [
    {
        "name": "run_decision",
        "description": (
            "Asks Jev one or more typed questions about a state and returns structured answers. "
            "Paid per input token. Never send secrets, personal data or private code."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "state": {"description": "What the questions refer to: text, or better a JSON object with descriptive keys."},
                "questions": {
                    "type": "object",
                    "description": (
                        "Map of a name you choose to a question. "
                        '{"type":"choice","instructions":"...","criteria":{"name":"description"}} picks one option. '
                        '{"type":"noul","instructions":"..."} returns the probability of yes. '
                        '{"type":"score","instructions":"...","criteria":["lowest level","highest level"]} rates on a scale.'
                    ),
                },
                "model": {"type": "string", "description": "Optional. Defaults to jev-latest."},
            },
            "required": ["state", "questions"],
        },
    },
    {
        "name": "list_models",
        "description": "Lists the available Jev models. Free.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


class ToolError(Exception):
    pass


def call_api(method, path, body=None):
    key = os.environ.get("TYPESAFE_API_KEY")
    if not key:
        raise ToolError("TYPESAFE_API_KEY is missing: use the next decision tool and report it")
    for attempt in range(3):
        try:
            response = CLIENT.request(method, API + path, json=body, headers={"Authorization": f"Bearer {key}"})
        except httpx.HTTPError as error:
            raise ToolError(f"TypeSafe connection failed: {type(error).__name__}") from None
        if response.status_code in {429, 529} and attempt < 2:
            time.sleep(0.5 * 2**attempt)
            continue
        if response.is_error:
            raise ToolError(f"TypeSafe returned HTTP {response.status_code}: {response.text[:500]}")
        return response.json()


def run_tool(name, args):
    if name == "list_models":
        return call_api("GET", "/models")
    if name == "run_decision":
        model = args.get("model") or os.environ.get("TYPESAFE_MODEL", "jev-latest")
        return call_api("POST", "/systemone", {"model": model, "state": args.get("state"), "questions": args.get("questions")})
    raise ToolError(f"Unknown tool: {name}")


def handle(message):
    """Returns the JSON-RPC response, or None for a notification."""
    if "id" not in message:
        return None
    method, params = message.get("method"), message.get("params") or {}
    if method == "initialize":
        result = {
            "protocolVersion": params.get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "jev", "version": "1.0.0"},
        }
    elif method == "ping":
        result = {}
    elif method == "tools/list":
        result = {"tools": TOOLS}
    elif method == "tools/call":
        # A failed call must reach the agent as an error, never look like an answer.
        try:
            output, failed = json.dumps(run_tool(params.get("name"), params.get("arguments") or {}), ensure_ascii=False), False
        except ToolError as error:
            output, failed = str(error), True
        result = {"content": [{"type": "text", "text": output}], "isError": failed}
    else:
        return {"jsonrpc": "2.0", "id": message["id"], "error": {"code": -32601, "message": f"Unknown method: {method}"}}
    return {"jsonrpc": "2.0", "id": message["id"], "result": result}


def main():
    load_env(HERE / ".env")
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            answer = handle(json.loads(line))
        except ValueError:
            answer = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Invalid JSON"}}
        if answer:
            print(json.dumps(answer, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
