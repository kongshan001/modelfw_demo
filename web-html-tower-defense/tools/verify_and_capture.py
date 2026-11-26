#!/usr/bin/env python3
"""
余烬堡 / Emberhold — 可复现验收 + 证据采集脚本。

用法（本机 Playwright 位于 /opt/anaconda3/bin/python）：
    /opt/anaconda3/bin/python tools/verify_and_capture.py
    /opt/anaconda3/bin/python tools/verify_and_capture.py --skip-video

做的事：
  1. file:// 与本地 http:// 加载，捕获 console/pageerror/网络请求
  2. 菜单/HUD 鼠标交互、建塔/升级/出售/暂停/倍速/AI 切换/换图
  3. ?autotest=1 让 AI 无人值守跑完两张图，断言胜利
  4. 1920x1080 截图（≥6，覆盖地图/建造/战斗/AI/过渡/胜利）
  5. 用固定步进渲染 1280x720 10s 演示帧 → MP4 + GIF（ffmpeg）
  6. 输出 captures/verification.json

说明：无头 Chromium 的 requestAnimationFrame 在本机会被节流，因此截图/视频
使用游戏自带的 QA 钩子 freeze()/fastForward()/holdTransition() 做确定性取景；
这些钩子不修改金币、冷却或 AI 规则，仅用于可复现截图。
"""
import argparse
import json
import hashlib
import os
import platform
import shutil
import socket
import subprocess
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "index.html"
CAP = ROOT / "captures"
FRAMES = Path("/tmp/emberhold_frames")
URL = GAME.as_uri()
CHROME_FLAGS = [
    "--disable-frame-rate-limit",
    "--disable-gpu-vsync",
    "--disable-background-timer-throttling",
    "--disable-backgrounding-occluded-windows",
    "--disable-renderer-backgrounding",
    "--disable-features=CalculateNativeWinOcclusion",
]

RESULTS = {
    "task": "T-20261126-022",
    "game": "余烬堡 / Emberhold",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "environment": {
        "platform": platform.platform(),
        "python": sys.version.split()[0],
        "cpu_count": os.cpu_count(),
        "loadavg": list(os.getloadavg()) if hasattr(os, "getloadavg") else None,
    },
    "source": {},
    "checks": [],
    "console_errors": [],
    "page_errors": [],
    "requests": [],
    "external_requests": [],
    "interactions": {},
    "autotests": {},
    "layout": {},
    "http": {},
    "performance": {},
    "screenshots": [],
    "video": {},
    "gif": {},
}
SCREENSHOTS = []
FAILS = 0
SEEN_REQUESTS = set()


def check(name, ok, detail=None):
    global FAILS
    rec = {"name": name, "ok": bool(ok)}
    if detail is not None:
        rec["detail"] = detail
    RESULTS["checks"].append(rec)
    if not ok:
        FAILS += 1
        print(f"  FAIL  {name}" + (f" — {detail}" if detail else ""))
    else:
        print(f"  ok    {name}" + (f" — {detail}" if detail is not None else ""))
    return ok


def attach(page, label):
    def on_console(msg):
        if msg.type == "error":
            RESULTS["console_errors"].append({"page": label, "text": msg.text})
    def on_pageerror(err):
        RESULTS["page_errors"].append({"page": label, "text": str(err)})
    def on_request(req):
        u = req.url
        if u not in SEEN_REQUESTS:
            SEEN_REQUESTS.add(u)
            RESULTS["requests"].append(u)
            if not (u.startswith("file:") or u.startswith("data:")
                    or u.startswith("http://127.0.0.1:")):
                RESULTS["external_requests"].append(u)
    page.on("console", on_console)
    page.on("pageerror", on_pageerror)
    page.on("request", on_request)


def new_page(browser, label, width=1920, height=1080):
    page = browser.new_page(viewport={"width": width, "height": height})
    page.set_default_timeout(20000)
    attach(page, label)
    return page


