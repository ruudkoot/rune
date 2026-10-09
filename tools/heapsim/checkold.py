#!/usr/bin/env python3
"""checkold.py TRACE_DIR -- stores.bin's old_id against the history of each
field (a trace with graph.bin): the value a store overwrites is the last
store's new value into that field, or the field's value at allocation
(graph.bin). Prints the agreement; a disagreement is a field written by
neither (a late fill, docs/census.md's limit) or a bug. Memory ~16 B/object."""
import os, sys
import numpy as np
d = sys.argv[1]
ADT = np.dtype([("kind", "u1"), ("sk", "u1"), ("contag", "<u2"), ("len", "<u4"), ("site", "<u4"), ("func", "<u4")])
STDT = np.dtype([("clock8", "<u4"), ("src", "<u4"), ("new", "<u4"), ("old", "<u4"), ("field", "<u4"),
                 ("site", "u1"), ("flags", "u1"), ("rep", "u1"), ("kind", "u1")])
a = np.memmap(os.path.join(d, "alloc.bin"), dtype=ADT, mode="r")
kind = np.array(a["kind"]); ln = np.array(a["len"]).astype(np.int64)
hasf = ~np.isin(kind, [0, 4, 10, 11, 12, 13])
flen = np.where(hasf, ln, 0)
off = np.concatenate(([0], np.cumsum(flen)))[:-1]       # field offset of each id
g = np.memmap(os.path.join(d, "graph.bin"), dtype="<u4", mode="r")
st = np.array(np.memmap(os.path.join(d, "stores.bin"), dtype=STDT, mode="r"))
n = len(st)
if n == 0:
    print("%s: no stores" % d); sys.exit(0)
slot = off[st["src"].astype(np.int64)] + st["field"].astype(np.int64)
order = np.lexsort((np.arange(n), slot))                  # by slot, then time
s_slot = slot[order]
first = np.ones(n, dtype=bool); first[1:] = s_slot[1:] != s_slot[:-1]
expect = np.empty(n, dtype=np.int64)
prev_new = np.empty(n, dtype=np.int64); prev_new[1:] = st["new"][order][:-1]
expect[~first] = prev_new[~first]
expect[first] = np.array(g[s_slot[first]]).astype(np.int64)
got = st["old"][order].astype(np.int64)
bad = got != expect
bad_first = bad & first
print("%s: %d stores, old_id agrees on %d (%.4f%%); disagreements %d (%d at a field's first store, i.e. against graph.bin)"
      % (d, n, n - bad.sum(), 100.0 * (n - bad.sum()) / n, bad.sum(), bad_first.sum()))
if bad.sum():
    i = np.nonzero(bad)[0][:5]
    for j in i:
        r = st[order[j]]
        print("  store src %d (%s) field %d site %d: old %d, expected %d (%s)" % (r["src"], kind[r["src"]], r["field"], r["site"], r["old"], expect[j], "graph" if first[j] else "previous store"))
