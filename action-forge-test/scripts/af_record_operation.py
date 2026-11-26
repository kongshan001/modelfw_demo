#!/usr/bin/env python3
"""Record a real Action Forge adjust/download session with Playwright.

The app's initial load can take minutes in a slow/headless environment; this
script records the whole session, so trim to the interesting segment afterwards.
The shipped recordings/af_operation.mp4 is a 14 s highlight cut from two such
sessions (Retarget screen + Download panel); raw videos are not shipped.
"""
from playwright.sync_api import sync_playwright
import time, os, re, json
PROFILE=os.environ.get("AF_PROFILE", "/tmp/af_profile"); ARGS=["--enable-unsafe-swiftshader","--use-gl=angle","--use-angle=swiftshader","--disable-gpu-sandbox","--ignore-gpu-blocklist"]
BASE=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW=os.path.join(BASE,"recordings","af_raw2"); os.makedirs(RAW, exist_ok=True)
for f in os.listdir(RAW): os.remove(os.path.join(RAW,f))
t0=time.time()
def log(*a): print(f"[{time.time()-t0:6.1f}s]", *a, flush=True)
with sync_playwright() as p:
    ctx=p.chromium.launch_persistent_context(PROFILE, headless=True, args=ARGS,
        viewport={"width":1280,"height":720}, accept_downloads=True,
        record_video_dir=RAW, record_video_size={"width":1280,"height":720})
    page=ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto("https://actionforge.app/", wait_until="domcontentloaded", timeout=120000)
    for i in range(200):
        t=page.evaluate("()=>document.body.innerText")
        if "pelvis" in t and "Loading ActionForge" not in t: break
        time.sleep(1)
    log("ready", i)
    page.wait_for_timeout(1200)
    page.locator('.wsw-tab', has_text='ANIMATE').first.click(); page.wait_for_timeout(600)
    page.evaluate("()=>{const e=document.querySelector('#ws-tab-animate'); if(e)e.click()}"); page.wait_for_timeout(600)
    adj=page.locator('button[data-sub="adjust"]')
    t_adj=time.time()-t0
    if adj.count(): adj.first.click()
    log("adjust", t_adj)
    page.wait_for_timeout(2200)
    # nudge speed slider visibly (ArrowRight a few times)
    sp=page.locator('input[aria-label="Speed"]')
    if sp.count():
        sp.focus()
        for _ in range(4): page.keyboard.press("ArrowRight")
    page.wait_for_timeout(1500)
    t_dl=time.time()-t0
    page.get_by_role("button", name=re.compile("DOWNLOAD", re.I)).first.click(); page.wait_for_timeout(900)
    checked=page.evaluate("()=>{const e=document.querySelector('#lib-inplace');return e?e.checked:null}")
    log("download panel", t_dl, "inplace", checked)
    if checked is False:
        page.locator('#lib-inplace-row').click(); page.wait_for_timeout(500)
    page.wait_for_timeout(900)
    with page.expect_download(timeout=120000) as dl:
        page.locator('#lib-bundle-go').click()
    d=dl.value; outp=os.path.join(BASE,"recordings","af_operation_export.glb"); d.save_as(outp)
    t_done=time.time()-t0
    log("downloaded", d.suggested_filename, os.path.getsize(outp), "t", t_done)
    page.wait_for_timeout(2000)
    t_end=time.time()-t0
    log("end", t_end)
    ctx.close()
vids=[os.path.join(RAW,f) for f in os.listdir(RAW) if f.endswith('.webm')]
print("VIDEO", vids)
json.dump({"t_adj":t_adj,"t_dl":t_dl,"t_done":t_done,"t_end":t_end,"video":vids}, open(os.path.join(BASE,"recordings","af_short_timing.json"),"w"))