def load(page, url=URL, wait=600):
    page.goto(url, wait_until="load")
    page.wait_for_timeout(wait)


def state(page):
    return page.evaluate("Emberhold.state()")


def shot(page, name, expected=(1920, 1080)):
    CAP.mkdir(parents=True, exist_ok=True)
    path = CAP / name
    page.screenshot(path=str(path), full_page=False)
    with Image.open(path) as im:
        w, h = im.size
    size = path.stat().st_size
    SCREENSHOTS.append({
        "file": str(path.relative_to(ROOT)),
        "width": w, "height": h, "bytes": size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()[:16],
    })
    check(f"screenshot {name} {expected[0]}x{expected[1]}",
          (w, h) == expected, f"{w}x{h}, {size} bytes")
    return path


def finish_transition(page):
    page.evaluate("Emberhold.finishTransition()")
    page.wait_for_timeout(250)


def start_instant(page, map_id, ai, speed=1):
    page.evaluate(
        "([m,a,s]) => Emberhold.startGame({mapId:m, ai:a, speed:s, instant:true})",
        [map_id, ai, speed],
    )
    page.wait_for_timeout(350)


def stage_ai(page, map_id, min_wave=5, tries=260, require_projectile=True,
             min_wave_time=0, min_in_range=2, min_enemies=0):
    start_instant(page, map_id, True, 1)
    best = None
    for _ in range(tries):
        page.evaluate("Emberhold.fastForward(1.0)")
        s = state(page)
        if best is None or s["wave"] > best["wave"]:
            best = s
        if s["over"]:
            break
        if (s["wave"] >= min_wave and s["phase"] == "wave"
                and s.get("waveT", 0) >= min_wave_time
                and s["inRange"] >= min_in_range and s["enemies"] >= min_enemies
                and ((s["projectiles"] >= 1) if require_projectile else True)):
            return s
    return best or state(page)


def wait_fps(page, target=30, timeout=4.0):
    best = 0
    t0 = time.time()
    while time.time() - t0 < timeout:
        s = state(page)
        best = max(best, s.get("fps", 0))
        if s.get("fps", 0) >= target:
            return best
        page.wait_for_timeout(160)
    return best


def stop_quietly(page):
    try:
        page.close()
    except Exception:
        pass


def source_audit():
    import re
    html = GAME.read_text(encoding="utf-8")
    resource_tokens = [t for t in
        ("//cdn", "<script src", '<link rel="stylesheet"', "@import",
         "<img", "<audio", "<video", "fetch(", "XMLHttpRequest", "WebSocket")
        if t in html]
    urls = re.findall(r'https?://[^"\'\s)]+', html)
    benign = "http://www.w3.org/2000/svg"
    external_urls = [u for u in urls if u != benign]
    RESULTS["source"] = {
        "file": str(GAME.relative_to(ROOT)),
        "bytes": GAME.stat().st_size,
        "lines": html.count("\n") + 1,
        "sha256": hashlib.sha256(GAME.read_bytes()).hexdigest(),
        "resource_tokens_found": sorted(set(resource_tokens)),
        "external_urls": external_urls,
        "svg_namespace_only": benign in html,
        "note": "所有 JS/CSS/精灵均在 index.html 内；无外部图片/字体/音频/CDN。",
    }
    check("single self-contained index.html", GAME.exists() and GAME.stat().st_size > 10000,
          f"{GAME.stat().st_size} bytes")
    check("no external asset/script tags", not resource_tokens,
          RESULTS["source"]["resource_tokens_found"])
    check("no external URLs in index.html", not external_urls, external_urls)

