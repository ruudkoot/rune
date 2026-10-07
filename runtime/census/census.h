/* runtime/census/census.h -- the census VM (docs/census.md): the hooks the
   runtime and runtime/register's loop call, which expand to nothing unless the VM is
   built with -DRUNE_CENSUS (`make vm-census`). Included at the end of vm.h,
   so that every file sees the same hooks. One VM per process: the state is
   global, since the hot hooks are macros on it. */
#ifndef RUNE_CENSUS_H
#define RUNE_CENSUS_H

#ifdef RUNE_CENSUS

/* --census-dir given: tracing on */
extern int census_on;
/* the forced-collection interval in L0 bytes (0: none) */
extern uint64_t census_every;
/* the allocation clock (L0 bytes) and the clock of the last sample */
extern uint64_t census_clock, census_last_sample_clock;
/* the allocating instruction: its pc, its frame's function, the primitive
   under PRIM/PRIMPUSH (-1: none); UINT32_MAX before the loop runs */
extern uint32_t census_site, census_func;
extern int census_prim;
/* > 0 while the runtime allocates for itself (vm_raise_builtin) */
extern int census_runtime;
/* the object allocated last, whose fields are written at the next NEXT */
extern Obj *census_pending;
/* executions per code byte, or NULL when off */
extern uint64_t *census_pcs;
extern uint64_t census_next_id;
/* the number of the collection running or last run: the birth sample of
   the objects allocated now, kept in the id word above CENSUS_ID_BITS */
extern uint32_t census_sample_no;
#define CENSUS_ID_BITS 40
#define CENSUS_ID_MASK ((1ULL << CENSUS_ID_BITS) - 1)

/* summary: no trace files and no per-object arrays, every table of
   census.txt (docs/census.md); ids_hint presizes the per-object
   arrays of the full mode (0: grown by doubling) */
/* graph: also graph.bin, the pointee ids of every field at allocation
   (--census-graph; docs/census.md) */
void census_init(VM *vm, const char *dir, uint64_t every, int fields, int summary, uint64_t ids_hint, int graph);
void census_alloc(VM *vm, Obj *o, size_t size);
void census_flush(void);
void census_gc_begin(VM *vm);
void census_gc_end(VM *vm);
void census_survive(Obj *o, size_t size);
void census_collect_begin(void);   /* a pass of collect_into begins: its survivors counted afresh */
void census_store(Obj *o, uint32_t field, Value v, int site, int rep);
void census_prim_result(int prim, Value v);
void census_call(int op, Value v, int rep);
void census_exit(VM *vm);
void census_fork_child(void);
/* the frame depth fell (an exception unwound to a handler's frame): the
   lowest depth since the last sample, which samples.bin records; a return
   is seen by census_call's RET */
void census_unwind(VM *vm);
/* the static census of a loaded program (runtime/census/census_static.c): TSV on out */
void census_static(const Program *p, const char *path, FILE *out);

#define CENSUS_FLUSH() do { if (census_pending) census_flush(); } while (0)
#define CENSUS_NEXT(pc) do { if (census_pcs) census_pcs[(pc)]++; if (census_pending) census_flush(); } while (0)
#define CENSUS_SITE(at, f) (census_site = (at), census_func = (f), census_prim = -1)
#define CENSUS_PRIM(at, f, prim) (census_site = (at), census_func = (f), census_prim = (prim))
#define CENSUS_ALLOC(vm, o, size) do { (o)->id = ++census_next_id | ((uint64_t)census_sample_no << CENSUS_ID_BITS); if (census_on) census_alloc((vm), (o), (size)); } while (0)
#define CENSUS_FORCED() (census_every && census_clock - census_last_sample_clock >= census_every)
#define CENSUS_GC_BEGIN(vm) do { CENSUS_FLUSH(); if (census_on) census_gc_begin(vm); } while (0)
#define CENSUS_GC_END(vm) do { if (census_on) census_gc_end(vm); } while (0)
#define CENSUS_SURVIVE(o, size) do { if (census_on) census_survive((o), (size)); } while (0)
/* the representation of register reg of function f, 15 where the file says nothing */
#define CENSUS_REP(p, f, reg) ((p)->funcs[(f)].has_meta && (uint32_t)(reg) < (p)->funcs[(f)].nlocals ? (p)->funcs[(f)].reps[(reg)] : 15)
#define CENSUS_STORE(o, i, v, site, rep) do { if (census_on) census_store((o), (uint32_t)(i), (v), (site), (rep)); } while (0)
#define CENSUS_PRIM_RESULT(prim, v) do { if (census_on) census_prim_result((prim), (v)); } while (0)
#define CENSUS_CALL(op, v, rep) do { if (census_on) census_call((op), (v), (rep)); } while (0)
#define CENSUS_EXIT(vm) do { if (census_on) census_exit(vm); } while (0)
#define CENSUS_RUNTIME_BEGIN() (census_runtime++)
#define CENSUS_RUNTIME_END() (census_runtime--)
#define CENSUS_FORK_CHILD() census_fork_child()
#define CENSUS_UNWIND(vm) do { if (census_on) census_unwind(vm); } while (0)

#else

#define CENSUS_FLUSH() ((void)0)
#define CENSUS_NEXT(pc) ((void)0)
#define CENSUS_SITE(at, f) ((void)0)
#define CENSUS_PRIM(at, f, prim) ((void)0)
#define CENSUS_ALLOC(vm, o, size) ((void)0)
#define CENSUS_FORCED() 0
#define CENSUS_GC_BEGIN(vm) ((void)0)
#define CENSUS_GC_END(vm) ((void)0)
#define CENSUS_SURVIVE(o, size) ((void)0)
#define CENSUS_REP(p, f, reg) 15
#define CENSUS_STORE(o, i, v, site, rep) ((void)0)
#define CENSUS_PRIM_RESULT(prim, v) ((void)0)
#define CENSUS_CALL(op, v, rep) ((void)0)
#define CENSUS_EXIT(vm) ((void)0)
#define CENSUS_RUNTIME_BEGIN() ((void)0)
#define CENSUS_RUNTIME_END() ((void)0)
#define CENSUS_FORK_CHILD() ((void)0)
#define CENSUS_UNWIND(vm) ((void)0)

#endif
#endif
