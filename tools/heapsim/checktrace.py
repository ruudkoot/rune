#!/usr/bin/env python3
"""checktrace.py TRACE_DIR -- the internal consistency of a census trace of
format 2 (the word layout; docs/census.md). Exits 1 on a failure.

Checks: the file sizes against meta.txt; the sizes and the clock (the
sum of w8_obj_size equals meta's bytes; boxes excluded, count_bytes);
for every sample, the objects alive by death.bin among ids 1..last_id sum
to its live_bytes and live_objs; the sample clocks are the prefix sums at
last_id; the frames (fp_low <= fp, base_low <= sp); graph.bin against
fields.bin (a pointer field and only one has an id, older than its
object, of the kind fields.bin says); every store's ids exist by its
clock. The files are memory-mapped and walked in chunks of objects:
memory about 4 bytes per object (the clock in 8-byte units) plus a chunk."""
import os
import sys
import numpy as np

CHUNK = 1 << 22

ADT = np.dtype([("kind", "u1"), ("sk", "u1"), ("contag", "<u2"), ("len", "<u4"), ("site", "<u4"), ("func", "<u4")])
SDT = np.dtype([("clock", "<u8"), ("live_bytes", "<u8"), ("live_objs", "<u8"), ("instr", "<u8"), ("last_id", "<u8"),
                ("sp", "<u4"), ("fp", "<u4"), ("fp_low", "<u4"), ("base_low", "<u4"), ("sp_ptrs", "<u4"), ("flags", "<u4")])
STDT = np.dtype([("clock8", "<u4"), ("src", "<u4"), ("new", "<u4"), ("old", "<u4"), ("field", "<u4"),
                 ("site", "u1"), ("flags", "u1"), ("rep", "u1"), ("kind", "u1")])


def mmap(path, dtype):
    if os.path.getsize(path) == 0:
        return np.zeros(0, dtype=dtype)
    return np.memmap(path, dtype=dtype, mode="r")


def sizes_of(kind, ln):
    kind = kind.astype(np.int64)
    ln = ln.astype(np.int64)
    pay = np.where((kind == 4) | (kind == 12), ln, np.where((kind == 10) | (kind == 11), 8, ln * 8))
    pay = np.maximum((pay + 7) & ~7, 8)
    return 8 + pay


