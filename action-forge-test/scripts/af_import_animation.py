#!/usr/bin/env python3
"""Import Michelle_Walk into an Action Forge browser profile (Setup > Import, Root travels)."""
from playwright.sync_api import sync_playwright
import os, time, re, json
PROFILE=os.environ.get("AF_PROFILE", "/tmp/af_profile"); ARGS=["--enable-unsafe-swiftshader","--use-gl=angle","--use-angle=swiftshader","--disable-gpu-sandbox","--ignore-gpu-blocklist"]
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOT=os.path.join(ROOT, "screenshots")
ANIM=os.path.abspath(os.path.join(ROOT, "..", "animation-retarget-kit", "examples", "soldier_to_michelle", "Michelle_Walk.glb"))
with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(PROFILE, headless=True, args=ARGS, viewport={"width":1280,"height":720}, accept_downloads=True)
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    logs=[]; page.on("console", lambda m: logs.append(f"{m.type}: {m.text[:250]}")); page.on("pageerror", lambda e: logs.append(f"PAGEERROR: {e}"))
    page.goto("https://actionforge.app/", wait_until="domcontentloaded", timeout=90000)
    for i in range(90):
        if "pelvis" in page.evaluate("()=>document.body.innerText"): break
        time.sleep(1)
    page.get_by_text("Setup", exact=True).first.click(); page.wait_for_timeout(1200)
    page.get_by_text("Import", exact=True).first.click(); page.wait_for_timeout(1200)
    page.screenshot(path=f"{SHOT}/import_panel.png")
    body=page.evaluate("()=>document.body.innerText")
    k=body.find("IMPORT")
    print("=== import panel ==="); print(body[k:k+1600] if k>=0 else body[:2000])
    info=page.evaluate("""()=>{const vis=el=>{const r=el.getBoundingClientRect();return r.width>0&&r.height>0};return {buttons:[...document.querySelectorAll('button')].filter(vis).map(b=>(b.innerText||b.title||'').trim().replace(/\\s+/g,' ').slice(0,90)), inputs:[...document.querySelectorAll('input[type=file]')].map(i=>({accept:i.accept,multiple:i.multiple,hidden:i.hidden}))}}""")
    print(json.dumps(info,indent=1,ensure_ascii=False)[:9000])
    # choose root travels
    rt=page.get_by_text(re.compile("Root travels", re.I))
    print("root travels count", rt.count(), flush=True)
    if rt.count(): rt.first.click(); page.wait_for_timeout(500)
    page.screenshot(path=f"{SHOT}/import_panel_motion.png")
    # direct set on first file input
    page.locator('input[type=file]').first.set_input_files(ANIM)
    print("set input", flush=True)
    for i in range(90):
        page.wait_for_timeout(2000)
        body=page.evaluate("()=>document.body.innerText")
        busy = any(k in body for k in ["Reading","Importing","Checking","Preparing","Retargeting","Keeping"])
        print(f"{(i+1)*2}s busy={busy}", flush=True)
        if i in (1,4,9,19,44): page.screenshot(path=f"{SHOT}/import_wait_{i}.png")
        if not busy and i>0: break
    page.wait_for_timeout(2000)
    page.screenshot(path=f"{SHOT}/import_done.png")
    body=page.evaluate("()=>document.body.innerText")
    print("=== after import ==="); print(body[:3000])
    print("=== logs ==="); print("\n".join(logs[-15:]))
    ctx.close()
