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

typedef struct PcTable { uint32_t pc, next; uint64_t epoch; uint64_t *bits; } PcTable;

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
/* the frames caf_frames walked, for gc_stack_roots's walk after it in the
   same collection (vm_frames_from, low 0, once) */
static FrameRef *reuse_f;
static size_t reuse_n;
static int reuse_on;
int caf_frames_reuse(FrameRef **out, size_t *n) {
    if (!reuse_on) return 0;
    reuse_on = 0;
    *out = reuse_f; *n = reuse_n;
    return 1;
}
void caf_frames_forget(void) { reuse_on = 0; }

/* The frames' tables taken (visit: the collector's), a frame that waits
   from where its callee returns to, the one that runs all of its
   function's; and, where defer, their closures set aside. A closure only
   the frames hold runs only from where they wait; a suspension's code
   runs in its suspension under evaluation, which runs no other way, and
   a closure taken last is marked as it would be first. */
void caf_frames(VM *vm, void (*visit)(VM *, Value *), int defer) {
    CafTables *t = vm->caf;
    FrameRef *f; size_t n = vm_frames_from(vm, 0, &f);
    reuse_f = f; reuse_n = n; reuse_on = 1;
    t->frames_walked += n;
    naside = 0;
    if (defer && capaside < n) {
        size_t cap = capaside ? capaside : 64;
        while (cap < n) cap *= 2;
        CafAside *a = realloc(aside, cap * sizeof *a);
        if (a) { aside = a; capaside = cap; }
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

/* an object marked whose code may run: all its function reaches */
void caf_code(VM *vm, Obj *o, void (*visit)(VM *, Value *)) {
    Value fv = obj_fields(o)[0];
    if (!val_is_imm(fv)) return;
    int64_t fid = val_int(fv);
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
