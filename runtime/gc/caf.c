/* CAF tables (the haskell98 roadmap's D19, B; GHC's static reference
   tables, docs/runtime.md, *The roots*): a full collection keeps a global
   only where code that may still run reads it, so that a CAF -- a global
   that holds a suspension, a top-level lazy list among them -- no live
   code reads any more is let go.

   Only in a program with suspensions: one some function of which says
   UPDATE or BLACKHOLE (Program.suspends, set where the program's code is
   checked, as reruns is). A program of SML has none, and its globals stay
   roots, as they always were; it builds no table and pays one test a full
   collection. runevm --caf-tables=off keeps every global a root whatever
   the program, and --caf-tables=on takes the tables in every program (a
   test of them on SML's).

   What each function's code reaches is worked out from the bytecode,
   which every engine keeps (the JIT compiles from it, runeopt's programs
   carry it), at the first full collection that takes the tables: the
   globals its code reads (GLOBAL) and, through every function it calls by
   name or makes a closure of (the operands of kind function: CALLK,
   TAILCALLK, CLOSURE), what theirs reach. One table to each strongly
   connected group of the call graph, as GHC's recursive closures share one
   (Marlow, "New SRTs", 2018); a group whose table is empty is taken for
   good, so that what its functions make costs one test. A frame's table is
   what its function's code reaches from where the frame waits (its pc) and
   from every handler the function installs, made the first time a frame
   waits there.

   A collection then takes as roots what OTHER_ROOTS takes but the
   globals, and a global only where reached: by a frame's table (the
   running frame's, all of its function's, since a collection comes in the
   middle of an instruction); by an object marked whose code may run, a
   closure or a suspension not yet evaluated, all of its function's table;
   and, where units are loaded, by what they export (an exported global,
   and an exported function's table: a unit loaded later may name either).
   The frames' own closures come last (caf_frames sets them aside while
   the rest is marked): a closure only the frames hold runs only from where
   they wait, which their tables cover, and it takes all of its function's
   table only where another reference reaches it (a bit of the header,
   CAF_ONLY, for the collection). A global no live code reaches is unit
   after the marking: nothing can read it again.

   The tables are the VM's, made again after a unit is loaded or an image
   read (caf_reset). The full collection of the non-moving old spaces
   (mark.c), the copier (copy.c) and the low-pause collector's cycle
   (cycle.c) take them; the cycle, whose globals are no roots of its
   snapshot and which has no barrier on SETGLOBAL, keeps a copy of the
   globals as they were when it began and marks a global reached both as
   it was then and as it is (caf_cycle_begin). Minor collections take the
   globals written since the last, as they always did. */
#include "gc/gc.h"
#include "sys/sys.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* a frame's table; and, for the stack's summary (copy.c, gc_stack_roots),
   the lowest frame below the summary's slots that waits where it was made
   (SIZE_MAX: none), and whether it is in the summary's list
   (CafTables.kept) */
typedef struct PcTable { uint32_t pc, next; uint64_t epoch; uint64_t *bits; size_t low; int listed; } PcTable;
/* a frame the stack's summary has, whose table is not looked up yet */
typedef struct PendFrame { size_t base; uint32_t func, pc; } PendFrame;

struct CafTables {
    int ready, failed, stale;
    uint32_t nfuncs, nglobals, words;
    uint8_t *caf;            /* per global: 1 where it has held a suspension (a CAF), counted (--stats) */
    uint32_t ncafs;          /* the globals caf has room for */
    uint8_t *reached;        /* per global: reached in this collection */
    uint32_t *scc;           /* per function: its group */
    uint32_t nscc;
    uint64_t *sccbits;       /* per group: words, what its code reaches */
    uint64_t *sccepoch;      /* per group: the collection it was last taken in (CAF_EMPTY: nothing to take) */
    PcTable *pcs;            /* frames' tables, a pool: each function's a list from pcfirst */
    uint32_t *pcfirst;       /* per function: its first frame table, 1 + its place in pcs (0: none) */
    uint32_t npcs, cappcs;
    /* the frames' tables the stack's summary keeps (PcTable.low), for the
       frames below the slots a walk decodes again (caf_frames) */
    uint32_t *kept;
    uint32_t nkept, capkept;
    size_t kept_to;          /* kept and the bits of closures have the frames below this slot; pend those from it up */
    /* the frames above kept_to, lowest first, each as a walk gave it
       (caf_record): their tables and closures made at the next full
       collection (kept_fold) */
    PendFrame *pend;
    size_t npend, cappend;
    struct { uint64_t key, fold; } met[64];   /* the places a fold met, by a hash */
    uint64_t folds;
    int noted;               /* every global looked at once for a CAF (caf_begin) */
    Value *snap;             /* the cycle's: the globals as they were when it began (caf_cycle_begin) */
    uint64_t epoch;
    uint64_t ncaf, dropped, dropped_cafs, frames_taken, code_taken, frames_walked, slots_deferred, builds;
    uint64_t build_ns;
};
#define CAF_EMPTY UINT64_MAX

