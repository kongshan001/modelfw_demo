#!/usr/bin/env python3
"""Export Action Forge variants from an already-prepared browser profile.

Prerequisite: in the profile (default /tmp/af_profile) the KayKit Rogue must be
uploaded/kept and the Michelle Walk clip imported (see docs/action-forge-test.md
sections 6.2 steps 2-4). Then run:
    /opt/anaconda3/bin/python action-forge-test/scripts/af_export_variants.py
Outputs: exports/Rogue_MichelleWalk_AF_{inplace,rootmotion,inplace_animonly}.glb
The Speed=1.5 nudge in the Adjust panel is a preview-only edit; it is not baked.
"""
from playwright.sync_api import sync_playwright
import os, time, re, json
PROFILE=os.environ.get("AF_PROFILE", "/tmp/af_profile"); ARGS=["--enable-unsafe-swiftshader","--use-gl=angle","--use-angle=swiftshader","--disable-gpu-sandbox","--ignore-gpu-blocklist"]
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOT=os.path.join(ROOT, "screenshots")
EXP=os.path.join(ROOT, "exports")
os.makedirs(EXP, exist_ok=True)
def open_download(page):
    btn=page.get_by_role("button", name=re.compile("DOWNLOAD", re.I)).first
    # ensure open
    exp=btn.get_attribute("aria-expanded")
    if exp!="true": btn.click(); page.wait_for_timeout(800)
def dl(page, fname):
    with page.expect_download(timeout=180000) as info:
        page.locator("#lib-bundle-go").click()
    d=info.value
    p=os.path.join(EXP, fname)
    d.save_as(p)
    print("DOWNLOADED", d.suggested_filename, "->", p, os.path.getsize(p), flush=True)
    page.wait_for_timeout(2500)
    return p
with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(PROFILE, headless=True, args=ARGS, viewport={"width":1280,"height":720}, accept_downloads=True)
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    logs=[]; page.on("console", lambda m: logs.append(f"{m.type}: {m.text[:200]}")); page.on("pageerror", lambda e: logs.append(f"PAGEERROR: {e}"))
    page.goto("https://actionforge.app/", wait_until="domcontentloaded", timeout=90000)
    for i in range(90):
        if "pelvis" in page.evaluate("()=>document.body.innerText"): break
        time.sleep(1)
    page.locator('.wsw-tab', has_text='ANIMATE').first.click(); page.wait_for_timeout(800)
    page.evaluate("()=>{document.querySelector('#ws-tab-animate').click()}"); page.wait_for_timeout(800)
    page.locator('button[data-sub="adjust"]').click(); page.wait_for_timeout(800)
    sp=page.locator('input[aria-label="Speed"]')
    sp.evaluate("""el=>{el.value='1.5'; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true}));}""")
    page.wait_for_timeout(500)
    print("speed", sp.input_value(), page.evaluate("()=>document.querySelector('input[aria-label=\\\"Speed\\\"]').closest('.lib-adj__row').innerText.replace(/\\n/g,' ')"), flush=True)
    page.screenshot(path=f"{SHOT}/speed_1_5.png")
    open_download(page)
    page.screenshot(path=f"{SHOT}/download_panel2.png")
    print("inplace:", page.locator("#lib-inplace").is_checked(), "motion:", page.locator("#lib-bundle-motion").is_checked(), "fmt:", page.locator("#lib-bundle-format").input_value(), "skel:", page.locator("#lib-bundle-skeleton").input_value(), flush=True)
    # 1) in place + character
    if not page.locator("#lib-inplace").is_checked(): page.locator("#lib-inplace").check()
    p1=dl(page, "Rogue_MichelleWalk_AF_inplace.glb")
    page.screenshot(path=f"{SHOT}/after_export_inplace.png")
    # 2) root motion + character
    open_download(page)
    page.locator("#lib-inplace").uncheck(); page.wait_for_timeout(300)
    page.screenshot(path=f"{SHOT}/download_rootmotion.png")
    p2=dl(page, "Rogue_MichelleWalk_AF_rootmotion.glb")
    # 3) motion only + in place
    open_download(page)
    page.locator("#lib-inplace").check(); page.locator("#lib-bundle-motion").check(); page.wait_for_timeout(300)
    page.screenshot(path=f"{SHOT}/download_motion_only2.png")
    p3=dl(page, "Rogue_MichelleWalk_AF_inplace_animonly.glb")
    # 4) Godot plugin (official static link) — just verify URL/status, do not ship
    href=page.locator("#lib-godot-plugin").get_attribute("href")
    print("godot plugin href:", href, flush=True)
    print("=== logs ==="); print("\n".join(logs[-8:]))
    ctx.close()
