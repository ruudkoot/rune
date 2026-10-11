#!/usr/bin/env python3
"""The compiler as a service (src/driver/serve.sml; the incremental roadmap's
M12, a prototype): rune --serve driven over its stdio, one JSON-RPC 2.0
message per line -- initialize, the diagnostics of a buffer with errors, of
one without and of one of non-ASCII text, hover on a function and on a
variable of a file that another file of the program declares, an unknown
method, shutdown -- and what one request takes, warm.

    tests/serve/run.py [--rune BIN]
"""
import json, os, subprocess, sys, time

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
rune = os.path.join(root, 'bin', 'rune')
if len(sys.argv) > 2 and sys.argv[1] == '--rune':
    rune = os.path.abspath(sys.argv[2])
out = os.path.join(root, 'tests', 'out', 'serve')
subprocess.run(['rm', '-rf', out])
os.makedirs(out)
os.chdir(out)
with open('lib.sml', 'w') as f:
    f.write('structure Lib = struct fun double x = x * 2 end\n')
good = 'val y = Lib.double 21\nfun twice f x = f (f x)\n'
bad = 'val y = Lib.double "21"\nval z = undefinedName\n'
with open('a.sml', 'w') as f:
    f.write(good)

p = subprocess.Popen([rune, '--serve', '--cache-dir', 'cache'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=open('serve.err', 'w'), text=True)
passed = failed = 0


def req(i, method, params):
    t = time.time()
    p.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': i, 'method': method, 'params': params}) + '\n')
    p.stdin.flush()
    return json.loads(p.stdout.readline()), time.time() - t


def want(what, got, ok):
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print('FAIL serve.%s: %s' % (what, json.dumps(got)))


files = ['lib.sml', 'a.sml']
r, _ = req(1, 'initialize', {})
want('initialize', r, r.get('result', {}).get('name') == 'rune' and 'hover' in r['result']['methods'])
r, _ = req(2, 'diagnostics', {'files': files, 'path': 'a.sml', 'text': bad})
ds = r.get('result', {}).get('diagnostics', [])
want('diagnostics-errors', r, [(d['severity'], d['line'], d['start'], d['stop']) for d in ds]
     == [('error', 1, bad.index('"21"'), bad.index('"21"') + 4), ('error', 2, bad.index('undefinedName'),
                                                                   bad.index('undefinedName') + len('undefinedName'))])
r, _ = req(3, 'diagnostics', {'files': files, 'path': 'a.sml', 'text': good})
want('diagnostics-none', r, r.get('result') == {'diagnostics': []})
r, _ = req(4, 'hover', {'files': files, 'path': 'a.sml', 'text': good, 'offset': good.index('double')})
want('hover-function', r, r.get('result', {}).get('type') == 'int -> int' and r['result']['name'] == 'Lib.double')
r, _ = req(5, 'hover', {'files': files, 'path': 'a.sml', 'text': good, 'offset': good.index('f x)')})
want('hover-variable', r, r.get('result', {}).get('name') == 'f' and r['result']['type'].endswith("-> 'a"))
r, _ = req(6, 'hover', {'files': files, 'path': 'a.sml', 'text': good, 'offset': 0})
want('hover-nothing', r, r.get('result', 'x') is None)
# a buffer with a string of non-ASCII text: it crosses as \u escapes, a
# character beyond 16 bits as two, and offsets are its bytes in UTF-8
accented = 'val s = "caf\u00e9 \u2192 \U0001f600"\nval z = alsoUndefined\n'
r, _ = req(9, 'diagnostics', {'files': files, 'path': 'a.sml', 'text': accented})
ds = r.get('result', {}).get('diagnostics', [])
at = accented.encode('utf-8').index(b'alsoUndefined')
want('diagnostics-utf8', r, [(d['line'], d['start']) for d in ds] == [(2, at)])
times = sorted(req(10 + k, 'diagnostics', {'files': files, 'path': 'a.sml', 'text': good})[1] for k in range(9))
r, _ = req(7, 'nosuch', {})
want('unknown-method', r, r.get('error', {}).get('code') == -32601)
r, _ = req(8, 'shutdown', {})
want('shutdown', r, 'result' in r and p.wait(timeout=30) == 0)
print('serve: passed %d, failed %d; a request warm %.0f ms (median of 9)' % (passed, failed, 1000 * times[4]))
sys.exit(1 if failed else 0)
