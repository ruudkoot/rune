# The census VM

`bin/runevm-census` is `runevm` built with `-DRUNE_CENSUS` (`make
vm-census`): the same runtime and the same register-bytecode loop, with the
hooks of `runtime/census/census.h` compiled in. It interprets everything (the JIT
allocates in line with its own idea of the header, so `--jit` is ignored)
and reports the stock VM's `--count` line, which is its correctness check
(`scripts/check-census.sh`, `make test-census`, part of `make check`). What
it adds is a record of every allocation, every field written, every store
into an existing object, every value a primitive produces or a call passes,
how long every object lived, measured in bytes allocated, and at every
sample the stack and the instruction count: the evidence the heap-layout
roadmap (`docs/plans/heap-layout.md`, *The experiments*) and the
second-generation collector's (`docs/plans/garbage-collector-v2.md`, *The
experiments*) rest on. `tools/heapsim` replays the traces under models of
collectors (`tools/heapsim/README.md`).

    bin/runevm-census --jit=off --count --stats --heap-size 268435456 --heap-fill 50 \
        --census-dir DIR [--census-every BYTES] [--census-summary] [--census-graph] FILE.rbc ARGS...
    bin/runevm-census --census-static FILE.rbc

`--census-dir DIR` turns tracing on and names the directory (made if
missing) for the files below. `--census-every BYTES` forces a collection
every BYTES bytes allocated (default 32768; 0 for none), which is how the
census samples liveness: with a semispace whose half holds the live data and
the interval, and `--heap-fill 50`, no other collection happens, so an
object's death is bracketed by two samples; a nursery can be modelled from
four intervals up (128 KiB at the default). `--census-summary` writes
`census.txt`, `meta.txt` and `pcs.bin` alone, with no per-object memory, for
a program that allocates tens of gigabytes; its survival table comes from
the birth sample kept in each object's header. `--census-graph` adds
`graph.bin`, the object each field points to at allocation.
`--census-static FILE.rbc` prints the static census of the program (below)
and exits.

`scripts/census.sh [--every N] [--graph] [--heap BYTES] [--name NAME]
WORKLOAD...` runs a workload on both VMs, checks the two `--count` lines
and outputs against each other and keeps the trace under
`tests/out/census/WORKLOAD` (`--out DIR` elsewhere), with a `DONE` file
(below); the comment at the top of the script says what the workloads are.
Its default semispace is 1 GiB; `--heap 268435456` gives the same samples
for any workload whose live data stays under 100 MiB, in less memory. The
bootstrap takes about 21 minutes at 32 KiB and writes 1.3 GB (34.2 million
objects, 27,227 samples; 465 MB resident), `compile-sigs` 11 seconds.
`tools/heapsim/checktrace.py DIR` checks a trace's consistency and
`tools/heapsim/checkold.py DIR` its old values (*Checks*, below);
`runtime/census/layouts.h` holds the size models: `w8_obj_size`, today's,
and the heap-layout study's candidates for the first-order sizes of
`census.txt`.

The header of an object is 16 bytes in this build (an `id` word after the
stock header), and the census subtracts it everywhere, so that the bytes
are the stock VM's; each semispace is half again as large as its stock
size to hold the extra words, and a collection happens where the stock
VM's would. The copied bytes of the census VM's `--stats` line count the
extra words: use the trace, not that line.

## The trace files (--census-dir DIR), format 2

The word layout's traces (format 2, layout W8; format 1 was the 16-byte
cells' of heap-layout M1, which the census VM no longer writes). All
integers little-endian, fixed width, no padding between records, no file
headers. Object ids start at 1 in allocation order (0 = none, or not a
pointer); id N's record is record N of alloc.bin, record 0 being zeros.

**Sizes** are the stock VM's (`runtime/value.h` `obj_size_of`; layouts.h
`w8_obj_size`): an 8-byte header and a payload rounded up to 8 and at least
8 -- len bytes for STRING and BYTES, 8 for REAL and BOX, 8 x len otherwise.
The least object is 16 bytes and every size a multiple of 8. The census VM
checks the rule against the VM's own size at every allocation and stops if
they differ; its id word is never counted.

**The allocation clock** of id N is the sum of the sizes of ids 1..N-1, the
boxes of the word (REAL, BOX) included: it is the stock VM's heap
allocation. `--count`'s bytes and objects (and `--stats`' bytes allocated)
leave the boxes out, so the count's bytes are the clock at exit less the
boxes' sizes; `census.txt` and `meta.txt` give both totals.

**The objects made before the trace.** The VM makes six REAL boxes as it
starts (+0.0, -0.0, +inf, -inf and the two NaNs), before the trace is
opened. They are ids 1..6, site kind 3, on the clock at 0..95, and alive at
exit; `meta.txt` says how many there are (`pretrace_objects`).

