#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import webbrowser
from pathlib import Path


def data_dir() -> Path:
    return Path(os.environ.get("PLANNOTATOR_DATA_DIR", "~/.plannotator")).expanduser()


def prepared_state_file() -> Path:
    return data_dir() / "active-agent-review.json"


def process_is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def load_prepared_state() -> dict:
    path = prepared_state_file()
    try:
        state = json.loads(path.read_text())
    except FileNotFoundError as error:
        raise RuntimeError("no prepared Plannotator review is available") from error
    except json.JSONDecodeError as error:
        raise RuntimeError(f"prepared review state is invalid: {path}") from error

    pid = state.get("pid")
    if not isinstance(pid, int) or not process_is_running(pid):
        path.unlink(missing_ok=True)
        raise RuntimeError("the prepared Plannotator review is no longer running")
    return state


def save_prepared_state(state: dict) -> None:
    path = prepared_state_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(state) + "\n")
    temporary.replace(path)


def add_target_options(parser: argparse.ArgumentParser) -> None:
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--pr", metavar="URL", help="GitHub PR or GitLab MR URL")
    target.add_argument("--diff-type", help="Plannotator Git diff type")
    parser.add_argument("--base", help="Git comparison base")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare a hidden Plannotator session for the active agent."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    start = commands.add_parser("start", help="Start a hidden code review session")
    add_target_options(start)

    post = commands.add_parser("post", help="Add the active agent's findings")
    post.add_argument("--url", help="Plannotator session URL (defaults to prepared review)")
    post.add_argument("--input", required=True, help="JSON findings file, or - for stdin")
    post.add_argument(
        "--source", default="active-agent-review", help="Annotation source label"
    )

    open_parser = commands.add_parser("open", help="Open the prepared session")
    open_parser.add_argument("--url", help="Plannotator session URL")

    stop = commands.add_parser("stop", help="Stop the prepared session")
    stop.add_argument("--pid", type=int, help="Plannotator process ID")

    commands.add_parser("status", help="Show the prepared session state")
    return parser.parse_args()


def request_json(url: str, method: str = "GET", body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"} if data else {},
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise RuntimeError(f"{method} {url} returned {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Cannot reach {url}: {error.reason}") from error


def session_file(pid: int) -> Path:
    return data_dir() / "sessions" / f"{pid}.json"


def read_process_log(log_path: Path) -> str:
    try:
        return log_path.read_text(errors="replace").strip()
    except OSError:
        return ""


def start_session(args: argparse.Namespace) -> int:
    try:
        existing = load_prepared_state()
    except RuntimeError:
        existing = None
    if existing:
        raise RuntimeError(
            "a prepared Plannotator review is already running; open or stop it first"
        )

    plannotator = shutil.which("plannotator")
    if not plannotator:
        raise RuntimeError("plannotator is not on PATH")
    if args.pr and args.base:
        raise RuntimeError("--base cannot be used with --pr")

    command = [plannotator, "review"]
    if args.pr:
        command.append(args.pr)
    else:
        command.extend(["--git", "--diff-type", args.diff_type or "merge-base"])
        if args.base:
            command.extend(["--base", args.base])

    log = tempfile.NamedTemporaryFile(
        prefix="plannotator-review-", suffix=".log", delete=False
    )
    log_path = Path(log.name)
    environment = os.environ.copy()
    environment["PLANNOTATOR_SKIP_BROWSER_OPEN"] = "1"
    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        env=environment,
        start_new_session=True,
    )
    log.close()

    registry_path = session_file(process.pid)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if registry_path.exists():
            try:
                session = json.loads(registry_path.read_text())
                session["log"] = str(log_path)
                session["findingCount"] = None
                save_prepared_state(session)
                print(json.dumps({"status": "started", "pid": process.pid}))
                return 0
            except (OSError, json.JSONDecodeError):
                pass
        if process.poll() is not None:
            output = read_process_log(log_path)
            raise RuntimeError(
                f"Plannotator exited during startup with code {process.returncode}"
                + (f":\n{output}" if output else "")
            )
        time.sleep(0.25)

    process.terminate()
    raise RuntimeError(
        f"Timed out waiting for Plannotator session registration. Log: {log_path}"
    )


def load_annotations(path: str, source: str) -> list[dict]:
    if path == "-":
        payload = json.load(sys.stdin)
    else:
        with open(path) as file:
            payload = json.load(file)

    annotations = payload.get("annotations") if isinstance(payload, dict) else payload
    if not isinstance(annotations, list):
        raise RuntimeError('findings JSON must be a list or an object with "annotations"')
    for index, annotation in enumerate(annotations):
        if not isinstance(annotation, dict):
            raise RuntimeError(f"annotation {index} is not an object")
        annotation.setdefault("source", source)
    return annotations


def post_annotations(args: argparse.Namespace) -> int:
    state = load_prepared_state() if not args.url else None
    url = args.url or state["url"]
    annotations = load_annotations(args.input, args.source)
    if annotations:
        result = request_json(
            f"{url.rstrip('/')}/api/external-annotations",
            method="POST",
            body={"annotations": annotations},
        )
    else:
        result = {"ids": []}

    result["count"] = len(result.get("ids", []))
    if state is not None:
        state["findingCount"] = result["count"]
        save_prepared_state(state)
    print(json.dumps(result))
    return 0


def open_session(url: str | None) -> int:
    target = url or load_prepared_state()["url"]
    if not webbrowser.open(target):
        raise RuntimeError(f"Could not open {target}")
    print("Opened the prepared Plannotator review.")
    return 0


def stop_session(pid: int | None) -> int:
    target = pid
    if target is None:
        target = load_prepared_state()["pid"]

    if not process_is_running(target):
        prepared_state_file().unlink(missing_ok=True)
        print(f"Plannotator session {target} is already stopped.")
        return 0

    os.kill(target, signal.SIGTERM)
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if not process_is_running(target):
            prepared_state_file().unlink(missing_ok=True)
            print(f"Stopped Plannotator session {target}.")
            return 0
        time.sleep(0.1)

    print(f"Sent a stop signal to Plannotator session {target}; it is still shutting down.")
    return 0


def show_status() -> int:
    state = load_prepared_state()
    print(json.dumps(state))
    return 0


def main() -> int:
    args = parse_args()
    try:
        if args.command == "start":
            return start_session(args)
        if args.command == "post":
            return post_annotations(args)
        if args.command == "open":
            return open_session(args.url)
        if args.command == "stop":
            return stop_session(args.pid)
        if args.command == "status":
            return show_status()
        raise RuntimeError(f"unknown command: {args.command}")
    except (RuntimeError, OSError, json.JSONDecodeError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