CafFast caf_fast;

static inline void bit_set(uint64_t *b, uint32_t i) { b[i >> 6] |= (uint64_t)1 << (i & 63); }
static inline void bits_or(uint64_t *d, const uint64_t *s, uint32_t w) { for (uint32_t i = 0; i < w; i++) d[i] |= s[i]; }
static int bits_empty(const uint64_t *b, uint32_t w) { for (uint32_t i = 0; i < w; i++) if (b[i]) return 0; return 1; }

/* the walk's callbacks: a global read, a function called or made a
   closure of (every function's callees in one array, each function's from
   its start) */
typedef struct Walk { CafTables *t; uint64_t *bits; uint32_t *callees; size_t ncallees, cap; int failed; } Walk;
static void on_global(void *c, uint32_t g) { Walk *w = c; if (g < w->t->nglobals) bit_set(w->bits, g); }
static void on_callee(void *c, uint32_t f) {
    Walk *w = c;
    if (f >= w->t->nfuncs) return;
    if (w->ncallees == w->cap) {
        size_t cap = w->cap ? 2 * w->cap : 1024;
        uint32_t *a = realloc(w->callees, cap * sizeof(uint32_t));
        if (!a) { w->failed = 1; return; }
        w->callees = a; w->cap = cap;
    }
    w->callees[w->ncallees++] = f;
}

/* the tables dropped (the program's code changed, or they were never made) */
static void tables_free(CafTables *t) {
    free(t->reached); free(t->scc); free(t->sccbits); free(t->sccepoch); free(t->pcfirst);
    for (uint32_t i = 0; i < t->npcs; i++) free(t->pcs[i].bits);
    free(t->pcs);
    free(t->kept);
    free(t->pend);
    t->kept = NULL;
    t->pend = NULL;
    t->nkept = t->capkept = 0;
    t->npend = t->cappend = 0;
    t->kept_to = 0;
    t->reached = NULL; t->scc = NULL; t->sccbits = NULL; t->sccepoch = NULL; t->pcfirst = NULL; t->pcs = NULL;
    t->npcs = t->cappcs = 0; t->nscc = 0;
    t->ready = 0;
    caf_fast.nfuncs = 0; caf_fast.scc = NULL; caf_fast.sccepoch = NULL;
}

/* Tarjan's groups of the call graph, each group's table the union of its
   members' own reads and the tables of the groups they call, which are
   done before it (iteratively: a program's call graph is deep) */