def main(d):
    ok = True

    def fail(msg):
        nonlocal ok
        ok = False
        print("FAIL " + msg)
    meta = {}
    for line in open(os.path.join(d, "meta.txt")):
        k, v = line.split()
        meta[k] = int(v) if v.lstrip("-").isdigit() else v
    if meta.get("format") != 2 or meta.get("layout") != "W8":
        fail("meta: format %s layout %s" % (meta.get("format"), meta.get("layout")))
    n = meta["objects"]
    if meta.get("summary"):
        print("summary trace: nothing to check but meta.txt")
        return 0
    a = mmap(os.path.join(d, "alloc.bin"), ADT)
    if len(a) != n + 1:
        fail("alloc.bin: %d records for %d objects + 1" % (len(a), n))
        return 1
    death = mmap(os.path.join(d, "death.bin"), "<u4")
    if len(death) != n + 1:
        fail("death.bin: %d entries" % len(death))
        return 1
    smp = np.array(mmap(os.path.join(d, "samples.bin"), SDT))
    ns = len(smp)
    if ns != meta["samples"]:
        fail("samples.bin: %d records, meta %d" % (ns, meta["samples"]))
    lid = smp["last_id"].astype(np.int64)
    if ns:
        if (np.diff(lid) < 0).any() or (np.diff(smp["clock"].astype(np.int64)) < 0).any() or (np.diff(smp["instr"].astype(np.int64)) < 0).any():
            fail("samples: last_id, clock or instructions decrease")
        if (smp["fp_low"] > smp["fp"]).any() or (smp["base_low"] > smp["sp"]).any() or (smp["sp_ptrs"] > smp["sp"]).any():
            fail("samples: fp_low > fp or base_low > sp or sp_ptrs > sp")
        if not (smp["flags"][-1] & 2) or (smp["flags"][:-1] & 2).any():
            fail("samples: the final flag is not on the last sample alone")
    fb = gb = None
    if meta["fields"]:
        fb = mmap(os.path.join(d, "fields.bin"), np.uint8)
        if len(fb) % 2:
            fail("fields.bin: odd size")
            fb = None
        else:
            fb = fb.reshape(-1, 2)
    if meta.get("graph"):
        gb = mmap(os.path.join(d, "graph.bin"), "<u4")
    pre = meta.get("pretrace_objects", 0)
    clock8 = np.zeros(n + 1, dtype=np.uint32)      # clock8[i] = bytes before id i, / 8
    cb = np.zeros(ns + 2, dtype=np.int64)
    co = np.zeros(ns + 2, dtype=np.int64)
    total = 0
    boxbytes = 0
    boxobjs = 0
    foff = 0
    any_alive_exit = False
    for lo in range(1, n + 1, CHUNK):
        hi = min(n + 1, lo + CHUNK)
        c = np.array(a[lo:hi])
        kind = c["kind"]
        ln = c["len"].astype(np.int64)
        if ((kind < 1) | (kind > 13) | (kind == 9)).any():
            fail("alloc.bin: a kind out of range in ids %d..%d" % (lo, hi - 1))
        sk = c["sk"]
        ids = np.arange(lo, hi, dtype=np.int64)
        if ((sk == 3) != (ids <= pre)).any():
            fail("alloc.bin: site kind 3 is not exactly the %d pretrace objects" % pre)
        size = sizes_of(kind, ln)
        csum = np.cumsum(size)
        start = total + csum - size                # the clock before each object
        if total + int(csum[-1]) >= (1 << 35):
            fail("the clock passes 32 GiB")
        clock8[lo:hi] = (start >> 3).astype(np.uint32)
        box = (kind == 10) | (kind == 11)
        boxbytes += int(size[box].sum())
        boxobjs += int(box.sum())
        total += int(csum[-1])
        # liveness: object i counts at samples [kb_i, dd_i]
        dd = np.array(death[lo:hi]).astype(np.int64)
        if (dd == 0xFFFFFFFF).any():
            any_alive_exit = True
        dd[dd == 0xFFFFFFFF] = ns
        if (dd > ns).any():
            fail("death.bin: a sample past the last")
        kb = np.searchsorted(lid, ids, side="left") + 1
        alive = dd >= kb
        if (dd[~alive] > 0).any():
            fail("death.bin: an object alive at a sample before its birth")
        np.add.at(cb, kb[alive], size[alive])
        np.add.at(cb, dd[alive] + 1, -size[alive])
        np.add.at(co, kb[alive], 1)
        np.add.at(co, dd[alive] + 1, -1)
        # fields and graph
        hasf = ~((kind == 4) | (kind == 10) | (kind == 11) | (kind == 12) | (kind == 13))
        nf = int(ln[hasf].sum())
        if fb is not None:
            if foff + nf > len(fb):
                fail("fields.bin too short")
                fb = gb = None
            else:
                f = np.array(fb[foff:foff + nf])
                what = f[:, 0] & 3
                if (what == 3).any() or (f[:, 0] & 0xC0).any() or (f[:, 1] & 0x80).any():
                    fail("fields.bin: a spare bit set or a word class 3")
                if gb is not None:
                    if foff + nf > len(gb):
                        fail("graph.bin too short")
                        gb = None
                    else:
                        g = np.array(gb[foff:foff + nf]).astype(np.int64)
                        if ((what == 1) != (g != 0)).any():
                            fail("graph.bin: a pointer field without an id or an id without one (ids %d..%d)" % (lo, hi - 1))
                        owner = np.repeat(ids[hasf], ln[hasf])
                        gp = g != 0
                        if (g[gp] >= owner[gp]).any():
                            fail("graph.bin: a field points to an object not older than its own")
                        pk = (f[:, 0] >> 2) & 15
                        if (pk[gp] != np.array(a["kind"][g[gp]])).any():
                            fail("graph.bin: the pointee's kind differs from fields.bin's")
        foff += nf
    if total != meta["bytes"]:
        fail("bytes: sum of sizes %d, meta %d" % (total, meta["bytes"]))
    if total - boxbytes != meta["count_bytes"] or n - boxobjs != meta["count_objects"]:
        fail("count: %d bytes %d objects without boxes, meta %d %d" % (total - boxbytes, n - boxobjs, meta["count_bytes"], meta["count_objects"]))
    if fb is not None and foff != len(fb):
        fail("fields.bin: %d fields, %d expected" % (len(fb), foff))
    if gb is not None and foff != len(gb):
        fail("graph.bin: %d entries, %d expected" % (len(gb), foff))
    if n and not any_alive_exit:
        fail("death.bin: nothing alive at exit")
    if ns:
        # the clock of sample k is the clock after last_id
        clk = smp["clock"].astype(np.int64)
        after = np.where(lid < n, clock8[np.minimum(lid + 1, n)].astype(np.int64) * 8, total)
        if (clk != after).any():
            k = int(np.nonzero(clk != after)[0][0])
            fail("samples: clock of sample %d is %d, the prefix sum at last_id %d is %d" % (k + 1, clk[k], lid[k], after[k]))
        lb = np.cumsum(cb)[1:ns + 1]
        lo_ = np.cumsum(co)[1:ns + 1]
        bad = np.nonzero((lb != smp["live_bytes"].astype(np.int64)) | (lo_ != smp["live_objs"].astype(np.int64)))[0]
        if len(bad):
            k = bad[0]
            fail("samples: %d of %d disagree with death.bin; first, sample %d: death.bin %d bytes %d objects, samples.bin %d %d"
                 % (len(bad), ns, k + 1, lb[k], lo_[k], smp["live_bytes"][k], smp["live_objs"][k]))
    st = mmap(os.path.join(d, "stores.bin"), STDT)
    nst = len(st)
    if nst != meta["stores"]:
        fail("stores.bin: %d records, meta %d" % (nst, meta["stores"]))
    prev = 0
    for lo in range(0, nst, CHUNK):
        s = np.array(st[lo:lo + CHUNK])
        c8 = s["clock8"].astype(np.int64)
        if c8[0] < prev or (np.diff(c8) < 0).any():
            fail("stores: the clock decreases")
        prev = int(c8[-1])
        # the ids allocated before the store: those whose clock8 is < c8, i.e. 1..last
        last = np.searchsorted(clock8, c8, side="left") - 1
        okb = (last >= n) | (clock8[np.minimum(last + 1, n)] == c8) | (c8 * 8 == total)
        if not okb.all():
            fail("stores: a clock that is no object's boundary")
        for fld in ("src", "new", "old"):
            if (s[fld].astype(np.int64) > last).any():
                fail("stores: a %s id not yet allocated at the store" % fld)
        src = s["src"].astype(np.int64)
        srec = np.array(a[src])
        if (srec["kind"] != s["kind"]).any():
            fail("stores: src_kind differs from alloc.bin")
        if (((s["flags"] & 1) != 0) != (s["old"] != 0)).any() or (((s["flags"] & 2) != 0) != (s["new"] != 0)).any():
            fail("stores: the pointer flags and the ids disagree")
        if (s["field"].astype(np.int64) >= srec["len"].astype(np.int64)).any():
            fail("stores: a field index past the object's length")
    print("%s: %d objects, %d bytes, %d samples, %d stores, %d fields: %s" % (d, n, total, ns, nst, foff, "ok" if ok else "FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
