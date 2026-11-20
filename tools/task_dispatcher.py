#!/usr/bin/env python3
"""Async task dispatcher for Feishu/cc-connect routing.

Why this exists:
  cc-connect bridges one chat to ONE long-lived Claude Code session. If that
  session is busy with a long turn, new Feishu messages are queued
  ("message queued for busy session"). The router must therefore return
  immediately: write the task, hand it to a detached worker, and end the turn.

  Each task runs as its own `claude -p` process (separate context/process),
  so tasks execute in parallel and the main Feishu session stays free.

Layout (~/.cc-connect/tasks):
  pending/  running/  done/  failed/  daemon.pid  daemon.log

Usage:
  python3 tools/task_dispatcher.py enqueue --file /path/task.json
  python3 tools/task_dispatcher.py list
  python3 tools/task_dispatcher.py status <id>
  python3 tools/task_dispatcher.py daemon          # normally auto-started
  python3 tools/task_dispatcher.py run <task.json> # internal
"""

import argparse
import fcntl
import json
import os
import shutil
import subprocess
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path

BASE = Path(os.path.expanduser("~/.cc-connect/tasks"))
PENDING = BASE / "pending"
RUNNING = BASE / "running"
DONE = BASE / "done"
FAILED = BASE / "failed"
DAEMON_PID = BASE / "daemon.pid"
DAEMON_LOG = BASE / "daemon.log"
CLAUDE = os.environ.get("CC_TASK_CLAUDE") or shutil.which("claude") or "claude"
MAX_WORKERS = int(os.environ.get("CC_TASK_WORKERS", "3"))
DEFAULT_MODEL = os.environ.get("CC_TASK_MODEL", "deepseek-flash")
DEFAULT_PERM = os.environ.get("CC_TASK_PERMISSION_MODE", "bypassPermissions")


def ensure_dirs():
    for p in (PENDING, RUNNING, DONE, FAILED):
        p.mkdir(parents=True, exist_ok=True)


def now():
    return datetime.now().isoformat(timespec="seconds")


def write_json(path: Path, data):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def ensure_daemon():
    ensure_dirs()
    if DAEMON_PID.exists():
        try:
            pid = int(DAEMON_PID.read_text().strip())
            if alive(pid):
                return pid
        except ValueError:
            pass
    log = open(DAEMON_LOG, "ab")
    proc = subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "daemon"],
        cwd=os.getcwd(),
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=log,
        start_new_session=True,
        env=os.environ.copy(),
    )
    DAEMON_PID.write_text(str(proc.pid))
    print(f"daemon started pid={proc.pid}")
    return proc.pid