static int build(VM *vm, CafTables *t) {
    const Program *p = &vm->prog;
    t->nfuncs = p->nfuncs; t->nglobals = p->nglobals; t->words = (p->nglobals + 63) / 64;
    if (!t->words) t->words = 1;
    uint32_t n = t->nfuncs, W = t->words;
    t->noted = 0;
    t->reached = calloc(t->nglobals + 1, 1);
    uint64_t *own = calloc((size_t)n * W, sizeof(uint64_t));
    size_t *start = calloc((size_t)n + 1, sizeof(size_t));
    if (!t->reached || !own || !start) { free(own); free(start); return 0; }
    Walk w = {t, NULL, NULL, 0, 0, 0};
    for (uint32_t f = 0; f < n; f++) {
        w.bits = own + (size_t)f * W;
        start[f] = w.ncallees;
        if (isa_caf_walk(p, f, p->funcs[f].code_offset, on_global, on_callee, &w) < 0 || w.failed) {
            free(w.callees); free(own); free(start); return 0;
        }
    }
    start[n] = w.ncallees;
    uint32_t *callees = w.callees;
#define NCALLS(f) (start[(f) + 1] - start[f])
#define CALL(f, i) (callees[start[f] + (i)])
    uint32_t *index = malloc(n * sizeof(uint32_t)), *low = malloc(n * sizeof(uint32_t)), *stack = malloc(n * sizeof(uint32_t));
    uint8_t *on = calloc(n, 1);
    uint32_t *cs_f = malloc(n * sizeof(uint32_t)); size_t *cs_i = malloc(n * sizeof(size_t));
    t->scc = malloc(n * sizeof(uint32_t));
    uint64_t *sccbits = calloc((size_t)n * W, sizeof(uint64_t));   /* at most n groups; shrunk below */
    int ok = index && low && stack && on && cs_f && cs_i && t->scc && sccbits;
    if (ok) {
        for (uint32_t f = 0; f < n; f++) index[f] = UINT32_MAX;
        uint32_t next = 0, sp = 0, nscc = 0;
        for (uint32_t root = 0; root < n; root++) {
            if (index[root] != UINT32_MAX) continue;
            size_t depth = 0;
            cs_f[depth] = root; cs_i[depth] = 0; depth++;
            index[root] = low[root] = next++; stack[sp++] = root; on[root] = 1;
            while (depth) {
                uint32_t f = cs_f[depth - 1];
                if (cs_i[depth - 1] < NCALLS(f)) {
                    uint32_t g = CALL(f, cs_i[depth - 1]++);
                    if (index[g] == UINT32_MAX) {
                        index[g] = low[g] = next++; stack[sp++] = g; on[g] = 1;
                        cs_f[depth] = g; cs_i[depth] = 0; depth++;
                    } else if (on[g] && index[g] < low[f]) low[f] = index[g];
                    continue;
                }
                /* f done */
                if (low[f] == index[f]) {
                    uint32_t s = nscc++;
                    uint64_t *b = sccbits + (size_t)s * W;
                    size_t first = sp;
                    do { uint32_t m = stack[--sp]; on[m] = 0; t->scc[m] = s; bits_or(b, own + (size_t)m * W, W); } while (stack[sp] != f);
                    /* the groups its members call are done (and have their own numbers) */
                    for (size_t k = sp; k < first; k++) {
                        uint32_t m = stack[k];
                        for (size_t c = 0; c < NCALLS(m); c++) { uint32_t s2 = t->scc[CALL(m, c)]; if (s2 != s) bits_or(b, sccbits + (size_t)s2 * W, W); }
                    }
                }
                depth--;
                if (depth) { uint32_t parent = cs_f[depth - 1]; if (low[f] < low[parent]) low[parent] = low[f]; }
            }
        }
        t->nscc = nscc;
        uint64_t *shrunk = realloc(sccbits, (size_t)(nscc ? nscc : 1) * W * sizeof(uint64_t));
        if (shrunk) sccbits = shrunk;
        t->sccbits = sccbits; sccbits = NULL;
        t->sccepoch = calloc(nscc ? nscc : 1, sizeof(uint64_t));
        t->pcfirst = calloc(n ? n : 1, sizeof(uint32_t));
        ok = t->sccepoch && t->pcfirst;
        /* a group that reaches no global: nothing ever to take */
        if (ok) for (uint32_t s = 0; s < nscc; s++) if (bits_empty(t->sccbits + (size_t)s * W, W)) t->sccepoch[s] = CAF_EMPTY;
    }
#undef NCALLS
#undef CALL
    free(index); free(low); free(stack); free(on); free(cs_f); free(cs_i); free(sccbits);
    free(own); free(start); free(callees);
    return ok;
}

/* the globals of bits not yet reached in this collection, visited: as
   they are, and as they were when the cycle began where one marks */
static void take(VM *vm, CafTables *t, const uint64_t *bits, void (*visit)(VM *, Value *)) {
    for (uint32_t i = 0; i < t->words; i++) {
        uint64_t w = bits[i];
        while (w) {
            uint32_t g = i * 64 + (uint32_t)__builtin_ctzll(w);
            w &= w - 1;
            if (g < t->nglobals && !t->reached[g]) {
                t->reached[g] = 1;
                visit(vm, &vm->globals[g]);
                if (t->snap) visit(vm, &t->snap[g]);
            }
        }
    }
}

/* where a global holds a suspension, it is a CAF from then on (before any
   collection shortcuts the indirection it becomes): counted, for --stats,
   in a program with suspensions from its first minor collection on
   (caf_note_written) */
void caf_note(VM *vm, uint32_t g) {
    if (vm->caf_mode == CAF_MODE_OFF || g >= vm->prog.nglobals) return;
    if (!vm->caf && !(vm->caf = calloc(1, sizeof(CafTables)))) return;
    CafTables *t = vm->caf;
    if (g >= t->ncafs) {
        uint32_t n = vm->prog.nglobals;
        uint8_t *c = realloc(t->caf, n);
        if (!c) return;
        memset(c + t->ncafs, 0, n - t->ncafs);
        t->caf = c; t->ncafs = n;
    }
    if (t->caf[g]) return;
    Value v = vm->globals[g];
    if (val_is_ptr(v) && (obj_kind(val_ptr(v)) == K_THUNK || obj_kind(val_ptr(v)) == K_IND)) { t->caf[g] = 1; t->ncaf++; }
}
/* the globals written since the last minor collection noted, as it takes
   them (minor.c; a program with suspensions) */