### alloc.bin -- 16 bytes per object, record N = id N (record 0 zeros)
    u8  kind        value.h ObjKind: TUPLE 1, CON 2, CLOSURE 3, STRING 4, REF 5, ARRAY 6, EXN 7,
                    EXNCON 8, REAL 10 (a boxed double), BOX 11 (an Int64 or Word64 beyond 63 bits),
                    BYTES 12 (Word8Array, CharArray), REALS 13 (RealArray, RealVector); never FORWARD 9
    u8  site_kind   0 = an instruction of runtime/register (site = its pc), 1 = a primitive under
                    PRIM/PRIMPUSH (site = that pc), 2 = the runtime (the loader's constants, vm_start's
                    exception constructors, vm_raise_builtin), 3 = made before the trace (VM start-up);
                    site = func = 0xFFFFFFFF for 2 and 3
    u16 contag      the constructor's tag (CON), else 0
    u32 len         fields; bytes for STRING and BYTES; doubles for REALS; 1 for REAL and BOX
    u32 site        pc of the allocating instruction
    u32 func        function index of the frame that allocated

### fields.bin -- 2 bytes per field of every object with fields, in id order
The objects with fields are those the collector scans (value.h
`obj_has_fields`): every kind but STRING, REAL, BOX, BYTES and REALS, which
have no entries. The offset of id N's fields is 2 x the sum of len over the
ids before N that have fields. A field's value is recorded at the end of
the allocating instruction (*Limits*).

    byte 0: bits 0-1 the word: 0 an immediate (low bit 1: an int, word, char, constructor tag, unit
                     or a real in its encoding -- the word does not say which), 1 a pointer to an
                     object (a box included), 2 null
            bits 2-5 the pointee's kind when a pointer, else 0
            bits 6-7 0
    byte 1: bits 0-3 source rep: the REP_* of the register the field came from (docs/bytecode.md:
                     ANY 0, INT 1, WORD 2, REAL 3, CHAR 4, CON0 5, PTR 6, CON 7, UNIT 8, INT64 9,
                     WORD64 10), from Function.reps at TUPLE/CONN/CLOSURE/CON/MKEXN sites; 15 =
                     unknown (a primitive's or the runtime's fill)
            bits 4-6 bits class of an immediate's signed 63-bit payload (0 <= 8 bits, 1 <= 31,
                     2 <= 48, 3 <= 51, 4 <= 62, 5 = 63); 7 for a word that is not an immediate
            bit 7    0
Under the word layout the word has no type, so the type is the rep's
(format 1 had a 3-bit tag here).

### graph.bin (--census-graph) -- 4 bytes per field, as fields.bin
    u32 the id of the object the field points to at the end of the allocating instruction;
        0 when it is not a pointer
Id N's entries are at 4 x the field index fields.bin's are at.

### stores.bin -- 24 bytes per store into an object that exists
Every SETENV, `ref_set` and `array_update` (in the loop and in the
primitive): every store through the VM's barrier (value.h
`obj_set_field`), not the fill of a fresh object nor a raw store into BYTES
or REALS.

    u32 clock8      the allocation clock at the store / 8 (exact: every size is a multiple of 8);
                    the store comes after every id whose clock is below clock8 x 8
    u32 src_id      the object stored into
    u32 new_id      the id of the new value if it is a pointer to an object (a box included), else 0
    u32 old_id      the id of the value overwritten if it was a pointer to an object, else 0 (what a
                    snapshot barrier logs)
    u32 field       the field index
    u8  site        0 = SETENV, 1 = ref_set, 2 = array_update
    u8  flags       bit 0 the old value a pointer; 1 the new value a pointer; 2 the new value a box
                    (REAL, BOX); 3 the old value a box
    u8  rep         the rep of the new value's register (15 = unknown: the primitive)
    u8  src_kind    the kind of the object stored into (REF 5, ARRAY 6, CLOSURE 3)

### death.bin -- u32 per id (index = id; entry 0 unused)
`death[id] = k`: the object was alive (copied) at sample k and dead by
sample k+1, so it died in (clock of sample k, clock of sample k+1]; 0 =
it never survived a collection; 0xFFFFFFFF = alive at exit (it survived
the final collection).

