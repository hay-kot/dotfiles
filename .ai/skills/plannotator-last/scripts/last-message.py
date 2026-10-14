#!/usr/bin/env python3

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Iterable


def text_blocks(content: object, block_types: tuple[str, ...] = ("text",)) -> list[str]:
    if isinstance(content, str):
        return [content] if content.strip() else []
    if not isinstance(content, list):
        return []

    return [
        block["text"]
        for block in content
        if isinstance(block, dict)
        and block.get("type") in block_types
        and isinstance(block.get("text"), str)
        and block["text"].strip()
    ]


def read_jsonl(path: Path) -> list[dict]:
    entries = []
    for line in path.read_text(errors="replace").splitlines():
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(entry, dict):
            entries.append(entry)
    return entries


def active_chain(
    entries: Iterable[dict], id_key: str, parent_key: str
) -> list[dict]:
    branch_entries = [
        entry
        for entry in entries
        if entry.get(id_key) and not entry.get("isSidechain", False)
    ]
    if not branch_entries:
        return []

    entries_by_id = {entry[id_key]: entry for entry in branch_entries}
    chain = []
    entry = branch_entries[-1]
    visited = set()
    while entry and entry[id_key] not in visited:
        visited.add(entry[id_key])
        chain.append(entry)
        entry = entries_by_id.get(entry.get(parent_key))
    return chain


def previous_assistant_text(
    entries: Iterable[dict],
    role_and_content,
    message_id,
) -> str | None:
    passed_current_user = False
    target_message_id = None
    parts = []

    for entry in entries:
        role, content, is_human = role_and_content(entry)
        if is_human:
            if passed_current_user and parts:
                break
            passed_current_user = True
            continue
        if not passed_current_user or role != "assistant":
            continue

        entry_parts = text_blocks(content)
        if not entry_parts:
            continue

        current_message_id = message_id(entry)
        if target_message_id is None:
            target_message_id = current_message_id
        elif current_message_id != target_message_id:
            break
        parts.extend(reversed(entry_parts))

    if not parts:
        return None
    return "\n\n".join(reversed(parts)).strip()


def pi_message(path: Path) -> str | None:
    entries = active_chain(read_jsonl(path), "id", "parentId")

    def role_and_content(entry: dict) -> tuple[object, object, bool]:
        message = entry.get("message") or {}
        role = message.get("role")
        return role, message.get("content"), role == "user"

    return previous_assistant_text(
        entries,
        role_and_content,
        lambda entry: entry.get("id"),
    )


def claude_message(path: Path) -> str | None:
    entries = active_chain(read_jsonl(path), "uuid", "parentUuid")

    def role_and_content(entry: dict) -> tuple[object, object, bool]:
        message = entry.get("message") or {}
        content = message.get("content")
        is_human = entry.get("type") == "user" and bool(text_blocks(content))
        return message.get("role"), content, is_human

    return previous_assistant_text(
        entries,
        role_and_content,
        lambda entry: (entry.get("message") or {}).get("id") or entry.get("uuid"),
    )


def codex_message(path: Path) -> str | None:
    entries = []
    for entry in reversed(read_jsonl(path)):
        if entry.get("type") != "response_item":
            continue
        payload = entry.get("payload") or {}
        if payload.get("type") == "message":
            entries.append(payload)

    def role_and_content(entry: dict) -> tuple[object, object, bool]:
        role = entry.get("role")
        content = entry.get("content")
        is_human = role == "user" and bool(
            text_blocks(content, ("input_text",))
        )
        normalized_content = [
            {"type": "text", "text": part}
            for part in text_blocks(content, ("output_text",))
        ]
        return role, normalized_content, is_human

    return previous_assistant_text(
        entries,
        role_and_content,
        lambda entry: entry.get("id"),
    )


def find_session_file(root: Path, pattern: str) -> Path | None:
    candidates = sorted(
        root.rglob(pattern),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return candidates[0] if candidates else None


def extract_message(claude_session_id: str | None) -> str:
    pi_session_file = os.environ.get("PI_SESSION_FILE")
    if pi_session_file:
        message = pi_message(Path(pi_session_file))
        if message:
            return message

    if claude_session_id and "CLAUDE_SESSION_ID" not in claude_session_id:
        session_file = find_session_file(
            Path.home() / ".claude" / "projects", f"{claude_session_id}.jsonl"
        )
        if session_file:
            message = claude_message(session_file)
            if message:
                return message

    codex_thread_id = os.environ.get("CODEX_THREAD_ID")
    if codex_thread_id:
        session_file = find_session_file(
            Path.home() / ".codex" / "sessions", f"*{codex_thread_id}.jsonl"
        )
        if session_file:
            message = codex_message(session_file)
            if message:
                return message

    raise RuntimeError("no previous assistant response was found in an active session")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--claude-session-id")
    args = parser.parse_args()

    claude_session_id = args.claude_session_id
    if claude_session_id and "CLAUDE_SESSION_ID" in claude_session_id:
        claude_session_id = None
    claude_session_id = claude_session_id or os.environ.get("CLAUDE_SESSION_ID")

    try:
        message = extract_message(claude_session_id)
    except (OSError, RuntimeError) as error:
        print(f"plannotator-last: {error}", file=sys.stderr)
        raise SystemExit(1) from error

    sys.stdout.write(message)


if __name__ == "__main__":
    main()
