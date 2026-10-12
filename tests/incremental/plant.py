#!/usr/bin/env python3
"""A stale entry planted in the cache, for S55 (tests/incremental/run.sh).

    plant.py OLD NEW
    plant.py --basis-version N UNIT ENTRY...

rewrites the entry NEW (UnitCache, src/driver/unitcache.sml) so that it keeps
NEW's usages and holds OLD's warnings, source name, basis and code, with the
hash of what it holds made again: an entry whose usages hold and whose
content is that of another compile, which a build takes as it is and
--verify-cache finds. With --basis-version, the ENTRY whose basis is UNIT's says
version N instead (S67): an entry of a cache made before the basis's form changed."""
import sys


def content_hash(s):
    # Pickle.hash (src/util/pickle.sml): four hashes of 24 bits each
    a, b, c, d = 7, 11, 13, 17
    for x in s:
        a = (a * 31 + x) % 16777213
        b = (b * 37 + x) % 16777199
        c = (c * 41 + x) % 16777183
        d = (d * 43 + x) % 16777153
    return ''.join('%06x' % v for v in (a, b, c, d)).encode()


def rnat(s, i):
    n, scale = 0, 1
    while True:
        b = s[i]
        i += 1
        if b < 128:
            return n + b * scale, i
        n += (b - 128) * scale
        scale *= 128


def nat(n):
    out = b''
    while n >= 128:
        out += bytes([128 + n % 128])
        n //= 128
    return out + bytes([n])


def rstring(s, i):
    n, i = rnat(s, i)
    return s[i:i + n], i + n


def parse(path):
    """An entry's version, its usages' bytes and the bytes after them"""
    s = open(path, 'rb').read()
    if s[:3] != b'RCE':
        sys.exit('plant.py: not an entry: ' + path)
    version, i = rnat(s, 3)
    _, i = rstring(s, i)
    body = s[i:]
    n, j = rnat(body, 0)
    for _ in range(2 * n):
        _, j = rstring(body, j)
    return version, body[:j], body[j:]


def basis_version(path, unit, n):
    """The entry at path, where its basis is the unit's, with the version the
    basis says made n (S67): the basis's header is "RBI", its version
    (UnitBasis.version) and the unit's name; whether it was changed"""
    version, usages, rest = parse(path)
    i = rest.find(b'RBI')
    if i < 0:
        return False
    _, j = rnat(rest, i + 3)
    name, _ = rstring(rest, j)
    if name != unit.encode():
        return False
    body = usages + rest[:i + 3] + nat(n) + rest[j:]
    h = content_hash(body)
    with open(path, 'wb') as out:
        out.write(b'RCE' + nat(version) + nat(len(h)) + h + body)
    return True


if __name__ == '__main__' and sys.argv[1] == '--basis-version':
    if not [p for p in sys.argv[4:] if basis_version(p, sys.argv[3], int(sys.argv[2]))]:
        sys.exit('plant.py: no entry of ' + sys.argv[3])
elif __name__ == '__main__':
    version, _, rest = parse(sys.argv[1])
    _, usages, _ = parse(sys.argv[2])
    body = usages + rest
    h = content_hash(body)
    with open(sys.argv[2], 'wb') as out:
        out.write(b'RCE' + nat(version) + nat(len(h)) + h + body)