void caf_note_written(VM *vm) {
    const uint8_t *set = vm->global_set;
    if (!set || vm->caf_mode == CAF_MODE_OFF) return;
    for (uint32_t g = 0; g < vm->prog.nglobals; g++) if (set[g] == 1) caf_note(vm, g);
}

/* the tables made again at the next full collection: the program's code
   or its globals changed (a unit loaded, loader.c), or the VM was made
   again from an image (image.c). Not before: a cycle that marks goes on
   with the tables it began with, which know nothing of the new functions
   and globals and so let none of them go, and keep every export a root. */
void caf_reset(VM *vm) {
    if (vm->caf) vm->caf->stale = 1;
}

void caf_free(VM *vm) {
    if (!vm->caf) return;
    tables_free(vm->caf);
    free(vm->caf->caf);
    free(vm->caf->snap);
    free(vm->caf);
    vm->caf = NULL;
}

/* Whether this full collection keeps the globals by the tables: in a
   program with suspensions (or under --caf-tables=on), once the program
   runs, the tables made where they are not. 0 keeps every global a root. */
int caf_begin(VM *vm) {
    if (vm->caf_mode == CAF_MODE_OFF) return 0;
    if (vm->caf_mode == CAF_MODE_AUTO && !vm->prog.suspends) return 0;
    /* a collection while the program loads (its code not all there yet), or
       before it runs: every global a root */
    if (!vm->frames_active) return 0;
    if (!vm->caf && !(vm->caf = calloc(1, sizeof(CafTables)))) return 0;
    CafTables *t = vm->caf;
    if (t->stale) { tables_free(t); t->stale = 0; t->failed = 0; }
    if (!t->ready) vm->gc.stack_aside_valid = 0;   /* the tables the summary kept, gone */
    if (t->failed) return 0;
    if (!t->ready) {
        int64_t t0 = sys_clock_ns();
        if (!build(vm, t)) {
            tables_free(t);
            t->failed = 1;
            fprintf(stderr, "runevm: no CAF tables of this program's code (out of memory): every global a root\n");
            return 0;
        }
        t->ready = 1;
        t->builds++;
        t->build_ns += (uint64_t)(sys_clock_ns() - t0);
        caf_fast.nfuncs = t->nfuncs; caf_fast.scc = t->scc; caf_fast.sccepoch = t->sccepoch;
    }
    /* a global becomes a CAF only where written (caf_note_written notes those
       a minor collection takes): all of them looked at once, then those
       written since the last minor collection */
    if (!t->noted) { for (uint32_t g = 0; g < t->nglobals; g++) caf_note(vm, g); t->noted = 1; }
    else if (vm->global_set) { for (uint32_t g = 0; g < t->nglobals; g++) if (vm->global_set[g] == 1) caf_note(vm, g); }
    memset(t->reached, 0, t->nglobals);
    t->epoch++;
    caf_fast.epoch = t->epoch;
    return 1;
}

/* a function's table taken, where it is not yet in this collection */
static void take_func(VM *vm, CafTables *t, uint32_t f, void (*visit)(VM *, Value *)) {
    if (f >= t->nfuncs) return;
    uint32_t s = t->scc[f];
    if (t->sccepoch[s] >= t->epoch) return;
    t->sccepoch[s] = t->epoch;
    t->code_taken++;
    take(vm, t, t->sccbits + (size_t)s * t->words, visit);
}

/* the roots but the globals (OTHER_ROOTS_BUT_GLOBALS), and what the
   units loaded export: a global as a root, a function's table taken */
void caf_roots(VM *vm, void (*visit)(VM *, Value *), void (*visit_obj)(VM *, Obj **)) {
    CafTables *t = vm->caf;
#define CAF_V(v) visit(vm, (v))
#define CAF_O(o) visit_obj(vm, (o))
    OTHER_ROOTS_BUT_GLOBALS(vm, CAF_V, CAF_O, 0);
#undef CAF_V
#undef CAF_O
    for (uint32_t i = 0; i < vm->nunit_exports; i++) {
        const UnitExport *e = &vm->unit_exports[i];
        if (e->kind == 1 && e->index < t->nglobals) {
            if (!t->reached[e->index]) {
                t->reached[e->index] = 1;
                visit(vm, &vm->globals[e->index]);
                if (t->snap) visit(vm, &t->snap[e->index]);
            }
        } else if (e->kind == 0) take_func(vm, t, e->index, visit);
    }
}

