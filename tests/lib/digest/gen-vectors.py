#!/usr/bin/env python3
"""Random messages and keys, and what Python's hashlib and hmac make of
them, as tests/lib/digest/python.txt, a line a case: the message, the
key, the SHA-256 and the HMAC-SHA-256, in hexadecimal, separated by
blanks. The messages are of every length
around the block's edges (55, 56, 63, 64, 119, 120 bytes...), so that
the padding of each case is checked against another implementation.

  python3 tests/lib/digest/gen-vectors.py > tests/lib/digest/python.txt
"""
import hashlib
import hmac
import random

rng = random.Random(2026)
lengths = list(range(0, 130)) + [255, 256, 1000, 4096]
for n in lengths:
    msg = bytes(rng.randrange(256) for _ in range(n))
    key = bytes(rng.randrange(256) for _ in range(rng.choice([0, 1, 20, 32, 63, 64, 65, 131])))
    print(msg.hex() or "-", key.hex() or "-", hashlib.sha256(msg).hexdigest(),
          hmac.new(key, msg, "sha256").hexdigest())
