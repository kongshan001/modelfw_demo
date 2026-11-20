#!/usr/bin/env python3
"""Publish completed task outputs to the remote Git repo.

Every task JSON may declare:

    "commit_paths": ["godot-pixel-ocean/", "docs/task-plans/game-demos.md"]

After the worker finishes and the task directory is under done/, this publisher
serializes git add/commit/push (one lock) and only touches those paths. It does
not force-push and does not stage unrelated working-tree changes.

Usage:
  python3 tools/git_publisher.py publish <task_id>
  python3 tools/git_publisher.py publish-all
  python3 tools/git_publisher.py daemon
  python3 tools/git_publisher.py status
"""

import argparse
import fcntl
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

TASKS = Path(os.path.expanduser("~/.cc-connect/tasks"))
DONE = TASKS / "done"
PID = TASKS / "git-publisher.pid"
LOG = TASKS / "git-publisher.log"
LOCK = TASKS / "git.lock"


def now():
    return datetime.now().isoformat(timespec="seconds")


def git(repo, *args, timeout=180):
    return subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True, timeout=timeout)


def published(task_dir: Path) -> bool:
    f = task_dir / "git.json"
    if not f.exists():
        return False
    try:
        d = json.loads(f.read_text(encoding="utf-8"))
        return d.get("status") in ("published", "no_changes")
    except Exception:
        return False


def write_git(task_dir: Path, data):
    tmp = task_dir / "git.json.tmp"
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, task_dir / "git.json")


def notify(project, text):
    if not project:
        return
    try:
        subprocess.run(
            ["cc-connect", "send", "-p", project, "-m", text],
            timeout=30, check=False, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)
    except Exception:
        pass


def publish_task(task_dir: Path) -> dict:
    task = json.loads((task_dir / "task.json").read_text(encoding="utf-8"))
    task_id = task.get("id") or task_dir.name
    paths = task.get("commit_paths") or []
    repo = task.get("cwd") or os.getcwd()
    if not paths:
        data = {"status": "skipped", "reason": "no commit_paths", "at": now()}
        write_git(task_dir, data)
        return data

    LOCK.touch(exist_ok=True)
    with open(LOCK, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)

        # Only stage explicitly declared paths.
        add = git(repo, "add", "--ignore-errors", "--", *paths)
        staged = git(repo, "diff", "--cached", "--name-only", "--", *paths)
        if staged.returncode != 0 or not staged.stdout.strip():
            data = {"status": "no_changes", "at": now()}
            write_git(task_dir, data)
            return data

        msg = f"{task_id}: {task.get('title', 'task result')}\n\n" \
              "Co-Authored-By: Claude <noreply@anthropic.com>"
        commit = git(repo, "commit", "-m", msg)
        if commit.returncode != 0:
            data = {"status": "commit_failed", "at": now(),
                    "stderr": (commit.stderr or "")[-1500:]}
            write_git(task_dir, data)
            notify(task.get("cc_project"),
                   f"[{task_id}] git commit 失败，请检查: {(commit.stderr or '')[-300:]}")
            return data

        branch = git(repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip() or "HEAD"
        rev = git(repo, "rev-parse", "--short", "HEAD").stdout.strip()
        push = git(repo, "push", "origin", branch, timeout=300)
        if push.returncode != 0:
            data = {"status": "push_failed", "commit": rev, "branch": branch,
                    "at": now(), "stderr": (push.stderr or "")[-1500:]}
            write_git(task_dir, data)
            notify(task.get("cc_project"),
                   f"[{task_id}] 已本地提交 {rev}，但 push 失败，请检查 remote/冲突。")
            return data

        data = {"status": "published", "commit": rev, "branch": branch,
                "at": now(), "paths": paths}
        write_git(task_dir, data)
        return data


def publish_all():
    results = []
    if not DONE.exists():
        return results
    for d in sorted(DONE.iterdir(), key=lambda p: p.stat().st_mtime):
        if not d.is_dir() or published(d):
            continue
        try:
            results.append((d.name, publish_task(d)))
        except Exception as e:
            results.append((d.name, {"status": "error", "error": str(e)}))
    return results


def daemon():
    PID.write_text(str(os.getpid()))
    print(f"git publisher up pid={os.getpid()}", flush=True)
    while True:
        try:
            for name, data in publish_all():
                print(name, data.get("status"), data.get("commit", ""), flush=True)
        except Exception as e:
            print("publisher error:", e, flush=True)
        time.sleep(20)


def ensure_daemon():
    if PID.exists():
        try:
            pid = int(PID.read_text().strip())
            os.kill(pid, 0)
            return pid
        except (ValueError, OSError):
            pass
    log = open(LOG, "ab")
    proc = subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "daemon"],
        cwd=os.getcwd(), stdin=subprocess.DEVNULL, stdout=log, stderr=log,
        start_new_session=True, env=os.environ.copy())
    PID.write_text(str(proc.pid))
    return proc.pid


def status(_args):
    if not DONE.exists():
        return
    for d in sorted(DONE.iterdir()):
        if not d.is_dir():
            continue
        f = d / "git.json"
        if f.exists():
            data = json.loads(f.read_text(encoding="utf-8"))
            print(f"{d.name:24} {data.get('status','?'):12} {data.get('commit','')}")
        else:
            print(f"{d.name:24} {'pending':12}")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("publish"); p.add_argument("task_id")
    sub.add_parser("publish-all")
    sub.add_parser("daemon")
    sub.add_parser("ensure")
    sub.add_parser("status")
    args = parser.parse_args()
    if args.cmd == "ensure":
        print(ensure_daemon())
    elif args.cmd == "publish":
        d = DONE / args.task_id
        if not (d / "task.json").exists():
            raise SystemExit("task not found: " + args.task_id)
        print(publish_task(d))
    elif args.cmd == "publish-all":
        for name, data in publish_all():
            print(name, data.get("status"), data.get("commit", ""))
    elif args.cmd == "daemon":
        daemon()
    elif args.cmd == "status":
        status(args)


if __name__ == "__main__":
    main()