def notify(task, status, result, result_path):
    if not task.get("notify", True):
        return
    icon = "✓" if status == "done" else "✗"
    title = task.get("title") or task.get("id", "task")
    body = (result or "").strip()
    if len(body) > 1200:
        body = body[:1200] + "…"
    text = f"[{task.get('id','?')}] {icon} {title}\n{body}\n结果: {result_path}"
    cmd = ["cc-connect", "send", "-m", text]
    project = task.get("cc_project") or ""
    if project:
        cmd += ["-p", project]
    try:
        subprocess.run(cmd, timeout=30, check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print("notify failed:", e)


def update_plan(task, status, output):
    plan = task.get("plan_file")
    if not plan:
        return
    path = Path(task.get("cwd") or os.getcwd()) / plan
    if not path.exists():
        return
    lock_path = path.with_suffix(path.suffix + ".lock")
    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        lines = path.read_text(encoding="utf-8").splitlines()
        start = None
        for i, line in enumerate(lines):
            if line.startswith(f"## {task.get('id')} ") or line.startswith(f"## {task.get('id')}·"):
                start = i
                break
        if start is None:
            return
        end = len(lines)
        for j in range(start + 1, len(lines)):
            if lines[j].startswith("## "):
                end = j
                break
        for k in range(start, end):
            if lines[k].startswith("- 状态:"):
                lines[k] = f"- 状态: {status}"
            elif lines[k].startswith("- 产出:"):
                lines[k] = f"- 产出: {output}"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_claude_output(stdout: str):
    stdout = (stdout or "").strip()
    if not stdout:
        return None
    try:
        return json.loads(stdout)
    except json.JSONDecodeError:
        # Sometimes logs precede the JSON; try the last JSON object.
        start = stdout.find("{")
        end = stdout.rfind("}")
        if start >= 0 and end > start:
            try:
                return json.loads(stdout[start:end + 1])
            except json.JSONDecodeError:
                return None
    return None


def run_task(task_path: Path):
    task = read_json(task_path)
    task_id = task.get("id") or task_path.parent.name
    rdir = task_path.parent
    write_json(rdir / "status.json", {
        "id": task_id, "status": "running", "pid": os.getpid(), "started": now(),
    })
    update_plan(task, "running", "worker running")
    log_path = rdir / "worker.log"
    result_text = ""
    status = "done"
    try:
        with open(log_path, "wb") as log:
            if task.get("exec"):
                proc = subprocess.run(
                    task["exec"], shell=True, cwd=task.get("cwd") or os.getcwd(),
                    stdout=subprocess.PIPE, stderr=log, text=True)
                result_text = (proc.stdout or "").strip()
                if proc.returncode != 0:
                    status = "failed"
                    result_text = f"exec failed rc={proc.returncode}\n{result_text}"
            else:
                prompt = task.get("prompt") or ""
                if not prompt:
                    raise ValueError("task has neither prompt nor exec")
                prompt = (
                    f"[TASK WORKER {task_id}]\n"
                    "你是该任务的独立执行 worker。项目 CLAUDE.md 里的“主 Agent 只路由”"
                    "规则只约束飞书入口的主 Agent，不约束你；请直接实现任务，不要只给计划，"
                    "也不要再派 subagent。\n"
                    "若任务产出图片/GIF/视频，完成后必须用 "
                    "`cc-connect send --image <绝对路径> --video <绝对路径>` "
                    "发送 1–3 个代表性附件到当前飞书会话（不要发中间产物）；"
                    "文本摘要由 runner 统一发送。\n\n" + prompt
                )
                cmd = [
                    CLAUDE, "-p", prompt,
                    "--model", task.get("model") or DEFAULT_MODEL,
                    "--permission-mode", task.get("permission_mode") or DEFAULT_PERM,
                    "--output-format", "json",
                ]
                if task.get("agent"):
                    cmd += ["--agent", str(task["agent"])]
                env = os.environ.copy()
                env["CC_TASK_ID"] = task_id
                env["CC_TASK_TITLE"] = task.get("title", "")
                proc = subprocess.run(
                    cmd, cwd=task.get("cwd") or os.getcwd(),
                    stdout=subprocess.PIPE, stderr=log, text=True, env=env)
                parsed = parse_claude_output(proc.stdout)
                if proc.returncode != 0 or (parsed and parsed.get("is_error")):
                    status = "failed"
                if parsed:
                    result_text = str(parsed.get("result") or "").strip()
                if not result_text:
                    result_text = (proc.stdout or "").strip()
                if status == "failed" and not result_text:
                    result_text = f"claude exited rc={proc.returncode}"
    except Exception as e:
        status = "failed"
        result_text = f"{type(e).__name__}: {e}"

    finished = now()
    target = (DONE if status == "done" else FAILED) / task_id
    final_log = target / "worker.log"
    output = str(target / "result.md")
    result_data = {
        "id": task_id, "title": task.get("title", ""),
        "status": status, "finished": finished,
        "result": result_text, "log": str(final_log),
        "cwd": task.get("cwd", ""),
    }
    write_json(rdir / "result.json", result_data)
    (rdir / "result.md").write_text(
        f"# {task.get('title', task_id)}\n\n"
        f"- id: {task_id}\n- status: {status}\n- finished: {finished}\n"
        f"- log: `{final_log}`\n\n## Result\n\n{result_text}\n",
        encoding="utf-8")
    write_json(rdir / "status.json", {
        "id": task_id, "status": status, "pid": os.getpid(), "finished": finished,
    })
    update_plan(task, status, output)
    notify(task, status, result_text, output)

    if target.exists():
        shutil.rmtree(target, ignore_errors=True)
    try:
        shutil.move(str(rdir), str(target))
    except Exception as e:
        print("move failed:", e)


def count_running():
    ensure_dirs()
    return sum(1 for p in RUNNING.iterdir() if p.is_dir())


def start_runner(task_path: Path):
    rdir = task_path.parent
    log = open(rdir / "runner.log", "ab")
    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "run", str(task_path)],
        cwd=os.getcwd(),
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=log,
        start_new_session=True,
        env=os.environ.copy(),
    )