def functional_ui(browser):
    print("\n[1/6] UI interaction / layout")
    page = new_page(browser, "ui")
    load(page)
    s = state(page)
    RESULTS["layout"]["1920x1080"] = {
        "canvas": s["canvas"], "viewport": [1920, 1080],
    }
    check("initial scene is menu", s["scene"] == "menu", s["scene"])
    check("1920x1080 canvas", s["canvas"] == {"width": "1920px", "height": "1080px"}, s["canvas"])

    # 地图卡：frost
    page.mouse.click(431 * 3, 180 * 3)
    page.wait_for_timeout(80)
    page.evaluate("Emberhold.finishTransition()")
    page.wait_for_timeout(220)
    s = state(page)
    check("menu card selects frost", s["mapId"] == "frost" and s["scene"] == "menu", s["mapId"])

    # 看 AI 打一局
    page.mouse.click(431 * 3, 276 * 3)
    page.wait_for_timeout(80)
    page.evaluate("Emberhold.finishTransition()")
    page.wait_for_timeout(500)
    s = state(page)
    RESULTS["interactions"]["ai_watch_start"] = {
        "scene": s["scene"], "mapId": s["mapId"], "aiOn": s["aiOn"], "speed": s["speed"],
    }
    check("AI watch starts an AI game", s["scene"] == "playing" and s["mapId"] == "frost" and s["aiOn"],
          s)

    # 暂停按钮 / 恢复按钮
    page.mouse.click(485 * 3, 339 * 3)
    page.wait_for_timeout(180)
    check("pause button pauses", state(page)["scene"] == "paused", state(page)["scene"])
    page.mouse.click(165 * 3, 232 * 3)
    page.wait_for_timeout(180)
    check("resume button resumes", state(page)["scene"] == "playing", state(page)["scene"])

    # 倍速按钮与 AI chip
    before = state(page)["speed"]
    page.mouse.click(518 * 3, 339 * 3)
    page.wait_for_timeout(150)
    after = state(page)["speed"]
    RESULTS["interactions"]["speed_button"] = [before, after]
    check("speed button cycles", after in (2, 3) and after != before, f"{before}->{after}")
    page.mouse.click(404 * 3, 12 * 3)
    page.wait_for_timeout(150)
    check("top AI chip toggles to manual", state(page)["aiOn"] is False)

    # 换图按钮
    page.mouse.click(584 * 3, 339 * 3)
    page.wait_for_timeout(80)
    page.evaluate("Emberhold.finishTransition()")
    page.wait_for_timeout(250)
    s = state(page)
    RESULTS["interactions"]["switch_map"] = {"mapId": s["mapId"], "scene": s["scene"]}
    check("HUD switch map button works", s["scene"] == "playing" and s["mapId"] == "ashen", s)
    stop_quietly(page)


def manual_interaction(browser):
    print("\n[2/6] Manual build / upgrade / sell / keyboard")
    page = new_page(browser, "manual")
    load(page)
    start_instant(page, "ashen", False, 1)
    cell = page.evaluate("""() => {
      const m = Emberhold.maps.ashen;
      let best = null, bd = 999;
      for (const c of m.buildCells) {
        const p = {x: c.cx * 16 + 8, y: 24 + c.cy * 16 + 8};
        const d = m.distanceToPath(p.x, p.y);
        if (c.cx > 2 && c.cx < 26 && c.cy > 1 && c.cy < 19 && d < 23 && d < bd) {
          bd = d; best = c;
        }
      }
      return best || m.buildCells[0];
    }""")
    RESULTS["interactions"]["build_cell"] = cell
    page.mouse.click(550 * 3, 53 * 3)       # 燧石哨塔卡
    page.wait_for_timeout(100)
    page.mouse.move((cell["cx"] * 16 + 8) * 3, (24 + cell["cy"] * 16 + 8) * 3)
    page.wait_for_timeout(150)
    page.mouse.click((cell["cx"] * 16 + 8) * 3, (24 + cell["cy"] * 16 + 8) * 3)
    page.wait_for_timeout(200)
    s = state(page)
    check("click build spends gold", s["gold"] == 100 and len(s["towers"]) == 1, s)
    page.keyboard.press("u")
    page.wait_for_timeout(180)
    s = state(page)
    check("U upgrades tower", s["gold"] == 55 and s["towers"][0]["level"] == 1, s)
    page.keyboard.press("s")
    page.wait_for_timeout(180)
    s = state(page)
    check("S sells tower", s["gold"] == 110 and len(s["towers"]) == 0, s)
    page.keyboard.press(" ")
    page.wait_for_timeout(150)
    check("Space pauses", state(page)["scene"] == "paused")
    page.keyboard.press(" ")
    page.wait_for_timeout(150)
    check("Space resumes", state(page)["scene"] == "playing")
    page.keyboard.press("a")
    page.wait_for_timeout(150)
    check("A hands control to AI", state(page)["aiOn"] is True)
    page.keyboard.press("a")
    page.wait_for_timeout(150)
    check("A returns to manual", state(page)["aiOn"] is False)
    page.keyboard.press("f")
    page.wait_for_timeout(150)
    check("F cycles speed", state(page)["speed"] == 2, state(page)["speed"])
    RESULTS["interactions"]["manual"] = {
        "build_cell": cell,
        "gold_after_build": 100,
        "gold_after_upgrade": 55,
        "gold_after_sell": 110,
        "keys": ["U", "S", "Space", "A", "F"],
    }
    stop_quietly(page)