/* a frame's table: what its function's code reaches from its pc on */
typedef struct PcWalk { CafTables *t; uint64_t *bits; } PcWalk;
static void pc_global(void *c, uint32_t g) { PcWalk *w = c; if (g < w->t->nglobals) bit_set(w->bits, g); }
static void pc_callee(void *c, uint32_t f) { PcWalk *w = c; if (f < w->t->nfuncs) bits_or(w->bits, w->t->sccbits + (size_t)w->t->scc[f] * w->t->words, w->t->words); }
static PcTable *pc_table(VM *vm, CafTables *t, uint32_t func, uint32_t pc) {
    /* each function's list the last found first (a recursion's frames
       come back to the same few) */
    for (uint32_t prev = 0, i = t->pcfirst[func]; i; prev = i, i = t->pcs[i - 1].next)
        if (t->pcs[i - 1].pc == pc) {
            if (prev) { t->pcs[prev - 1].next = t->pcs[i - 1].next; t->pcs[i - 1].next = t->pcfirst[func]; t->pcfirst[func] = i; }
            return &t->pcs[i - 1];
        }
    if (t->npcs == t->cappcs) {
        uint32_t cap = t->cappcs ? 2 * t->cappcs : 256;
        PcTable *n = realloc(t->pcs, cap * sizeof(PcTable));
        if (!n) return NULL;
        t->pcs = n; t->cappcs = cap;
    }
    uint64_t *b = calloc(t->words, sizeof(uint64_t));
    if (!b) return NULL;
    PcWalk w = {t, b};
    if (isa_caf_walk(&vm->prog, func, pc, pc_global, pc_callee, &w) < 0) { free(b); return NULL; }
    PcTable *e = &t->pcs[t->npcs++];
    e->pc = pc; e->bits = b; e->next = t->pcfirst[func];
    e->low = SIZE_MAX; e->listed = 0;
    e->epoch = bits_empty(b, t->words) ? CAF_EMPTY : 0;
    t->pcfirst[func] = t->npcs;
    return e;
}

/* The frames' closures a collection takes last (caf_frames): runtime/
   register's in the value stack (FrameRef.closure_slot), the stack VM's in
   its frame records (closure_root); each set aside -- unit, or NULL --
   while the rest is marked, and put back (caf_back) for the collector to
   take (caf_aside). */
static CafAside *aside;
static size_t naside, capaside;
/* room for n set aside: 0 where there is no memory (a closure not set
   aside is marked as the frames' other roots are) */
static int aside_room(size_t n) {
    if (n <= capaside) return 1;
    size_t cap = capaside ? capaside : 64;
    while (cap < n) cap *= 2;
    CafAside *a = realloc(aside, cap * sizeof *a);
    if (!a) return 0;
    aside = a; capaside = cap;
    return 1;
}
/* the closures of the frames below this slot set aside by the stack's
   summary's bits (GcState.stack_aside), not in the list: caf_frames to
   caf_end, 0 where none is */
static size_t aside_below;
/* the frames caf_frames walked, and where their slots begin, for
   gc_stack_roots's walk after it in the same collection (once) */
static FrameRef *reuse_f;
static size_t reuse_n, reuse_from;
static int reuse_on;
int caf_frames_reuse(FrameRef **out, size_t *n, size_t *from, size_t *below) {
    if (!reuse_on) return 0;
    reuse_on = 0;
    *out = reuse_f; *n = reuse_n; *from = reuse_from; *below = aside_below;
    return 1;
}
void caf_frames_forget(void) { reuse_on = 0; }

/* The stack's summary (copy.c, gc_stack_roots), the CAF tables' part: the
   closures of the frames that wait, a bit a slot (GcState.stack_aside),
   and the tables of the places the frames wait at, so that a collection
   takes the tables and the closures of the frames below the slots it
   decodes again from them (caf_frames). A walk that decodes the frames
   f[0, n) from slot from, where the summary has the slots below, keeps for
   the slots [0, rec) below the frame that runs each frame that waits, as
   (base, function, pc), above what it has made already (pend), lowest
   first, and nothing more: a minor collection's frames are most of them
   gone before a full collection comes (rhc's infer: 323,007 frames that
   its minor collections decode, 10,464 that its full ones do). That
   collection makes the closures' bits and the tables of the frames pend
   still has, each table with the lowest frame that waits at it
   (PcTable.low, in the list kept). Where the tables are not made yet (or
   are to be made again), or there is no memory, the part has the slots
   below from alone. */