def daemon():
    ensure_dirs()
    DAEMON_PID.write_text(str(os.getpid()))
    print(f"daemon up pid={os.getpid()} max_workers={MAX_WORKERS}", flush=True)
    while True:
        try:
            if count_running() < MAX_WORKERS:
                files = sorted(PENDING.glob("*.json"), key=lambda p: p.stat().st_mtime)
                for f in files:
                    if count_running() >= MAX_WORKERS:
                        break
                    task = read_json(f)
                    task_id = task.get("id") or ("T-" + uuid.uuid4().hex[:8])
                    rdir = RUNNING / task_id
                    if rdir.exists():
                        rdir = RUNNING / (task_id + "-" + uuid.uuid4().hex[:4])
                    rdir.mkdir(parents=True, exist_ok=True)
                    task["id"] = task_id
                    write_json(rdir / "task.json", task)
                    try:
                        f.unlink()
                    except OSError:
                        pass
                    start_runner(rdir / "task.json")
                    print(f"started {task_id}", flush=True)
            time.sleep(2)
        except Exception as e:
            print("daemon error:", e, flush=True)
            time.sleep(5)


def enqueue(args):
    ensure_dirs()
    if args.file:
        task = read_json(Path(args.file))
    elif args.json:
        task = json.loads(args.json)
    else:
        raise SystemExit("enqueue needs --file or --json")
    task.setdefault("id", "T-" + datetime.now().strftime("%Y%m%d") + "-" +
                    uuid.uuid4().hex[:4].upper())
    task.setdefault("cwd", os.getcwd())
    task.setdefault("created", now())
    task.setdefault("model", DEFAULT_MODEL)
    task.setdefault("permission_mode", DEFAULT_PERM)
    task.setdefault("notify", True)
    task.setdefault("cc_project", os.environ.get("CC_PROJECT", ""))
    task.setdefault("cc_session", os.environ.get("CC_SESSION_KEY", ""))
    if not task.get("prompt") and not task.get("exec"):
        raise SystemExit("task needs prompt or exec")
    path = PENDING / (task["id"] + ".json")
    write_json(path, task)
    ensure_daemon()
    print(task["id"])


def list_tasks(_args):
    ensure_dirs()
    rows = []
    for folder, status in ((PENDING, "pending"), (RUNNING, "running"),
                           (DONE, "done"), (FAILED, "failed")):
        for p in sorted(folder.iterdir()):
            if p.is_dir():
                task_file = p / "task.json"
                title = ""
                if task_file.exists():
                    try:
                        title = read_json(task_file).get("title", "")
                    except Exception:
                        pass
                rows.append({"id": p.name, "status": status, "title": title})
            elif p.suffix == ".json":
                try:
                    t = read_json(p)
                    rows.append({"id": t.get("id", p.stem), "status": status,
                                 "title": t.get("title", "")})
                except Exception:
                    pass
    for r in rows:
        print(f"{r['status']:8} {r['id']:24} {r['title']}")
    return rows


def status(args):
    for folder in (PENDING, RUNNING, DONE, FAILED):
        for p in folder.iterdir():
            if p.name == args.id or p.stem == args.id:
                target = p if p.is_dir() else p
                for f in ("task.json", "result.json", "status.json"):
                    fp = target / f if target.is_dir() else None
                    if fp and fp.exists():
                        print(f"--- {f}")
                        print(fp.read_text(encoding="utf-8"))
                return
    print("not found")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_enq = sub.add_parser("enqueue")
    p_enq.add_argument("--file")
    p_enq.add_argument("--json")
    sub.add_parser("daemon")
    p_run = sub.add_parser("run")
    p_run.add_argument("task")
    sub.add_parser("list")
    p_status = sub.add_parser("status")
    p_status.add_argument("id")
    args = parser.parse_args()
    if args.cmd == "enqueue":
        enqueue(args)
    elif args.cmd == "daemon":
        daemon()
    elif args.cmd == "run":
        run_task(Path(args.task))
    elif args.cmd == "list":
        list_tasks(args)
    elif args.cmd == "status":
        status(args)


if __name__ == "__main__":
    main()