def autotests(browser):
    print("\n[3/6] Unattended AI full runs")
    for i, map_id in enumerate(("ashen", "frost")):
        page = new_page(browser, f"autotest-{map_id}")
        load(page, URL + f"?autotest=1&map={map_id}", wait=300)
        page.wait_for_function("window.__AUTOTEST__ && window.__AUTOTEST__.done === true", timeout=120000)
        at = page.evaluate("window.__AUTOTEST__")
        RESULTS["autotests"][map_id] = at
        check(f"autotest {map_id} wins unattended",
              at.get("win") is True and at.get("timeout") is False,
              {k: at.get(k) for k in ("win", "lives", "wave", "kills", "simTime", "wallMs", "aiActions")})
        check(f"autotest {map_id} no cheat flag", at.get("cheats") is False and at.get("aiOn") is True)
        page.wait_for_timeout(1600)
        s = state(page)
        bench = page.evaluate("Emberhold.benchmark(80)")
        RESULTS["performance"][f"autotest_{map_id}_post_idle"] = {
            "fps": s["fps"], "perf": s["perf"], "benchmark": bench,
        }
        if map_id == "ashen":
            shot(page, "09-victory.png")
        stop_quietly(page)


def captures(browser):
    print("\n[4/6] 1920x1080 evidence screenshots")
    # 菜单 + 地图过渡 + 霜图菜单
    page = new_page(browser, "capture-menu")
    load(page)
    page.wait_for_timeout(500)
    shot(page, "01-menu-ashen.png")
    page.evaluate("Emberhold.selectMap('frost')")
    page.wait_for_timeout(60)
    held = page.evaluate("Emberhold.holdTransition(0.55)")
    check("transition can be staged", held is True)
    page.wait_for_timeout(150)
    shot(page, "03-map-transition.png")
    page.evaluate("Emberhold.finishTransition()")
    page.wait_for_timeout(350)
    shot(page, "02-menu-frost.png")
    check("menu map switch applied", state(page)["mapId"] == "frost")
    stop_quietly(page)

    # 建造预览 + 暂停（手动局）
    page = new_page(browser, "capture-build")
    load(page)
    start_instant(page, "ashen", False, 1)
    cell = page.evaluate("""() => {
      const m = Emberhold.maps.ashen;
      let best = null, bd = 999;
      for (const c of m.buildCells) {
        const p = {x: c.cx * 16 + 8, y: 24 + c.cy * 16 + 8};
        const d = m.distanceToPath(p.x, p.y);
        if (c.cx > 2 && c.cx < 26 && c.cy > 1 && c.cy < 19 && d < 23 && d < bd) {
          bd = d; best = c;
        }
      }
      return best || m.buildCells[0];
    }""")
    page.mouse.click(550 * 3, 53 * 3)
    page.wait_for_timeout(100)
    page.mouse.move((cell["cx"] * 16 + 8) * 3, (24 + cell["cy"] * 16 + 8) * 3)
    page.wait_for_timeout(200)
    page.evaluate("Emberhold.freeze(true)")
    page.wait_for_timeout(300)
    wait_fps(page, 30, 2.0)
    shot(page, "04-build-preview.png")
    page.evaluate("Emberhold.freeze(false)")
    page.mouse.click((cell["cx"] * 16 + 8) * 3, (24 + cell["cy"] * 16 + 8) * 3)
    page.wait_for_timeout(200)
    page.keyboard.press(" ")
    page.wait_for_timeout(300)
    shot(page, "10-pause.png")
    stop_quietly(page)

    # AI 战斗 / AI 决策 / Boss
    page = new_page(browser, "capture-combat")
    load(page)
    staged = stage_ai(page, "ashen", min_wave=6, require_projectile=True, min_wave_time=6, min_in_range=3, min_enemies=8)
    RESULTS["staged_combat"] = {"wave": staged["wave"], "inRange": staged["inRange"],
                                "enemies": staged["enemies"], "towers": len(staged["towers"])}
    page.evaluate("Emberhold.freeze(true)")
    page.wait_for_timeout(500)
    wait_fps(page, 30, 3.0)
    shot(page, "05-wave-combat.png")
    page.evaluate("Emberhold.fastForward(2.0)")
    page.wait_for_timeout(150)
    shot(page, "06-ai-command.png")

    # 快进到 Boss 出现（同一 AI 局；暂停更新只在捕获时冻结）
    boss_found = False
    for _ in range(800):
        page.evaluate("Emberhold.fastForward(1.0)")
        s = state(page)
        if s.get("over"):
            break
        if s.get("wave", 0) >= 11:
            # 波次 11 末尾/12 用更小步长，避免 Boss 被秒杀后才取景
            for _ in range(12):
                page.evaluate("Emberhold.fastForward(0.2)")
                s = state(page)
                if s.get("boss") or s.get("over"):
                    break
        if s.get("boss"):
            boss_found = True
            break
        if s.get("wave", 0) >= 12 and s.get("phase") == "done":
            break
    s = state(page)
    RESULTS["interactions"]["boss_stage"] = {
        "found": boss_found, "wave": s.get("wave"), "over": s.get("over"),
    }
    if boss_found:
        # 继续让 Boss 走进画面（页面此时已冻结，fastForward 只推进模拟）
        boss_visible = False
        for _ in range(120):
            page.evaluate("Emberhold.fastForward(0.15)")
            s = state(page)
            b = s.get("boss")
            if not b:
                break
            if b.get("x", 0) >= 90:
                boss_visible = True
                break
        RESULTS["interactions"]["boss_visible"] = boss_visible
        check("boss on screen for screenshot", boss_visible, s.get("boss"))
        if boss_visible:
            page.wait_for_timeout(300)
            wait_fps(page, 30, 2.0)
            shot(page, "07-boss-wave.png")
    else:
        check("boss wave staged", False, s.get("over"))
    stop_quietly(page)

    # 霜图战斗
    page = new_page(browser, "capture-frost")
    load(page)
    staged_f = stage_ai(page, "frost", min_wave=6, require_projectile=True, min_wave_time=14, min_in_range=4, min_enemies=5)
    staged_f = state(page)
    RESULTS["staged_frost"] = {"wave": staged_f["wave"], "waveT": staged_f["waveT"],
                               "inRange": staged_f["inRange"], "enemies": staged_f["enemies"],
                               "towers": len(staged_f["towers"]), "over": staged_f["over"]}
    page.evaluate("Emberhold.freeze(true)")
    page.wait_for_timeout(500)
    wait_fps(page, 30, 3.0)
    shot(page, "08-frost-assault.png")
    stop_quietly(page)

    RESULTS["screenshots"] = SCREENSHOTS
    check("at least six 1920x1080 screenshots",
          len([s for s in SCREENSHOTS if (s["width"], s["height"]) == (1920, 1080)]) >= 6,
          len(SCREENSHOTS))


