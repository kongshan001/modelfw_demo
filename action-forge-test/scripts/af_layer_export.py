#!/usr/bin/env python3
"""Export Action Forge's base Walk + upper-body Idle Talking layer (T-013).

Prerequisite: a persistent Chromium profile (AF_PROFILE, default /tmp/af_profile)
where KayKit Rogue has already been uploaded/worn. The script removes any stale
Idle Talking layer, rebuilds base Walk Loop + a new layer, adds Idle Talking,
sets the layer weight to 100%, then downloads GLB (in-place) and FBX.

The critical UI details (also in docs/action-forge-test.md §2):
- tick the library tile, then Setup > Mask > + ADD SELECTED;
- select the new layer in Animate > Adjust > LAYERS before adding the second clip;
- DO NOT drag the strip after adding it: that resets the mask to Full body;
- don't click the layer head at x~60: that can hit the mini weight slider and set 0.

Run:
    /opt/anaconda3/bin/python action-forge-test/scripts/af_layer_export.py
Outputs: action-forge-test/exports/Rogue_Walk_IdleTalkLayer_AF_{inplace.glb,fbx}
"""
from playwright.sync_api import sync_playwright
import os, time, json, re, shutil
PROFILE=os.environ.get("AF_PROFILE","/tmp/af_profile")
ARGS=["--enable-unsafe-swiftshader","--use-gl=angle","--use-angle=swiftshader","--disable-gpu-sandbox","--ignore-gpu-blocklist"]
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.environ.get("AF_OUT","/tmp/af_layer_export"); os.makedirs(OUT,exist_ok=True)
EXP=os.path.join(ROOT,"exports"); SHOT=os.path.join(ROOT,"screenshots")
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
def seq(page):
    return page.evaluate("()=>document.querySelector('#lib-seq')?.innerText||''")
def rows(page):
    return page.evaluate("""()=>{const vis=el=>{const r=el.getBoundingClientRect();return r.width>1&&r.height>1};return [...document.querySelectorAll('#lib-seq .lib-seq__row')].filter(vis).map(e=>({tx:e.innerText.slice(0,300),rect:(r=>[r.x,r.y,r.width,r.height])(e.getBoundingClientRect())}));}""")
def lib(page,q):
    page.locator('#ws-tab-library').click(); page.wait_for_timeout(500)
    page.locator('#lib-tab-anims').click(); page.wait_for_timeout(500)
    page.locator('#lib-search').fill(q); page.wait_for_timeout(900)
def pick(page,cid,on=True):
    return page.evaluate("""({cid,on})=>{const t=document.querySelector('.lib-tile[data-id="'+cid+'"]');if(!t)return{ok:false};const p=t.querySelector('.lib-tile__pick');if(!p)return{ok:false};const cur=p.getAttribute('aria-checked')==='true';if(cur!==on)p.click();return{ok:true,was:cur,now:p.getAttribute('aria-checked')};}""",{"cid":cid,"on":on})
def mask_add(page):
    page.locator('.ws-icontab[data-tab="setup"]').first.click(); page.wait_for_timeout(500)
    m=page.locator('.ws-icontab[data-sub="compose"]').first
    if m.count() and m.is_visible(): m.click(); page.wait_for_timeout(700)
    add=page.get_by_role("button", name=re.compile(r"\+\s*ADD SELECTED",re.I))
    if add.count() and add.first.is_visible(): add.first.click(); page.wait_for_timeout(2500); return True
    return False
def set_weights(page, mode="auto"):
    return page.evaluate("""(mode)=>{
      const vis=el=>{const r=el.getBoundingClientRect();return r.width>1&&r.height>1};
      const rows=[...document.querySelectorAll('#lib-seq .lib-seq__row')].filter(vis);
      const base=rows.find(x=>/^Base/.test((x.innerText||'').trim()));
      const out=[];
      for(const row of rows){
        const inp=row.querySelector('input.lib-seq__hweight'); if(!inp) continue;
        const isBase=row===base; const isLayer=!isBase && /Idle Talking/.test(row.innerText||'');
        let val=null;
        if(mode==='zero_all') val=0;
        else if(isLayer && !/Full body/.test(row.innerText)) val=100;
        else if(isLayer && /Full body/.test(row.innerText)) val=0;
        if(val!==null){inp.value=String(val);inp.dispatchEvent(new Event('input',{bubbles:true}));inp.dispatchEvent(new Event('change',{bubbles:true}));}
        out.push({layer:isLayer,base:isBase,val:inp.value,head:(row.innerText||'').slice(0,90)});
      }
      return out;
    }""",mode)
