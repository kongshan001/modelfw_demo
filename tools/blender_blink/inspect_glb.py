"""Inspect a GLB's JSON chunk: meshes, morph targets, skins, animations.

  python3 tools/blender_blink/inspect_glb.py agent-probes/blink-test/qinghe_blink.glb
"""
import json
import struct
import sys


def read_glb(path):
    with open(path, 'rb') as f:
        magic, version, length = struct.unpack('<III', f.read(12))
        assert magic == 0x46546C67, 'not a GLB'
        chunks = {}
        while f.tell() < length:
            clen, ctype = struct.unpack('<II', f.read(8))
            data = f.read(clen)
            chunks[ctype] = data
        return json.loads(chunks[0x4E4F534A].decode('utf-8')), chunks


def summarize(path):
    gltf, chunks = read_glb(path)
    out = {'file': path, 'asset': gltf.get('asset', {}),
           'scenes': len(gltf.get('scenes', [])),
           'nodes': len(gltf.get('nodes', [])),
           'skins': [{'name': s.get('name'), 'joints': len(s.get('joints', [])),
                      'skeleton': s.get('skeleton')} for s in gltf.get('skins', [])],
           'meshes': [], 'animations': []}
    for m in gltf.get('meshes', []):
        prims = []
        for p in m.get('primitives', []):
            prims.append({
                'material': gltf['materials'][p['material']].get('name')
                if 'material' in p else None,
                'targets': len(p.get('targets', [])),
                'target_names': [t.get('name') for t in p.get('targets', [])],
                'has_skinning': 'JOINTS_0' in p.get('attributes', {}),
                'mode': p.get('mode', 4),
            })
        out['meshes'].append({'name': m.get('name'), 'primitives': prims,
                              'weights': m.get('weights')})
    for a in gltf.get('animations', []):
        targets = {}
        for ch in a.get('channels', []):
            t = ch['target']
            targets.setdefault(t.get('path'), 0)
            targets[t.get('path')] += 1
        samplers = a.get('samplers', [])
        times = []
        for s in samplers:
            acc = gltf['accessors'][s['input']]
            if 'min' in acc and 'max' in acc:
                times.append((acc['min'][0], acc['max'][0], acc['count']))
        out['animations'].append({
            'name': a.get('name'), 'channels': len(a.get('channels', [])),
            'paths': targets, 'samplers': len(samplers),
            'time_range': [min(t[0] for t in times), max(t[1] for t in times)] if times else None,
            'max_samples': max(t[2] for t in times) if times else None,
            'morph_target_node_names': [
                gltf['nodes'][ch['target']['node']].get('name')
                for ch in a.get('channels', []) if ch['target'].get('path') == 'weights'],
        })
    out['extensions_used'] = gltf.get('extensionsUsed', [])
    out['materials'] = [m.get('name') for m in gltf.get('materials', [])]
    return out


if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else 'agent-probes/blink-test/qinghe_blink.glb'
    print(json.dumps(summarize(path), indent=2))