def video_capture(browser):
    print("\n[5/6] 10s 1280x720 demo frames")
    if FRAMES.exists():
        shutil.rmtree(FRAMES)
    FRAMES.mkdir(parents=True, exist_ok=True)
    page = new_page(browser, "video", 1280, 720)
    load(page)
    staged = stage_ai(page, "ashen", min_wave=6, require_projectile=True, min_wave_time=10, min_in_range=3, min_enemies=8)
    if not state(page).get("over"):
        page.evaluate("Emberhold.fastForward(4.0)")
    staged = state(page)
    page.evaluate("Emberhold.freeze(true)")
    page.wait_for_timeout(400)
    RESULTS["video_stage"] = {"wave": staged["wave"], "enemies": staged["enemies"],
                              "inRange": staged["inRange"], "towers": len(staged["towers"])}
    total = 300
    t0 = time.time()
    for i in range(total):
        page.evaluate("Emberhold.fastForward(1/30)")
        page.screenshot(path=str(FRAMES / f"frame_{i:04d}.png"), full_page=False)
        if i % 60 == 59:
            print(f"  frames {i + 1}/{total} ({time.time() - t0:.1f}s)")
    stop_quietly(page)

    CAP.mkdir(parents=True, exist_ok=True)
    mp4 = CAP / "emberhold-demo.mp4"
    gif = CAP / "emberhold-demo.gif"
    try:
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error", "-framerate", "30",
            "-i", str(FRAMES / "frame_%04d.png"),
            "-c:v", "libx264", "-preset", "fast", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4),
        ], check=True)
        probe_mp4 = ffprobe(mp4)
        RESULTS["video"] = {"file": str(mp4.relative_to(ROOT)), "bytes": mp4.stat().st_size, **probe_mp4}
        check("MP4 demo >= 10s", np_dur(probe_mp4.get("duration")) >= 9.9, probe_mp4)
    except Exception as exc:
        RESULTS["video"] = {"error": repr(exc)}
        check("MP4 demo encodes", False, repr(exc))

    try:
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error", "-framerate", "30",
            "-i", str(FRAMES / "frame_%04d.png"), "-t", "10",
            "-vf", "fps=15,scale=960:-1:flags=neighbor,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3",
            str(gif),
        ], check=True)
        probe_gif = ffprobe(gif)
        RESULTS["gif"] = {"file": str(gif.relative_to(ROOT)), "bytes": gif.stat().st_size, **probe_gif}
        check("GIF demo >= 9s", np_dur(probe_gif.get("duration")) >= 9.0, probe_gif)
    except Exception as exc:
        RESULTS["gif"] = {"error": repr(exc)}
        check("GIF demo encodes", False, repr(exc))
    shutil.rmtree(FRAMES, ignore_errors=True)


