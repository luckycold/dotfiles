#!/usr/bin/env python3
"""Probe upstream kagi mcp tool schemas (Luke Hermes container).

Run from any cwd; no shell pipes required (cron/Tirith-safe):
  python3 /path/to/skills/.../references/kagi-mcp-schema-probe.py

Exit 0 prints one line per tool: name + property keys or EMPTY.
Exit 1 if any of the five required tools lack typed properties.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

KAGI = "/config/.npm-global/bin/kagi"
HOME = "/config"
REQUIRED = {
    "kagi_search",
    "kagi_quick",
    "kagi_summarize",
    "kagi_news",
    "kagi_news_search",
}


def main() -> int:
    env = os.environ.copy()
    env["HOME"] = HOME
    env["PATH"] = (
        "/config/.npm-global/bin:/config/.linuxbrew/bin:"
        "/config/.linuxbrew/sbin:/usr/bin:/bin:" + env.get("PATH", "")
    )
    msgs = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "infra-hygiene-probe", "version": "1"},
            },
        },
        {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
    ]
    proc = subprocess.run(
        [KAGI, "mcp", "--json-lines"],
        input="".join(json.dumps(m) + "\n" for m in msgs),
        env=env,
        cwd=HOME,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
        check=False,
    )
    if proc.returncode != 0:
        print("kagi mcp failed:", proc.stderr[:300] or proc.stdout[:300], file=sys.stderr)
        return 2
    tools_by_name: dict[str, dict] = {}
    for line in proc.stdout.splitlines():
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("id") == 2 and "result" in obj:
            for t in obj["result"].get("tools", []):
                tools_by_name[t.get("name", "")] = t
    ok = True
    for name in sorted(REQUIRED):
        t = tools_by_name.get(name)
        if not t:
            print(name, "MISSING")
            ok = False
            continue
        props = list(t.get("inputSchema", {}).get("properties", {}).keys())
        print(name, props or "EMPTY")
        if not props:
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())