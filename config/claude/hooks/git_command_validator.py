#!/usr/bin/env python3
"""
Claude Code Hook: Git Command Validator
This hook runs as a PreToolUse hook for the Bash tool.
It prevents direct git commands and forces the use of MCP git tools.
"""

import json
import re
import sys

_VALIDATION_RULES = [
    (
        r"^git\s+",
        "Use MCP git tools (mcp__git__*) instead of direct git commands"
    ),
]

def _validate_command(command: str) -> list[str]:
    issues = []
    for pattern, message in _VALIDATION_RULES:
        if re.search(pattern, command):
            issues.append(message)
    return issues

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    if tool_name != "Bash":
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    if not command:
        sys.exit(0)

    issues = _validate_command(command)
    if issues:
        for message in issues:
            print(f"• {message}", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()