def np_dur(d):
    try:
        return float(d)
    except (TypeError, ValueError):
        return 0.0


def ffprobe(path):
    try:
        out = subprocess.run([
            "ffprobe", "-v", "error", "-show_entries",
            "format=duration,size:stream=width,height,avg_frame_rate,nb_frames",
            "-of", "json", str(path),
        ], capture_output=True, text=True, check=True).stdout
        data = json.loads(out)
        st = (data.get("streams") or [{}])[0]
        fmt = data.get("format") or {}
        return {
            "duration": float(fmt.get("duration", 0) or 0),
            "width": st.get("width"), "height": st.get("height"),
            "fps": st.get("avg_frame_rate"), "frames": st.get("nb_frames"),
            "bytes": int(fmt.get("size", 0) or 0),
        }
    except Exception as exc:
        return {"error": repr(exc)}


def http_test(browser):
    print("\n[6/6] Local HTTP serving / responsive layout")
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    srv = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1"],
        cwd=str(ROOT), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(60):
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.1)
        page = new_page(browser, "http", 1280, 720)
        local_reqs = []
        page.on("request", lambda r: local_reqs.append(r.url))
        load(page, f"http://127.0.0.1:{port}/index.html", wait=900)
        s = state(page)
        RESULTS["layout"]["1280x720"] = {"canvas": s["canvas"], "viewport": [1280, 720]}
        RESULTS["http"] = {
            "url": f"http://127.0.0.1:{port}/index.html",
            "scene": s["scene"],
            "canvas": s["canvas"],
            "requests": local_reqs,
            "errors": [e for e in RESULTS["console_errors"] if e["page"] == "http"],
        }
        check("HTTP load works", s["scene"] == "menu", s["scene"])
        check("1280x720 canvas", s["canvas"] == {"width": "1280px", "height": "720px"}, s["canvas"])
        check("HTTP only same-origin requests",
              all(u.startswith(f"http://127.0.0.1:{port}/") for u in local_reqs), local_reqs)
        stop_quietly(page)
    finally:
        srv.terminate()
        try:
            srv.wait(timeout=3)
        except subprocess.TimeoutExpired:
            srv.kill()