static void kept_add(CafTables *t, uint32_t i, int *whole) {
    if (t->pcs[i].listed) return;
    if (t->nkept == t->capkept) {
        uint32_t cap = t->capkept ? 2 * t->capkept : 64;
        uint32_t *k = realloc(t->kept, cap * sizeof *k);
        if (!k) { *whole = 0; return; }
        t->kept = k; t->capkept = cap;
    }
    t->kept[t->nkept++] = i;
    t->pcs[i].listed = 1;
}
/* the summary's frames from slot from up forgotten: pend's, and where
   from is below kept_to, the tables kept of the frames from there up
   (let go of the list at the next full collection, kept_fold) */
static void pend_cut(CafTables *t, size_t from) {
    if (from < t->kept_to) { t->kept_to = from; t->npend = 0; return; }
    while (t->npend && t->pend[t->npend - 1].base >= from) t->npend--;
}
void caf_record(VM *vm, const FrameRef *f, size_t n, size_t from, size_t rec) {
    CafTables *t = vm->caf;
    if (!rec || !t || !t->ready || t->stale || vm->gc.stack_aside_valid < from) {
        if (vm->gc.stack_aside_valid > from) vm->gc.stack_aside_valid = from;
        return;
    }
    pend_cut(t, from);
    if (n && t->npend + n > t->cappend) {
        size_t cap = t->cappend ? t->cappend : 256;
        while (cap < t->npend + n) cap *= 2;
        PendFrame *p = realloc(t->pend, cap * sizeof *p);
        if (!p) { vm->gc.stack_aside_valid = from; return; }
        t->pend = p; t->cappend = cap;
    }
    PendFrame *p = t->pend + t->npend;
    for (size_t i = 0; i + 1 < n; i++) *p++ = (PendFrame){f[i].base, f[i].func, f[i].pc};
    t->npend = (size_t)(p - t->pend);
    vm->gc.stack_aside_valid = rec;
}

/* The summary's tables and closures for the frames below slot from, at a
   full collection: of those pend has, the closures' bits, and the tables
   looked up and kept, each with the lowest frame that waits at it; the
   tables kept of frames gone let go. 0 where a frame has no table (no
   memory, or no walk of its code), whose function's whole table is taken
   then (visit). */
static int kept_fold(VM *vm, CafTables *t, size_t from, void (*visit)(VM *, Value *)) {
    pend_cut(t, from);
    uint32_t m = 0;
    for (uint32_t k = 0; k < t->nkept; k++) {
        PcTable *pt = &t->pcs[t->kept[k]];
        if (pt->low >= t->kept_to) { pt->low = SIZE_MAX; pt->listed = 0; continue; }
        t->kept[m++] = t->kept[k];
    }
    t->nkept = m;
    if (t->kept_to < from) gc_bits_clear(vm->gc.stack_aside, t->kept_to, from);
    uint64_t fold = ++t->folds;
    int whole = 1;
    for (size_t i = 0; i < t->npend; i++) {
        const PendFrame *p = &t->pend[i];
        /* its closure, where it reads one (frame_at's FrameRef.closure) */
        size_t c = p->base - 2;
        if (p->func < vm->prog.nfuncs && vm->prog.funcs[p->func].reads_closure && val_is_ptr(vm->stack[c]))
            vm->gc.stack_aside[c >> 6] |= (uint64_t)1 << (c & 63);
        if (p->func >= t->nfuncs) continue;
        uint64_t key = ((uint64_t)p->func << 32) | p->pc;
        unsigned h = (unsigned)((key * 0x9E3779B97F4A7C15u) >> 58);
        if (t->met[h].fold == fold && t->met[h].key == key) continue;   /* a frame below waits there */
        t->met[h].key = key;
        t->met[h].fold = fold;
        PcTable *pt = pc_table(vm, t, p->func, p->pc);
        if (!pt) { whole = 0; take_func(vm, t, p->func, visit); continue; }
        if (pt->listed) continue;   /* a lower frame waits there */
        pt->low = p->base;
        kept_add(t, (uint32_t)(pt - t->pcs), &whole);
    }
    t->npend = 0;
    t->kept_to = from;
    return whole;
}

/* where the bits of the summary's closures are made: below kept_to, the
   rest pending (gc_stack_check) */
size_t caf_aside_made(VM *vm) {
    CafTables *t = vm->caf;
    size_t to = vm->gc.stack_aside_valid;
    return t && t->kept_to < to ? t->kept_to : to;
}

/* The frames' tables taken (visit: the collector's), a frame that waits
   from where its callee returns to, the one that runs all of its
   function's; and, where defer, their closures set aside. A closure only
   the frames hold runs only from where they wait; a suspension's code
   runs in its suspension under evaluation, which runs no other way, and
   a closure taken last is marked as it would be first. The frames below
   the slots the walk decodes again (gc_stack_frames: those that have not
   run since the stack's summary was made) are the summary's: the tables
   kept, the frames pending looked up first (kept_fold), and the closures
   of its bits. */
