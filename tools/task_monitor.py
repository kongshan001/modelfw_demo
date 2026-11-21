#!/usr/bin/env python3
"""Lightweight scheduled monitor for the cc-connect task dispatcher.

It is intentionally NOT an LLM loop: it inspects task dirs, worker processes,
dependencies, plan status and git publication, then prints a short Feishu
digest only when something changed or looks wrong.

Usage:
  python3 tools/task_monitor.py                 # quiet unless change/anomaly
  python3 tools/task_monitor.py --force         # always print a snapshot
  python3 tools/task_monitor.py --reset-state   # re-baseline (testing)
  python3 tools/task_monitor.py --json          # machine-readable

State: ~/.cc-connect/tasks/monitor_state.json
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = Path(os.path.expanduser("~/.cc-connect/tasks"))
PENDING = BASE / "pending"
RUNNING = BASE / "running"
DONE = BASE / "done"
FAILED = BASE / "failed"
DEFAULT_STATE = BASE / "monitor_state.json"
DAEMON_PID = BASE / "daemon.pid"
GIT_PID = BASE / "git-publisher.pid"


def now():
    return datetime.now()


def iso(dt=None):
    return (dt or now()).isoformat(timespec="seconds")


def parse_time(s):
    try:
        return datetime.fromisoformat(str(s))
    except Exception:
        return None


def age_min(s):
    dt = parse_time(s)
    if not dt:
        return None
    return max(0.0, (now() - dt).total_seconds() / 60.0)


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return None


def write_json(path, data):
    path = Path(path)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def pid_alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except Exception:
        return False


def read_pid(path):
    try:
        return int(Path(path).read_text(encoding="utf-8").strip())
    except Exception:
        return None


def cpu_seconds(pid):
    try:
        out = subprocess.run(
            ["ps", "-p", str(pid), "-o", "time="],
            capture_output=True, text=True, timeout=5)
    except Exception:
        return None
    s = (out.stdout or "").strip()
    if not s:
        return None
    # Formats: [[dd-]hh:]mm:ss[.cc]
    days = 0
    if "-" in s:
        d, s = s.split("-", 1)
        try:
            days = int(d)
        except ValueError:
            days = 0
    parts = s.split(":")
    try:
        parts = [float(x) for x in parts]
    except ValueError:
        return None
    if len(parts) == 3:
        h, m, sec = parts
    elif len(parts) == 2:
        h, m, sec = 0, parts[0], parts[1]
    else:
        return None
    return days * 86400 + h * 3600 + m * 60 + sec


def child_count(pid):
    try:
        out = subprocess.run(
            ["pgrep", "-P", str(pid)], capture_output=True, text=True, timeout=5)
        if out.returncode == 1:
            return 0
        return len([x for x in (out.stdout or "").split() if x.strip()])
    except Exception:
        return None


def collect_tasks():
    tasks = {}
    if PENDING.is_dir():
        for f in PENDING.glob("*.json"):
            t = read_json(f) or {}
            tid = t.get("id") or f.stem
            tasks[tid] = {
                "id": tid, "status": "pending", "task": t, "dir": f.parent,
                "created": t.get("created"), "pid": None, "started": None,
                "finished": None, "git": None,
            }
    for folder, status in ((RUNNING, "running"), (DONE, "done"), (FAILED, "failed")):
        if not folder.is_dir():
            continue
        for d in folder.iterdir():
            if not d.is_dir():
                continue
            t = read_json(d / "task.json") or {}
            st = read_json(d / "status.json") or {}
            tid = t.get("id") or st.get("id") or d.name
            tasks[tid] = {
                "id": tid, "status": status, "task": t, "dir": d,
                "created": t.get("created"), "pid": st.get("pid"),
                "started": st.get("started"), "finished": st.get("finished"),
                "git": read_json(d / "git.json"),
            }
    return tasks


def plan_status(plan_file, task_id):
    if not plan_file:
        return None
    p = ROOT / plan_file
    if not p.exists():
        return None
    lines = p.read_text(encoding="utf-8", errors="ignore").splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith(f"## {task_id} ") or line.strip() == f"## {task_id}":
            start = i
            break
    if start is None:
        return None
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        if line.startswith("- 状态:"):
            raw = line.split(":", 1)[1].strip()
            return raw.split("（", 1)[0].split("(", 1)[0].strip()
    return None


def plan_ok(actual, plan):
    if not plan:
        return True
    if actual == "pending":
        return plan in ("queued", "blocked", "pending", "waiting", "待启动")
    if actual == "failed":
        return plan in ("failed", "stopped")
    return plan == actual


def status_line(tasks):
    counts = {"running": 0, "pending": 0, "done": 0, "failed": 0}
    for t in tasks.values():
        counts[t["status"]] = counts.get(t["status"], 0) + 1
    return counts


def short_title(t, n=42):
    title = (t.get("task") or {}).get("title") or t.get("id")
    title = str(title).replace("\n", " ")
    return title if len(title) <= n else title[:n - 1] + "…"


def failed_snippet(t):
    d = t.get("dir")
    if not d:
        return ""
    p = Path(d) / "result.md"
    if not p.exists():
        return ""
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""
    marker = "## Result"
    if marker in text:
        text = text.split(marker, 1)[1]
    text = " ".join(text.split())
    return text[:220]


def add_anomaly(state, anomalies, key, text, cooldown_h=6):
    ts = parse_time((state.get("notified") or {}).get(key))
    if ts and (now() - ts) < timedelta(hours=cooldown_h):
        return
    anomalies.append(text)
    state.setdefault("notified", {})[key] = iso()


def build(args, state, first_run):
    tasks = collect_tasks()
    counts = status_line(tasks)
    transitions, anomalies, active, recent_failed = [], [], [], []
    seen = state.setdefault("seen", {})
    cpu_state = state.setdefault("cpu", {})

    for tid, t in sorted(tasks.items()):
        actual = t["status"]
        prev = seen.get(tid)
        if prev != actual:
            if not first_run and prev is not None:
                extra = ""
                if actual == "done":
                    g = t.get("git") or {}
                    if g.get("status") == "published":
                        extra = f"（已发布 {g.get('commit', '')[:7]}）"
                    elif g.get("status") in ("no_changes", "skipped"):
                        extra = "（无变更）"
                transitions.append(f"- {tid} {prev} → {actual}{extra} {short_title(t)}")
            elif not first_run and prev is None:
                transitions.append(f"- 新任务 {tid}（{actual}）{short_title(t)}")

        if actual == "running":
            active.append(t)
            pid = t.get("pid")
            elapsed = age_min(t.get("started")) or 0
            if pid and pid_alive(pid):
                kids = child_count(pid)
                if kids == 0:
                    add_anomaly(state, anomalies, f"{tid}:no_child",
                                f"- {tid} runner 存活但无子进程，可能卡住")
                cpu = cpu_seconds(pid)
                prev_cpu = cpu_state.get(tid)
                if cpu is not None and prev_cpu:
                    unchanged_min = age_min(prev_cpu.get("at")) or 0
                    if abs(cpu - float(prev_cpu.get("seconds", 0))) < 0.05 and unchanged_min >= args.cpu_stall_min:
                        add_anomaly(
                            state, anomalies, f"{tid}:cpu_stall",
                            f"- {tid} 运行 {elapsed:.0f} 分钟，CPU 时间约 "
                            f"{unchanged_min:.0f} 分钟未增长（可能等待/卡住）")
                if cpu is not None:
                    cpu_state[tid] = {"seconds": cpu, "at": iso()}
            else:
                add_anomaly(state, anomalies, f"{tid}:dead",
                            f"- {tid} 标记 running 但 worker pid 不存在（可能僵死）")
            if elapsed > args.max_run_min:
                add_anomaly(state, anomalies, f"{tid}:long",
                            f"- {tid} 已运行 {elapsed:.0f} 分钟（> {args.max_run_min}，留意是否失控）")

        elif actual == "pending":
            deps = (t.get("task") or {}).get("depends_on") or []
            blocked = []
            for dep in deps:
                other = tasks.get(str(dep))
                if other and other["status"] == "failed":
                    add_anomaly(state, anomalies, f"{tid}:dep_failed",
                                f"- {tid} 依赖 {dep} 已失败，无法启动")
                elif not other or other["status"] not in ("done",):
                    blocked.append(str(dep))
            if age_min(t.get("created")) and age_min(t.get("created")) > args.blocked_min:
                add_anomaly(state, anomalies, f"{tid}:blocked",
                            f"- {tid} 等待超过 {args.blocked_min} 分钟"
                            + (f"（依赖: {', '.join(blocked)}）" if blocked else ""))

        elif actual == "done":
            g = t.get("git") or {}
            gs = g.get("status")
            fin_age = age_min(t.get("finished")) or 0
            if gs == "failed":
                add_anomaly(state, anomalies, f"{tid}:git_failed",
                            f"- {tid} Git 发布失败: {str(g.get('error') or g.get('reason') or '')[:180]}")
            elif gs in ("pending", "running") and fin_age > 15:
                add_anomaly(state, anomalies, f"{tid}:git_pending",
                            f"- {tid} 已完成 {fin_age:.0f} 分钟但 Git 仍未发布")
            elif not g and fin_age > 20:
                add_anomaly(state, anomalies, f"{tid}:git_missing",
                            f"- {tid} 已完成 {fin_age:.0f} 分钟，无 git.json（未发布）")

        elif actual == "failed":
            if first_run:
                if (age_min(t.get("finished")) or 1e9) <= 24 * 60:
                    recent_failed.append(f"- {tid} {short_title(t)}")
            elif tid not in (state.get("failed_seen") or {}):
                add_anomaly(state, anomalies, f"{tid}:failed",
                            f"- {tid} 失败: {short_title(t)} | {failed_snippet(t)}")

        ps = plan_status((t.get("task") or {}).get("plan_file"), tid)
        if not first_run and not plan_ok(actual, ps):
            add_anomaly(state, anomalies, f"{tid}:plan",
                        f"- {tid} 计划状态={ps!r} 与实际={actual!r} 不一致")

    # Infrastructure daemons
    if (counts["pending"] or counts["running"]):
        dpid = read_pid(DAEMON_PID)
        if not dpid or not pid_alive(dpid):
            add_anomaly(state, anomalies, "dispatcher:dead",
                        "- dispatcher daemon 未运行，队列不会推进")
    if counts["done"]:
        gpid = read_pid(GIT_PID)
        if not gpid or not pid_alive(gpid):
            add_anomaly(state, anomalies, "git:dead",
                        "- git_publisher daemon 未运行，完成任务可能不会自动发布")

    # First run: baseline, do not alert historical failures as new.
    if first_run:
        state["failed_seen"] = {tid: iso() for tid, t in tasks.items()
                                if t["status"] == "failed"}
    else:
        fs = state.setdefault("failed_seen", {})
        for tid, t in tasks.items():
            if t["status"] == "failed" and tid not in fs:
                fs[tid] = iso()
        cutoff = now() - timedelta(days=7)
        state["failed_seen"] = {
            k: v for k, v in fs.items()
            if (parse_time(v) or now()) > cutoff
        }

    state["seen"] = {tid: t["status"] for tid, t in tasks.items()}
    state["cpu"] = {k: v for k, v in cpu_state.items() if k in tasks and tasks[k]["status"] == "running"}
    state["last_check"] = iso()

    heartbeat = False
    last_digest = parse_time(state.get("last_digest"))
    if args.force or first_run or not last_digest or (now() - last_digest) > timedelta(hours=24):
        heartbeat = True
        state["last_digest"] = iso()

    if not (args.force or first_run or transitions or anomalies or heartbeat):
        return None, tasks, counts

    lines = []
    head = f"**任务巡检** {now().strftime('%m-%d %H:%M')}"
    lines.append(head)
    lines.append(f"运行 {counts['running']} · 等待 {counts['pending']} · "
                 f"完成 {counts['done']} · 失败 {counts['failed']}")
    if first_run:
        lines.append("监控已启用（首次基线，历史任务不重复报警）。")
    if recent_failed:
        lines.append("**近 24h 失败**")
        lines.extend(recent_failed[:8])
    if transitions:
        lines.append("**变化**")
        lines.extend(transitions[:12])
    if anomalies:
        lines.append("**需要关注**")
        lines.extend(anomalies[:12])
    if active:
        lines.append("**运行中**")
        for t in sorted(active, key=lambda x: x.get("started") or ""):
            el = age_min(t.get("started")) or 0
            lines.append(f"- {t['id']} {short_title(t)}（{el:.0f} 分钟）")
    if heartbeat and not first_run and not transitions and not anomalies:
        lines.append("（24h 心跳：队列正常）")
    return "\n".join(lines), tasks, counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--state", default=str(DEFAULT_STATE))
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--reset-state", action="store_true")
    ap.add_argument("--cpu-stall-min", type=float, default=30)
    ap.add_argument("--max-run-min", type=float, default=120)
    ap.add_argument("--blocked-min", type=float, default=180)
    args = ap.parse_args()

    state_path = Path(os.path.expanduser(args.state))
    if args.reset_state and state_path.exists():
        state_path.unlink()
    state = read_json(state_path) or {}
    first_run = not state_path.exists()
    if first_run:
        state = {"seen": {}, "cpu": {}, "notified": {}, "failed_seen": {},
                 "last_check": None, "last_digest": None}

    msg, tasks, counts = build(args, state, first_run)
    write_json(state_path, state)

    if args.json:
        print(json.dumps({
            "message": msg, "counts": counts,
            "tasks": {tid: {"status": t["status"],
                            "title": (t.get("task") or {}).get("title", "")}
                      for tid, t in tasks.items()},
        }, ensure_ascii=False, indent=2))
    elif msg:
        print(msg)


if __name__ == "__main__":
    main()
