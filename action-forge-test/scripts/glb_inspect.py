#!/usr/bin/env python3
"""Minimal GLB inspector: skeleton, meshes, animations, root motion, duration.
No third-party deps. Usage: python3 glb_inspect.py file.glb [...]"""
import json, struct, sys, os

def load_glb(path):
    with open(path,'rb') as f:
        data=f.read()
    magic, ver, length = struct.unpack_from('<III', data, 0)
    assert magic == 0x46546C67, 'not a GLB'
    off=12; doc=None; binchunk=None
    while off < length:
        clen, ctype = struct.unpack_from('<II', data, off); off+=8
        chunk=data[off:off+clen]; off+=clen
        if ctype == 0x4E4F534A: doc=json.loads(chunk.decode('utf-8'))
        elif ctype == 0x004E4942: binchunk=chunk
    return doc, binchunk, len(data)

def acc_minmax(doc, idx):
    a=doc['accessors'][idx]
    return a.get('min'), a.get('max'), a.get('count'), a.get('type'), a.get('componentType')

def inspect(path):
    doc, binc, size = load_glb(path)
    print(f"== {os.path.basename(path)} ({size} bytes) ==")
    print("generator:", doc.get('asset',{}).get('generator'))
    print("nodes:", len(doc.get('nodes',[])), "meshes:", len(doc.get('meshes',[])), "skins:", len(doc.get('skins',[])), "materials:", len(doc.get('materials',[])))
    if doc.get('skins'):
        for si,s in enumerate(doc['skins']):
            joints=s.get('joints',[])
            names=[doc['nodes'][j].get('name','?') for j in joints]
            print(f"skin[{si}] joints={len(joints)} skeleton={doc['nodes'][s['skeleton']].get('name') if 'skeleton' in s else None}")
            print("  joints:", ','.join(names[:50]))
            if len(names)>50: print("  ...")
    verts=0; prims=0
    for m in doc.get('meshes',[]):
        for p in m.get('primitives',[]):
            prims+=1
            pos=p.get('attributes',{}).get('POSITION')
            if pos is not None: verts+=doc['accessors'][pos]['count']
    print("primitives:", prims, "vertices(sum primitives):", verts)
    for m in doc.get('meshes',[]):
        print("  mesh:", m.get('name'), "prims:", len(m.get('primitives',[])))
    node_names={i:n.get('name','?') for i,n in enumerate(doc.get('nodes',[]))}
    for ai,anim in enumerate(doc.get('animations',[])):
        times=[]; chans=[]
        tmin=1e9; tmax=-1
        for ch in anim.get('channels',[]):
            s=anim['samplers'][ch['sampler']]
            mn,mx,cnt,typ,ct=acc_minmax(doc,s['input'])
            if mn: tmin=min(tmin,mn[0])
            if mx: tmax=max(tmax,mx[0])
            node=node_names.get(ch['target'].get('node'),'?')
            chans.append((node,ch['target'].get('path')))
        print(f"anim[{ai}] name={anim.get('name')!r} channels={len(chans)} time=[{tmin:.4f},{tmax:.4f}]s duration={tmax-tmin:.4f}s")
        # show translation channels for interesting nodes
        for ch in anim.get('channels',[]):
            path_=ch['target'].get('path')
            node=node_names.get(ch['target'].get('node'),'?')
            if path_=='translation' and any(k in node.lower() for k in ['root','hips','pelvis']):
                s=anim['samplers'][ch['sampler']]
                mn,mx,cnt,typ,ct=acc_minmax(doc,s['output'])
                if mn is None:
                    # accessor min/max may be missing; read from bin
                    a=doc['accessors'][s['output']]; bv=doc['bufferViews'][a['bufferView']]
                    start=bv.get('byteOffset',0)+a.get('byteOffset',0)
                    n=a['count']; comps={'VEC3':3,'VEC4':4}.get(a['type'],3)
                    vals=struct.unpack_from('<'+'f'*n*comps, binc, start)
                    xs=vals[0::comps]; ys=vals[1::comps]; zs=vals[2::comps]
                    mn=[min(xs),min(ys),min(zs)]; mx=[max(xs),max(ys),max(zs)]
                print(f"   translation {node}: min={['%.4f'%v for v in mn]} max={['%.4f'%v for v in mx]} range={['%.4f'%(mx[i]-mn[i]) for i in range(len(mn))]}")
    print()

if __name__=='__main__':
    for p in sys.argv[1:]:
        inspect(p)
