# The census VM

`bin/runevm-census` is `runevm-new` built with `-DRUNE_CENSUS` (`make
vm-census`): the same runtime and the same register-bytecode loop, with the
hooks of `vm/census.h` compiled in. It interprets everything (the JIT
allocates in line with its own idea of the header, so `--jit` is ignored)
and reports the stock VM's `--count` line, which is its correctness check
(`scripts/check-census.sh`, part of `make check`). What it adds is a record
of every allocation, every field written, every store into an existing
object, every value a primitive produces or a call passes, and how long
every object lived, measured in bytes allocated: the evidence the
heap-layout roadmap rests on (`docs/plans/heap-layout.md`, *The
experiments*).

    bin/runevm-census --jit=off --count --stats --heap-size 1073741824 --heap-fill 50 \
        --census-dir DIR [--census-every BYTES] [--census-summary] FILE.rbc ARGS...
    bin/runevm-census --census-static FILE.rbc

`--census-dir DIR` turns tracing on and names the directory (made if
missing) for the files below. `--census-every BYTES` forces a collection
every BYTES bytes allocated (default 262144; 0 for none), which is how the
census samples liveness: with a 1 GiB semispace and `--heap-fill 50` no
other collection happens, so an object's death is bracketed by two
samples. `--census-summary` writes `census.txt` and `pcs.bin` alone, with no
per-object memory, for a program that allocates tens of gigabytes; its
survival table comes from the birth sample kept in each object's header.
`--census-static FILE.rbc` prints the static census of the program (below)
and exits. `scripts/census.sh WORKLOAD...` runs a workload on both VMs,
checks them against each other and keeps the traces under
`tests/out/census/WORKLOAD`; `vm/layouts.h` holds the size models of the
candidate layouts that the first-order sizes of `census.txt` use.

The header of an object is 16 bytes in this build (an `id` word after the
stock header), and the census subtracts it from what `--count` reports, so
that the bytes are the stock VM's. Ids start at 1 in allocation order.

## The trace files (--census-dir DIR)


All integers little-endian, fixed width. Object ids start at 1 (0 = none),
in allocation order; id N's record is at index N of alloc.bin.
Sizes are L0 sizes (today's layout: 8 + round16(max(16, 16*len)), strings
8 + round16(max(16, len))), computed by `l0size(kind, len)`; the census VM's
own header is 16 bytes (an id word) but no L0 size counts it.

### alloc.bin -- 16 bytes per object, index = id
    u8  kind        vm.h ObjKind: TUPLE 1, CON 2, CLOSURE 3, STRING 4, REF 5, ARRAY 6, EXN 7, EXNCON 8
    u8  site_kind   0 = an opcode of vm/new (site = its pc), 1 = a primitive under PRIM/PRIMPUSH
                    (site = pc of that PRIM, prim = prim number in the high 16 bits of func? no: see census.txt),
                    2 = runtime (loader, vm_start, vm_raise_builtin): site = 0xFFFFFFFF
    u16 contag
    u32 len         fields, or bytes for STRING
    u32 site        pc of the allocating instruction (TUPLE, CLOSURE, CON, CONN, NEWEXN, MKEXN, PRIM, PRIMPUSH)
    u32 func        function index of the frame that allocated (0xFFFFFFFF for runtime)
The allocation clock of id = prefix sum of l0size over ids < id (the simulator of heap-layout M2 computes it).

### fields.bin -- for every non-STRING object in id order, len x 2 bytes (the tags at the
   end of the allocating instruction, i.e. after its fill; see census_flush)
    byte 0: bits 0-2 tag (vm.h enum Tag: UNIT 0, INT 1, WORD 2, REAL 3, CHAR 4, CON0 5, PTR 6)
            bits 3-6 pointee kind (ObjKind above) when tag = PTR, else 0
            bit 7   spare
    byte 1: bits 0-2 bits class (BC below)
            bits 3-6 source rep (REP_* of the register the field came from, from
                    Function.reps at TUPLE/CONN/CLOSURE/CON sites; 15 = unknown, e.g. a
                    primitive's fill)
            bit 7   spare
Bits class BC of a value:  INT/CHAR/CON0: b = bits of the two's-complement value
   (64 - leading sign bits + 1, 1..64); WORD: b = 64 - clz (0..64);
   0: b <= 8, 1: <= 31, 2: <= 48, 3: <= 51, 4: <= 62, 5: <= 63, 6: 64.
   REAL: 0 if the double's 11-bit exponent field is in [0x3ff-0x1ff, 0x3ff+0x200)
   (Koka's value-encodable range: fits a 63-bit immediate), 7 otherwise (also NaN/inf).
   UNIT/PTR: 0.
The offset of id's fields = prefix sum of len over non-string ids < id (index built once).

### stores.bin -- 16 bytes per store into an existing object (ref_set, array_update, SETENV;
   NOT the fill of a fresh object)
    u32 clock16     allocation clock at the store, in 16-byte units (bytes / 16)
    u32 src_id      the object stored into
    u32 dst_id      id of the new value if it is a pointer, else 0
    u16 field       field index
    u8  site        0 = SETENV, 1 = ref_set, 2 = array_update
    u8  flags       bit 0: the old value was a pointer; bits 1-3: tag of the new value;
                    bits 4-7: rep of the source register (15 = unknown)

### death.bin -- u32 per id (index = id): the last sample at which the object was
   alive: death[id] = k means alive at sample k, dead by sample k+1 (died in
   (clock[k], clock[k+1]]); 0 = never survived a forced collection;
   0xFFFFFFFF = alive at exit.

### samples.bin -- 24 bytes per forced collection (sample k = record k, k >= 1):
    u64 clock       bytes allocated (L0) when the collection ran
    u64 live_bytes  L0 bytes that survived
    u64 live_objs   objects that survived

### pcs.bin -- u64 per code byte: executions of the instruction starting there.

### census.txt -- text tables:
    alloc by (kind, contag, len): objects, bytes
    alloc by site: pc, func, kind, len, objects, bytes (top 200) and by function (all)
    prim results: [prim][tag][b 0..64] counts
    calls: [op][tag][b][rep] counts of values crossing CALL/TAILCALL/CALLK/TAILCALLK/RET
    stores by site x new tag x (age class of src, dst): <256K, <1M, <4M, <32M, >=32M bytes since birth
    reals: produced, crossing calls, stored at allocation, stored later, value-encodable share
    first-order sizes: sum of layout_obj_size over allocations, per layout and variant (layouts.h)

## The static census (--census-static)

What the loader's tables say of a register-bytecode program, TSV on stdout:

    F  func name nlocals arity has_meta  n_ANY n_INT n_WORD n_REAL n_CHAR n_CON0 n_PTR n_CON n_UNIT
    S  pc func opcode prim n srcreps dstrep file line

One `F` line per function: its registers by representation (from the
representations section; `has_meta` 0 when the function has none). One `S`
line per site that allocates, stores, calls or returns (TUPLE, CONN,
CLOSURE, CON, SETENV, PRIM, PRIMPUSH, CALL, TAILCALL, CALLK, TAILCALLK,
RET, NEWEXN, MKEXN): the primitive's name under PRIM and PRIMPUSH, the
number of source registers listed and their representations (CALL and
TAILCALL: the closure then the argument; SETENV: the closure then the
value; CLOSURE: the captured registers; MKEXN: the constructor then the
payload), the destination register's representation or `-`, and the
source position. A representation is 0..8 as `docs/bytecode.md` numbers
them, 15 where the function has no section. Joined with `pcs.bin` and
`alloc.bin` by site, it says what the compiler knew at every allocation.