void caf_frames(VM *vm, void (*visit)(VM *, Value *), int defer) {
    CafTables *t = vm->caf;
    size_t from;
    aside_below = 0;
    FrameRef *f; size_t n = gc_stack_frames(vm, &f, &from, vm->gc.stack_aside_valid);
    reuse_f = f; reuse_n = n; reuse_from = from; reuse_on = 1;
    t->frames_walked += n;
    naside = 0;
    if (defer && capaside < n) aside_room(n);
    int whole = kept_fold(vm, t, from, visit);
    if (from) {
        for (uint32_t k = 0; k < t->nkept; k++) {
            PcTable *pt = &t->pcs[t->kept[k]];
            if (pt->epoch >= t->epoch) continue;
            pt->epoch = t->epoch;
            t->frames_taken++;
            take(vm, t, pt->bits, visit);
        }
        /* their closures set aside where they are, by the bits: the walk
           of the stack passes over them (gc_stack_roots), caf_aside_bits
           takes them last */
        if (defer) aside_below = from;
    }
    /* the last few (function, pc) taken, a mutual recursion's frames
       coming back to them: a frame of one of them is no new table */
    uint64_t recent[4] = {UINT64_MAX, UINT64_MAX, UINT64_MAX, UINT64_MAX};
    unsigned next_recent = 0;
    for (size_t i = 0; i < n; i++) {
        if (defer && f[i].closure && naside < capaside) {
            CafAside *a = &aside[naside];
            if (f[i].closure_slot) {
                a->slot = f[i].closure_slot; a->root = NULL; a->was = *a->slot;
                *a->slot = mk_unit();
                naside++;
            } else if (f[i].closure_root && *f[i].closure_root) {
                a->slot = NULL; a->root = f[i].closure_root; a->was = mk_ptr(*a->root);
                *a->root = NULL;
                naside++;
            }
        }
        if (f[i].func >= t->nfuncs) continue;
        if (i + 1 < n) {
            uint64_t key = ((uint64_t)f[i].func << 32) | f[i].pc;
            if (recent[0] == key || recent[1] == key || recent[2] == key || recent[3] == key) continue;
            recent[next_recent++ & 3] = key;
        }
        PcTable *pt = i + 1 < n ? pc_table(vm, t, f[i].func, f[i].pc) : NULL;
        if (!pt) { take_func(vm, t, f[i].func, visit); continue; }   /* the running frame, or no table: all of the function's */
        if (pt->epoch >= t->epoch) continue;
        pt->epoch = t->epoch;
        t->frames_taken++;
        take(vm, t, pt->bits, visit);
    }
    /* the summary's part made again, as gc_stack_roots makes its bits */
    if (vm->frame_live) {
        size_t rec = n ? f[n - 1].head : 0;
        if (rec > vm->sp || (rec && !gc_stack_room(vm, rec))) rec = 0;
        caf_record(vm, f, n, from, rec);
    }
    if (!whole) vm->gc.stack_aside_valid = 0;
}

/* --gc-verify (copy.c, gc_stack_check): every frame of f[0, n) below the
   slot to, which the summary has, waits where the summary keeps a table
   whose lowest frame is no higher, below kept_to, or is in pend as it is,
   from kept_to up */
const char *caf_stack_check(VM *vm, const FrameRef *f, size_t n, size_t to) {
    CafTables *t = vm->caf;
    if (!t->ready) return NULL;
    size_t j = 0;
    for (size_t i = 0; i + 1 < n && f[i + 1].head <= to; i++) {
        if (f[i].base >= t->kept_to) {
            while (j < t->npend && t->pend[j].base < f[i].base) j++;
            if (j == t->npend || t->pend[j].base != f[i].base || t->pend[j].func != f[i].func || t->pend[j].pc != f[i].pc)
                return "a frame below the frames that ran that the stack's summary does not have pending";
            continue;
        }
        if (f[i].func >= t->nfuncs) continue;
        const PcTable *pt = NULL;
        for (uint32_t k = t->pcfirst[f[i].func]; k; k = t->pcs[k - 1].next)
            if (t->pcs[k - 1].pc == f[i].pc) { pt = &t->pcs[k - 1]; break; }
        if (!pt || !pt->listed || pt->low > f[i].base)
            return "a frame below the frames that ran whose table the stack's summary does not keep";
    }
    return NULL;
}

/* the closures caf_frames set aside put back, the last first (a slot set
   aside twice keeps what it held first) */
