#!/usr/bin/env python3
"""Insert a missing "type":0 field into every object in a .blueprint file's
top-level "bodies" array, via bracket-depth text surgery (not a JSON
parse+reserialize) so all original formatting/whitespace/line-endings are
preserved exactly.

Usage:
    python3 fix_missing_type.py <path-to-blueprint-file>
"""

import json
import sys


def fix_missing_type(path):
    with open(path, encoding='utf-8', newline='') as f:
        raw = f.read()

    marker = '"bodies":['
    start = raw.find(marker)
    if start == -1:
        raise SystemExit('No "bodies":[ array found in file')

    i = start + len(marker) - 1
    depth = 0
    end = None
    while True:
        if raw[i] == '[':
            depth += 1
        elif raw[i] == ']':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1

    bodies_span = raw[start + len(marker) - 1:end]
    result = []
    i = 0
    n = len(bodies_span)
    patched = 0
    skipped = 0
    while i < n:
        if bodies_span[i] == '{':
            depth = 0
            j = i
            while True:
                if bodies_span[j] == '{':
                    depth += 1
                elif bodies_span[j] == '}':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            body_obj = bodies_span[i:j + 1]
            parsed = json.loads(body_obj)  # validates + checks top-level keys only, not re-emitted
            if 'type' in parsed:
                result.append(body_obj)
                skipped += 1
            else:
                assert body_obj.endswith('}'), body_obj[-50:]
                new_body_obj = body_obj[:-1] + ',"type":0}'
                result.append(new_body_obj)
                patched += 1
            i = j + 1
        else:
            result.append(bodies_span[i])
            i += 1

    new_bodies_span = ''.join(result)
    new_raw = raw[:start + len(marker) - 1] + new_bodies_span + raw[end:]

    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(new_raw)

    print(f'Bodies patched: {patched}')
    print(f'Bodies already had "type" (skipped): {skipped}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(f'Usage: {sys.argv[0]} <path-to-blueprint-file>')
    fix_missing_type(sys.argv[1])