### samples.bin -- 64 bytes per collection; record j (from 0) is sample k = j + 1
Every collection is a sample: the forced ones (every `--census-every`
bytes of clock), any the heap forces (none where the semispace's half holds
the live data and the interval), and the final one at exit.

    u64 clock         the allocation clock when the collection ran
    u64 live_bytes    the bytes that survived it (the stock VM's heap use after it)
    u64 live_objs     the objects that survived it
    u64 instructions  the instructions executed before it (--count's counter: a deterministic
                      mutator clock)
    u64 last_id       ids 1..last_id were allocated before it
    u32 sp            the value stack's depth in slots: the collector scans [0, sp) (the live
                      registers only of the waiting frames)
    u32 fp            the running frame's index (frames 0..fp exist)
    u32 fp_low        the lowest frame index reached since the previous sample (after a return or
                      an exception's unwinding), fp of the previous sample where none returned
                      below it, and from 0 for the first sample: frames 0..fp_low-1 were suspended
                      throughout
    u32 base_low      frames[fp_low].base: the slots [0, base_low) belong to frames suspended since
                      the previous sample (what a stack watermark lets a minor collection skip)
    u32 sp_ptrs       the slots of [0, sp) that held a pointer when the collection began
    u32 flags         bit 0 forced by --census-every; 1 the final collection at exit (the last
                      sample alone); 2 the heap grew at it

### pcs.bin -- u64 per byte of code: the executions of the instruction that starts there.

### meta.txt -- `key value` lines, written at exit: what a reader of the trace needs first
    format 2                         layout W8
    every N                          the --census-every interval
    fields 0|1, graph 0|1, summary 0|1
    objects N, bytes N               every object, boxes included: the clock at exit
    count_objects N, count_bytes N   the boxes left out: --count's
    boxes N, box_bytes N             REAL and BOX objects, those made before the trace included
    pretrace_objects N, pretrace_bytes N
    samples N, stores N, instructions N
    nglobals N, nconsts N            the roots besides the stack
    fields_bytes N                   the size of fields.bin

### DONE -- written by scripts/census.sh when the two VMs agree
    count runevm: count: I instructions, B bytes, O objects   the stock VM's, equal to the census's
    wall S s                         the census's run
    every N, layout W8, version 2
    census-heap N                    the census VM's --heap-size
    flags --census-every N ...       the census flags used
    mode summary                     where --census-summary was
    cwd DIR, cmd FILE.rbc ARGS       how the stock VM ran, for tools/heapsim/validate.sh and
                                     validate2.sh to run it again at other heap settings
    out FILE                         the file the compiler writes, if any (deleted before each run:
                                     the compiler looks at it first, docs/testing.md)
    runevm: C collections, ...       the census VM's --stats line

### census.txt -- text tables
    the totals: objects and bytes with the boxes and without (--count's), the boxes, the
        instructions, the samples
    alloc by kind, by (kind, contag, len), by site (top 200) and by function
    fields at allocation by tag (the source rep's where known, else what the word shows: an
        immediate INT, a REAL box REAL, a BOX INT, a pointer PTR)
    prim results: [prim][tag][b 0..64] counts
    calls: [op][tag][b][rep] counts of values crossing CALL/TAILCALL/CALLK/TAILCALLK/RET
    stores by site x new tag x (age class of src, dst): <256K, <1M, <4M, <32M, >=32M bytes since birth
    reals: produced, crossing calls, stored at allocation, stored later, value-encodable share
    first-order sizes: W8 (the trace itself) and the heap-layout study's layouts (layouts.h), under
        which the word's boxes are not objects but are counted as their fields need them
    survivors by age in samples

### Limits
- A field is recorded at the end of the allocating instruction, or at the
  next allocation if that comes first: a primitive that allocates A, then
  B, then fills A's fields records A's fields before that fill (as unit).
  A pointer written that way is in neither fields.bin, graph.bin nor
  stores.bin.
- clock8 and the birth clock of every object are u32 in 8-byte units, and
  ids are u32: a full trace stops at 32 GiB of allocation or 2^32 - 2
  objects (`--census-summary` has neither limit).
- Reads are not recorded.
- The counts are those of `bin/runevm --jit=off --count`, and depend, as
  every count does, on the input's kind and the compiler's output path
  (docs/testing.md); within one run the two VMs always agree.
- At a sample every register of the running frame is a root, its dead ones
  included, while the waiting frames' dead registers are cleared: a census
  keeps a little more alive than a stock VM that collects between its
  samples (a few kilobytes on the bootstrap).

### Checks
- `tools/heapsim/checktrace.py DIR`: the file sizes against `meta.txt`;
  the clock (the sum of `w8_obj_size`) and the count totals; every sample's
  live bytes and objects recomputed from death.bin and the sizes; every
  sample's clock the prefix sum at its last_id, and the final flag on the
  last sample alone; the frames (fp_low <= fp, base_low <= sp); graph.bin
  against fields.bin (a pointer field, and only one, has an id, older than
  its object, of the kind fields.bin says); every store's ids allocated by
  its clock, its src_kind, flags and field. Memory about 60 bytes an object
  (2 GB on the bootstrap). `make test-census` runs it where python3 has
  numpy.
- `tools/heapsim/checkold.py DIR` (a trace with graph.bin): each store's
  old_id is the previous store's new_id into that field, or the field's
  value in graph.bin.
- `bin/gcsim --trace DIR --check` and `bin/heapsim --trace DIR --check`:
  death.bin and the sizes against the census's live bytes at every sample.
- The final sample's instructions equal `--count`'s.

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