void caf_back(VM *vm) {
    (void)vm;
    for (size_t i = naside; i > 0; i--) {
        CafAside *a = &aside[i - 1];
        if (a->slot) *a->slot = a->was;
        else *a->root = val_ptr(a->was);
    }
}
size_t caf_aside(CafAside **out) { *out = aside; return naside; }

/* each closure set aside by the summary's bits (aside_below) visited, and
   marked the frames' alone, as caf_aside's are */
void caf_aside_bits(VM *vm, void (*visit)(VM *, Value *)) {
    for (size_t w = 0; w << 6 < aside_below; w++) {
        uint64_t x = vm->gc.stack_aside[w];
        if ((w + 1) << 6 > aside_below) x &= ((uint64_t)1 << (aside_below & 63)) - 1;
        for (; x; x &= x - 1) {
            Value *slot = &vm->stack[(w << 6) + (size_t)__builtin_ctzll(x)];
            visit(vm, slot);
            if (val_is_ptr(*slot) && caf_runs(val_ptr(*slot))) caf_only_add(val_ptr(*slot));
        }
    }
}

/* an object marked whose code may run: all its function reaches */
void caf_code(VM *vm, Obj *o, void (*visit)(VM *, Value *)) {
    Value fv = obj_fields(o)[0];
    if (!val_is_imm(fv)) return;
    int64_t fid = val_int(fv);
    if (fid <= CLOSURE_NARY(0)) fid = CLOSURE_NARY(fid);   /* a closure of more than one parameter (value.h) */
    if (fid < 0) return;
    take_func(vm, vm->caf, (uint32_t)fid, visit);
}

/* after the marking: a global no live code reaches made unit, and the
   header bit of the closures still the frames' alone cleared */
void caf_end(VM *vm) {
    CafTables *t = vm->caf;
    t->slots_deferred += naside;
    for (size_t i = 0; i < naside; i++) {
        Obj *o = aside[i].slot ? (val_is_ptr(*aside[i].slot) ? val_ptr(*aside[i].slot) : NULL) : *aside[i].root;
        if (o) caf_only_take(o);
    }
    naside = 0;
    for (size_t w = 0; w << 6 < aside_below; w++) {
        uint64_t x = vm->gc.stack_aside[w];
        if ((w + 1) << 6 > aside_below) x &= ((uint64_t)1 << (aside_below & 63)) - 1;
        for (; x; x &= x - 1) {
            Value v = vm->stack[(w << 6) + (size_t)__builtin_ctzll(x)];
            t->slots_deferred++;
            if (val_is_ptr(v)) caf_only_take(val_ptr(v));
        }
    }
    aside_below = 0;
    reuse_on = 0;
    for (uint32_t g = 0; g < t->nglobals; g++)
        if (!t->reached[g] && vm->globals[g] != mk_unit()) {
            vm->globals[g] = mk_unit(); t->dropped++;
            if (g < t->ncafs && t->caf[g]) t->dropped_cafs++;
        }
    free(t->snap);
    t->snap = NULL;
}

/* The low-pause collector's cycle (cycle.c) begun with the tables: the
   globals as they are kept for the cycle, whose snapshot they are not a
   root of, and the frames' tables taken (shade: the cycle's), their
   closures marked with the stack; 0 where the cycle keeps every global a
   root. */
int caf_cycle_begin(VM *vm, void (*shade)(VM *, Value *)) {
    if (!caf_begin(vm)) return 0;
    CafTables *t = vm->caf;
    free(t->snap);
    t->snap = malloc((size_t)(t->nglobals ? t->nglobals : 1) * sizeof(Value));
    if (!t->snap) return 0;   /* (caf_begin's epoch unused: the next takes another) */
    memcpy(t->snap, vm->globals, (size_t)t->nglobals * sizeof(Value));
    caf_frames(vm, shade, 0);
    return 1;
}

void caf_stats(VM *vm, FILE *out) {
    CafTables *t = vm->caf;
    if (!t) return;
    fprintf(out, "runevm: caf tables %s: %llu CAFs, %llu of them dropped, %llu globals dropped in all; "
            "%u groups of %u functions, %u frame tables; frames %llu walked, %llu taken, %llu closures last; "
            "%llu codes taken; built %llu times in %llu us\n",
            t->ready ? "on" : t->failed ? "failed" : "dropped", (unsigned long long)t->ncaf, (unsigned long long)t->dropped_cafs,
            (unsigned long long)t->dropped, t->nscc, t->nfuncs, t->npcs, (unsigned long long)t->frames_walked,
            (unsigned long long)t->frames_taken, (unsigned long long)t->slots_deferred, (unsigned long long)t->code_taken,
            (unsigned long long)t->builds, (unsigned long long)(t->build_ns / 1000));
}
