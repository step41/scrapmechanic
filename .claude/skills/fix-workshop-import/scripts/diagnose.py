#!/usr/bin/env python3
"""Full diagnostic battery for a Scrap Mechanic .blueprint file, developed
from repeatedly debugging broken Steam Workshop-derived imports.

Checks, in order:
  1. version / top-level keys / body & joint counts / missing-"type" count
  2. CRLF vs lone-LF line-ending audit
  3. shapeId resolution against the full current shapeset database
  4. restrictions check on every resolved shapeId
  5. structural key-pattern diff of bodies/joints against a reference file
  6. color hex validity
  7. position range sanity

Usage:
    python3 diagnose.py <target.blueprint> <reference.blueprint> [repo_root]

repo_root defaults to the directory three levels above this script
(<repo>/.claude/skills/fix-workshop-import/scripts -> <repo>), which is
correct when the script is run from its normal bundled location.
"""

import glob
import json
import os
import sys


def load_raw(path):
    with open(path, 'rb') as f:
        raw = f.read()
    crlf = raw.count(b'\r\n')
    lf_only = raw.count(b'\n') - crlf
    return raw, crlf, lf_only


def collect_shape_ids(obj, out):
    if isinstance(obj, dict):
        if 'shapeId' in obj:
            out.add(obj['shapeId'])
        for v in obj.values():
            collect_shape_ids(v, out)
    elif isinstance(obj, list):
        for v in obj:
            collect_shape_ids(v, out)


def build_shape_database(repo_root):
    """Scan every .shapeset / custom.json under repo_root for uuid ->
    restrictions, tolerating the different list-key names shapesets use
    (partList, shapeList, wedgeList, ...)."""
    uuid_restrictions = {}
    uuid_found = set()
    files = glob.glob(os.path.join(repo_root, '**', '*.shapeset'), recursive=True)
    files += glob.glob(os.path.join(repo_root, '**', 'custom.json'), recursive=True)
    for sf in files:
        try:
            with open(sf, encoding='utf-8') as f:
                sdata = json.load(f)
        except Exception:
            continue
        if not isinstance(sdata, dict):
            continue
        parts = None
        for key in ('partList', 'blockList', 'wedgeList'):
            if key in sdata and isinstance(sdata[key], list):
                parts = sdata[key]
                break
        if parts is None:
            continue
        for p in parts:
            if isinstance(p, dict) and 'uuid' in p:
                uid = p['uuid'].lower()
                uuid_found.add(uid)
                if 'restrictions' in p:
                    uuid_restrictions[uid] = p['restrictions']
    return uuid_found, uuid_restrictions


def keyset(obj, prefix=''):
    keys = set()
    if isinstance(obj, dict):
        for k, v in obj.items():
            keys.add(prefix + k)
            keys |= keyset(v, prefix + k + '.')
    elif isinstance(obj, list):
        for item in obj[:3]:
            keys |= keyset(item, prefix)
    return keys


def collect_colors(obj, colors):
    if isinstance(obj, dict):
        if 'color' in obj and isinstance(obj['color'], str):
            colors.add(obj['color'])
        for v in obj.values():
            collect_colors(v, colors)
    elif isinstance(obj, list):
        for v in obj:
            collect_colors(v, colors)


def collect_positions(obj, positions):
    if isinstance(obj, dict):
        if 'pos' in obj and isinstance(obj['pos'], dict):
            positions.append(obj['pos'])
        for v in obj.values():
            collect_positions(v, positions)
    elif isinstance(obj, list):
        for v in obj:
            collect_positions(v, positions)


def report_file(label, path):
    raw, crlf, lf_only = load_raw(path)
    data = json.loads(raw.decode('utf-8'))
    bodies = data.get('bodies', [])
    joints = data.get('joints', [])
    type_dist = {}
    for b in bodies:
        t = b.get('type', 'MISSING')
        type_dist[t] = type_dist.get(t, 0) + 1
    print(f'--- {label} ({path}) ---')
    print('version:', data.get('version'))
    print('top-level keys:', list(data.keys()))
    print('bodies:', len(bodies), 'joints:', len(joints))
    print('body type distribution:', type_dist)
    print('CRLF:', crlf, 'lone LF:', lf_only)
    print()
    return data


def main():
    if len(sys.argv) < 3:
        raise SystemExit(f'Usage: {sys.argv[0]} <target.blueprint> <reference.blueprint> [repo_root]')

    target_path, ref_path = sys.argv[1], sys.argv[2]
    if len(sys.argv) >= 4:
        repo_root = sys.argv[3]
    else:
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))

    print('### 1. Version / keys / body-type counts ###\n')
    target = report_file('TARGET', target_path)
    ref = report_file('REFERENCE', ref_path)

    print('### 2. shapeId resolution + restrictions ###\n')
    shape_ids = set()
    collect_shape_ids(target.get('bodies', []), shape_ids)
    print('Unique shapeIds referenced by target:', len(shape_ids))

    uuid_found, uuid_restrictions = build_shape_database(repo_root)
    missing = sorted(sid for sid in shape_ids if sid.lower() not in uuid_found)
    print('Missing shapeIds (not found in any shapeset):', missing or 'none')

    restricted = []
    for sid in shape_ids:
        r = uuid_restrictions.get(sid.lower())
        if r and not all(r.values()):
            restricted.append((sid, {k: v for k, v in r.items() if not v}))
    print('ShapeIds with a restriction=false somewhere:', restricted or 'none')
    print()

    print('### 3. Structural key-pattern diff vs reference ###\n')
    tk = keyset(target.get('bodies', []))
    rk = keyset(ref.get('bodies', []))
    print('Keys in target bodies not in reference:', tk - rk or 'none')
    print('Keys in reference bodies not in target:', rk - tk or 'none')
    print('(Content-driven diffs like controller/container/light fields are')
    print(' expected variance between different creations — only worry about')
    print(' structural keys like "type" being absent.)')
    print()

    tjk = keyset(target.get('joints', []))
    rjk = keyset(ref.get('joints', []))
    print('Joint keys in target not in reference:', tjk - rjk or 'none')
    print('Joint keys in reference not in target:', rjk - tjk or 'none')
    print()

    print('### 4. Color validity ###\n')
    colors = set()
    collect_colors(target.get('bodies', []), colors)
    bad_colors = [c for c in colors if not (len(c) == 6 and all(ch in '0123456789abcdefABCDEF' for ch in c))]
    print('Total unique colors:', len(colors))
    print('Malformed colors:', bad_colors or 'none')
    print()

    print('### 5. Position range sanity ###\n')
    positions = []
    collect_positions(target.get('bodies', []), positions)
    if positions:
        xs = [p.get('x', 0) for p in positions]
        ys = [p.get('y', 0) for p in positions]
        zs = [p.get('z', 0) for p in positions]
        print('pos x range:', min(xs), max(xs))
        print('pos y range:', min(ys), max(ys))
        print('pos z range:', min(zs), max(zs))
    else:
        print('No "pos" dict keys found directly under bodies.')


if __name__ == '__main__':
    main()