def main():
    global FAILS
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-video", action="store_true")
    args = parser.parse_args()
    CAP.mkdir(parents=True, exist_ok=True)
    print("Emberhold verification")
    print("  game:", GAME)
    source_audit()
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=CHROME_FLAGS)
        try:
            functional_ui(browser)
            manual_interaction(browser)
            autotests(browser)
            captures(browser)
            if not args.skip_video:
                video_capture(browser)
            else:
                RESULTS["video"]["skipped"] = True
                RESULTS["gif"]["skipped"] = True
            http_test(browser)
        finally:
            browser.close()

    # 汇总
    all_fps = [v.get("benchmark", {}).get("fps", 0) for v in RESULTS["performance"].values()]
    check("render benchmark >= 30 fps", (min(all_fps) if all_fps else 0) >= 30,
          min(all_fps) if all_fps else 0)
    check("no console errors", len(RESULTS["console_errors"]) == 0,
          len(RESULTS["console_errors"]))
    check("no page errors", len(RESULTS["page_errors"]) == 0,
          len(RESULTS["page_errors"]))
    check("no external network requests", len(RESULTS["external_requests"]) == 0,
          RESULTS["external_requests"])
    check("screenshots >= 6 @1920x1080", len(SCREENSHOTS) >= 6, len(SCREENSHOTS))
    RESULTS["summary"] = {
        "checks": len(RESULTS["checks"]),
        "failed": sum(1 for c in RESULTS["checks"] if not c["ok"]),
        "screenshots": len(SCREENSHOTS),
        "autotests": {k: {"win": v.get("win"), "lives": v.get("lives"),
                          "kills": v.get("kills"), "wallMs": v.get("wallMs")}
                      for k, v in RESULTS["autotests"].items()},
    }
    out = CAP / "verification.json"
    out.write_text(json.dumps(RESULTS, ensure_ascii=False, indent=2), encoding="utf-8")
    print("\nSUMMARY")
    print(json.dumps(RESULTS["summary"], ensure_ascii=False, indent=2))
    print("\nwrote", out)
    if FAILS:
        print(f"\n{FAILS} check(s) FAILED")
        sys.exit(1)
    print("\nALL CHECKS PASSED")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        CAP.mkdir(parents=True, exist_ok=True)
        RESULTS["fatal"] = traceback.format_exc()
        (CAP / "verification.json").write_text(
            json.dumps(RESULTS, ensure_ascii=False, indent=2), encoding="utf-8")
        sys.exit(2)