def delete_layers(page):
    return page.evaluate("""()=>{
      const vis=el=>{const r=el.getBoundingClientRect();return r.width>1&&r.height>1};
      const rows=[...document.querySelectorAll('#lib-seq .lib-seq__row')].filter(vis);
      const base=rows.find(x=>/^Base/.test((x.innerText||'').trim()));
      const layers=rows.filter(x=>/Idle Talking/.test(x.innerText||'')&&(!base||x.getBoundingClientRect().y<base.getBoundingClientRect().y));
      const out=[];
      for(const layer of layers){
        const btns=[...layer.querySelectorAll('button')].map(b=>({t:(b.innerText||'').trim(),aria:b.getAttribute('aria-label'),title:b.title}));
        let b=[...layer.querySelectorAll('button')].find(x=>/remove|delete|clear|close/i.test((x.getAttribute('aria-label')||'')+(x.title||'')+(x.innerText||'')));
        if(!b) b=[...layer.querySelectorAll('*')].find(x=>(x.innerText||'').trim()==='✕'&&x.getBoundingClientRect().width>0);
        if(b){b.click(); out.push({ok:true,btns});} else out.push({ok:false,btns});
      }
      return out;
    }""")
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
    page.goto("https://actionforge.app/",wait_until="domcontentloaded",timeout=120000)
    for i in range(300):
        t=body(page)
        if "pelvis" in t and "Loading ActionForge" not in t: break
        time.sleep(1)
    log("ready",i); unfold(page); log("rows start",json.dumps(rows(page),ensure_ascii=False)); log("weights start",page.evaluate("()=>[...document.querySelectorAll('input.lib-seq__hweight')].map(e=>e.value)"))
    # delete existing idle layers (or zero them)
    log("delete layers",delete_layers(page)); page.wait_for_timeout(1500)
    for txt in ["DELETE","REMOVE","OK","YES"]:
        try:
            b=page.get_by_role("button", name=re.compile('^'+txt+'$',re.I))
            if b.count() and b.first.is_visible(): b.first.click(); log("confirm",txt); page.wait_for_timeout(800); break
        except: pass
    log("rows after delete",json.dumps(rows(page),ensure_ascii=False))
    # ensure base walk
    if "Walk Loop" not in seq(page):
        lib(page,"walk"); pick(page,"walk_loop",True); log("add walk",mask_add(page)); page.wait_for_timeout(1000)
    # zero any remaining old layers
    log("weights zero_all",set_weights(page,"zero_all")); page.wait_for_timeout(800)
    log("rows before new layer",json.dumps(rows(page),ensure_ascii=False))
    # new layer
    page.locator('#ws-tab-animate').click(); page.wait_for_timeout(600)
    page.locator('.ws-icontab[data-sub="adjust"]').click(); page.wait_for_timeout(800)
    b=page.get_by_role("button", name=re.compile(r"\+\s*LAYER",re.I))
    if b.count(): b.first.click(); page.wait_for_timeout(1500)
    log("rows after +layer",json.dumps(rows(page),ensure_ascii=False))
    # select new layer
    try:
        lab=page.get_by_text("Layer 1",exact=True).last
        if lab.count(): lab.click(timeout=15000); page.wait_for_timeout(900); log("clicked layer1")
    except Exception as e: log("label err",str(e)[:120])
    # add idle to layer
    lib(page,"talking"); pick(page,"idle_talking_loop",True); log("add idle",mask_add(page)); page.wait_for_timeout(1000)
    log("rows after idle",json.dumps(rows(page),ensure_ascii=False)); snap(page,"01_after_idle")
    # set weights: new layer 100, full-body old layer 0
    log("weights auto",set_weights(page,"auto")); page.wait_for_timeout(1200)
    log("weights after",page.evaluate("()=>[...document.querySelectorAll('input.lib-seq__hweight')].map(e=>({v:e.value,row:e.closest('.lib-seq__row')?.innerText.slice(0,80)}))"))
    log("rows final",json.dumps(rows(page),ensure_ascii=False))
    # mask panel
    page.locator('.ws-icontab[data-tab="setup"]').first.click(); page.wait_for_timeout(500)
    m=page.locator('.ws-icontab[data-sub="compose"]').first
    if m.count() and m.is_visible(): m.click(); page.wait_for_timeout(1000)
    snap(page,"02_mask"); dump(page,"02_mask")
    # export glb inplace + fbx
    open_download(page); log("inplace disabled",page.locator("#lib-inplace").is_disabled(),"checked",page.locator("#lib-inplace").is_checked())
    try: page.select_option("#lib-bundle-format","glb")
    except: pass
    if not page.locator("#lib-inplace").is_checked(): page.locator("#lib-inplace").check()
    page.wait_for_timeout(500); dl(page,"Rogue_Walk_IdleTalkLayer_AF_inplace.glb")
    open_download(page)
    try: page.select_option("#lib-bundle-format","fbx")
    except: pass
    if not page.locator("#lib-inplace").is_checked(): page.locator("#lib-inplace").check()
    page.wait_for_timeout(500); dl(page,"Rogue_Walk_IdleTalkLayer_AF.fbx")
    snap(page,"03_export_done")
    for n in os.listdir(OUT):
        if n.endswith(".png"): shutil.copy(os.path.join(OUT,n),os.path.join(SHOT,"t013_script_"+n))
    open(OUT+"/console.txt","w").write("\n".join(logs[-60:]))
    log("done"); ctx.close()
logf.close()
