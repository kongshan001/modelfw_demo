#!/usr/bin/env python3
"""Upload a corrected Mixamo Michelle target and export Walk Loop (T-013).

Prerequisite: a persistent Chromium profile (AF_PROFILE) with KayKit Rogue
already uploaded (same profile as af_layer_export.py). The target GLB should
have its armature scale applied first (Blender: import Michelle, select armature,
Object > Apply > Scale) so the root node has no 0.01 scale; otherwise Action Forge
shows it as 1 cm. This script uses /tmp/Michelle_scaled.glb.

Known app bug (documented in docs/action-forge-test.md §4): the app shows a
~1.8 m target as "63 cm" and the raw export has a 2.692 m mesh AABB (1.618× the
1.664 m source). A uniform 0.618 root-node scale corrects the in-place export;
root-motion export is broken (hips Y 2.357 m). This script does NOT hide that —
it downloads the raw app output.

Run:
    /opt/anaconda3/bin/python action-forge-test/scripts/af_character_retarget.py
Outputs: exports/Michelle_WalkLoop_AF_{inplace.glb,rootmotion.glb,fbx}
"""
from playwright.sync_api import sync_playwright
import os, time, json, re, shutil
PROFILE=os.environ.get("AF_PROFILE","/tmp/af_profile")
ARGS=["--enable-unsafe-swiftshader","--use-gl=angle","--use-angle=swiftshader","--disable-gpu-sandbox","--ignore-gpu-blocklist"]
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.environ.get("AF_OUT","/tmp/af_character_retarget"); os.makedirs(OUT,exist_ok=True)
EXP=os.path.join(ROOT,"exports"); SHOT=os.path.join(ROOT,"screenshots")
TARGET=os.environ.get("AF_MICHELLE_GLB","/tmp/Michelle_scaled.glb")
t0=time.time(); logf=open(OUT+"/log.txt","w")
def log(*a):
    s=f"[{time.time()-t0:6.1f}s] "+" ".join(str(x) for x in a); print(s,flush=True); logf.write(s+"\n"); logf.flush()
def body(page):
    try: return page.evaluate("()=>document.body.innerText")
    except Exception as e: return "ERR "+str(e)
def snap(page,name):
    try:
        p=os.path.join(OUT,name+".png"); page.screenshot(path=p,timeout=120000); return p
    except Exception as e: log("SNAP_FAIL",name,str(e)[:120]); return None
def dump(page,name):
    t=body(page); open(f"{OUT}/{name}.txt","w").write(t); log("DUMP",name,len(t)); return t
def unfold(page):
    for k in range(4):
        cls=page.locator('#lib-seq').get_attribute('class') or ''
        if 'is-folded' not in cls: return True
        page.locator('#timelineEditor').click(); page.wait_for_timeout(900)
    return False
def seq(page): return page.evaluate("()=>document.querySelector('#lib-seq')?.innerText||''")
def lib(page,q):
    page.locator('#ws-tab-library').click(); page.wait_for_timeout(500)
    page.locator('#lib-tab-anims').click(); page.wait_for_timeout(500)
    page.locator('#lib-search').fill(q); page.wait_for_timeout(900)
def pick(page,cid,on=True):
    return page.evaluate("""({cid,on})=>{const t=document.querySelector('.lib-tile[data-id="'+cid+'"]');if(!t)return{ok:false};const p=t.querySelector('.lib-tile__pick');if(!p)return{ok:false};const cur=p.getAttribute('aria-checked')==='true';if(cur!==on)p.click();return{ok:true,was:cur,now:p.getAttribute('aria-checked')};}""",{"cid":cid,"on":on})
def add_selected(page):
    page.locator('.ws-icontab[data-tab="setup"]').first.click(); page.wait_for_timeout(500)
    m=page.locator('.ws-icontab[data-sub="compose"]').first
    if m.count() and m.is_visible(): m.click(); page.wait_for_timeout(700)
    a=page.get_by_role("button", name=re.compile(r"\+\s*ADD SELECTED",re.I))
    if a.count() and a.first.is_visible(): a.first.click(); page.wait_for_timeout(2500); return True
    return False
def ensure_walk(page):
    if "Walk Loop" in seq(page): return True
    lib(page,"walk"); pick(page,"walk_loop",True); log("add walk",add_selected(page)); page.wait_for_timeout(800)
    return "Walk Loop" in seq(page)
def open_download(page):
    btn=page.get_by_role("button", name=re.compile("DOWNLOAD",re.I)).first
    if btn.get_attribute("aria-expanded")!="true": btn.click(); page.wait_for_timeout(900)
def dl(page, fname):
    with page.expect_download(timeout=300000) as info:
        page.locator("#lib-bundle-go").click()
    d=info.value; p=os.path.join(EXP,fname); d.save_as(p)
    log("DOWNLOADED",d.suggested_filename,"->",fname,os.path.getsize(p)); page.wait_for_timeout(2500)
with sync_playwright() as p:
    ctx=p.chromium.launch_persistent_context(PROFILE,headless=True,args=ARGS,viewport={"width":1280,"height":720},accept_downloads=True)
    page=ctx.pages[0] if ctx.pages else ctx.new_page(); page.set_default_timeout(90000)
    logs=[]; page.on("console",lambda m: logs.append(f"{m.type}:{m.text[:300]}")); page.on("pageerror",lambda e: logs.append(f"PAGEERROR:{e}"))
    def on_fc(fc):
        try: log("FILECHOOSER"); fc.set_files(TARGET); log("FILECHOOSER set")
        except Exception as e: log("FILECHOOSER err",str(e)[:150])
    page.on("filechooser", on_fc)
    page.goto("https://actionforge.app/",wait_until="domcontentloaded",timeout=120000)
    for i in range(300):
        t=body(page)
        if "pelvis" in t and "Loading ActionForge" not in t: break
        time.sleep(1)
    log("ready",i); unfold(page)
    page.locator('.ws-icontab[data-tab="setup"]').first.click(); page.wait_for_timeout(500)
    ch=page.locator('.ws-icontab[data-sub="rig"]').first
    if ch.count() and ch.is_visible(): ch.click(); page.wait_for_timeout(800)
    log("chars before",repr(body(page)[:1500]))
    # upload scaled Michelle via JS tile click
    clicked=page.evaluate("""()=>{const t=[...document.querySelectorAll('.lib-tile')].find(e=>(e.dataset.words||'')==='+ Rigged character'); if(t){t.click(); return true;} return false;}""")
    log("js clicked rigged",clicked); page.wait_for_timeout(4000)
    for k in range(90):
        page.wait_for_timeout(2000)
        t=body(page)
        busy=any(x in t for x in ["Reading","Importing","Checking","Preparing","Retargeting","Keeping","Scaling","Shrinking"])
        if k%5==0: log("import poll",k,"busy",busy,"scaled","Michelle_scaled" in t)
        if "Michelle_scaled" in t and not busy: break
    snap(page,"01_scaled_import"); dump(page,"01_scaled_import")
    log("chars after",repr(body(page)[:2500]))
    # select scaled tile and wear if enabled
    tile=page.locator('.lib-tile:has-text("Michelle_scaled")').first
    if tile.count(): tile.click(); page.wait_for_timeout(800)
    wear=page.get_by_role("button", name=re.compile(r"^WEAR$",re.I))
    if wear.count():
        log("wear disabled",wear.first.is_disabled(),"visible",wear.first.is_visible())
        if wear.first.is_visible() and not wear.first.is_disabled(): wear.first.click(); page.wait_for_timeout(2000); log("clicked wear")
        else: log("already worn")
    snap(page,"02_scaled_worn"); dump(page,"02_scaled_worn")
    # retarget panel screenshot
    gear=page.get_by_role("button", name=re.compile(r"RETARGET",re.I))
    if gear.count() and gear.first.is_visible():
        gear.first.click(); page.wait_for_timeout(1200); snap(page,"03_retarget_panel"); dump(page,"03_retarget_panel")
        for pat in ["DONE","Done","BACK","CLOSE","Close"]:
            b=page.get_by_role("button", name=re.compile('^'+pat+'$',re.I))
            if b.count() and b.first.is_visible(): b.first.click(); page.wait_for_timeout(800); break
    ensure_walk(page); snap(page,"04_walk"); log("seq",repr(seq(page)[-500:]))
    open_download(page); snap(page,"05_download")
    log("inplace disabled",page.locator("#lib-inplace").is_disabled(),"checked",page.locator("#lib-inplace").is_checked())
    log("download tail",repr(body(page)[-1200:]))
    if not page.locator("#lib-inplace").is_disabled():
        try: page.select_option("#lib-bundle-format","glb")
        except: pass
        if not page.locator("#lib-inplace").is_checked(): page.locator("#lib-inplace").check()
        dl(page,"Michelle_WalkLoop_AF_inplace.glb")
        open_download(page)
        if page.locator("#lib-inplace").is_checked(): page.locator("#lib-inplace").uncheck()
        page.wait_for_timeout(1000)
        dl(page,"Michelle_WalkLoop_AF_rootmotion.glb")
        open_download(page)
        try: page.select_option("#lib-bundle-format","fbx")
        except: pass
        if not page.locator("#lib-inplace").is_checked(): page.locator("#lib-inplace").check()
        dl(page,"Michelle_WalkLoop_AF.fbx")
    snap(page,"06_export_done")
    for n in os.listdir(OUT):
        if n.endswith(".png"): shutil.copy(os.path.join(OUT,n),os.path.join(SHOT,"t013_michelle_"+n))
    open(OUT+"/console.txt","w").write("\n".join(logs[-60:]))
    log("done"); ctx.close()
logf.close()
