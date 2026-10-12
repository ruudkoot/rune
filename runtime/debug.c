/* The debugger's part of the VM (the REPL roadmap's D22 and M12; vm.h,
   Debugger): debug mode, the lines the debug loop of runtime/register
   watches, the breakpoints, the steps, and the stop -- a frame of <debug>
   pushed above the frame that stopped, which calls the REPL's hook. The
   primitives the REPL drives it with are in prims.c (rt_debug_*).

   A stop is at an instruction of the user's code: a frame above the one
   the REPL's handler is in (VM.raise_mark), so that the REPL, which runs
   in the same loop while debug mode is on, never stops itself; and never
   while the hook runs. A line is a key, (file + 1) << 20 | line, of the
   line table's entry for the instruction; the debug loop sees a new line
   where the key differs from the one it saw last in the same frame. */
#include "vm.h"

#include <stdlib.h>
#include <string.h>

Debugger *dbg_get(VM *vm) {
    if (vm->dbg) return vm->dbg;
    Debugger *d = calloc(1, sizeof *d);
    if (!d) return NULL;
    d->func = UINT32_MAX;
    vm->dbg = d;
    return d;
}

void dbg_free(VM *vm) {
    Debugger *d = vm->dbg;
    if (!d) return;
    for (uint32_t i = 0; i < d->nfuncs; i++) free(d->keys[i]);
    free(d->keys);
    free(d->frame_key);
    free(d->breaks);
    free(d);
    vm->dbg = NULL;
}

/* The debug loop looks at each instruction while something may stop it
   there, or debug mode has ended and it is to give the program back to
   the driver. */
void dbg_update(Debugger *d) {
    int armed = !d->in_hook && (d->nbreaks || d->step != DBG_GO || d->pending);
    d->check = armed || (!d->on && !d->in_hook);
}

void dbg_set_on(VM *vm, int on) {
    Debugger *d = vm->dbg;
    int was = d->on;
    d->on = on != 0;
    if (d->on) {
        /* every frame returns into the interpreter (as an image's do,
           runtime/register/interp.c, make_room), and compiled code leaves
           at its next poll; every register is a root (nothing dead points
           anywhere: the collector made what it found dead unit) */
        if (vm->frames_active)
            for (size_t i = 0; i <= vm->fp; i++) {
                vm->frames[i].native_ret = vm->ret_tramp;
                vm->frames[i].result = UINT32_MAX;   /* the loop's RET reads it from the code (vm.h, Frame) */
            }
        vm->interrupt |= 2;
        vm_poll_soon(vm);   /* compiled code's calls see it too (vm.h, M6) */
        if (!was) { d->frame_live = vm->frame_live; vm->frame_live = NULL; }
    } else {
        vm->interrupt &= ~2;
        if (was) vm->frame_live = d->frame_live;
        d->step = DBG_GO;
        d->step_fp = 0;
        d->pending = 0;
    }
    dbg_update(d);
}

int dbg_in_user(const VM *vm) {
    return vm->raise_mark && vm->raise_mark <= vm->hp && vm->frames_active
           && vm->fp > vm->handlers[vm->raise_mark - 1].fp;
}

int dbg_pause(VM *vm) {
    Debugger *d = vm->dbg;
    if (d->in_hook || !dbg_in_user(vm)) return 0;
    d->pending = 1;
    dbg_set_on(vm, 1);
    vm->interrupt = 2;   /* the user's taken */
    vm_poll_soon(vm);
    return 1;
}

static int frame_keys(Debugger *d, size_t fp) {
    if (fp < d->nframe_keys) return 1;
    size_t n = d->nframe_keys ? d->nframe_keys : 64;
    while (n <= fp) n *= 2;
    uint32_t *k = realloc(d->frame_key, n * sizeof *k);
    if (!k) return 0;
    for (size_t i = d->nframe_keys; i < n; i++) k[i] = DBG_NOKEY;
    d->frame_key = k;
    d->nframe_keys = n;
    return 1;
}

void dbg_new_frame(VM *vm) {
    Debugger *d = vm->dbg;
    if (frame_keys(d, vm->fp)) d->frame_key[vm->fp] = DBG_NOKEY;
}

static uint32_t key_of(const LineEntry *e) { return ((e->file + 1) << 20) | (e->line & 0xFFFFF); }

/* The keys of a function, made the first time one is asked for: 0 where
   an instruction has no line (the function's code has no entry of its
   own, as <debug>'s and <return>'s have not). */
uint32_t dbg_key_slow(VM *vm, uint32_t func, uint32_t pc) {
    Debugger *d = vm->dbg;
    const Program *p = &vm->prog;
    if (func >= p->nfuncs) return 0;
    if (func >= d->nfuncs) {
        uint32_t **k = realloc(d->keys, (size_t)p->nfuncs * sizeof *k);
        if (!k) return 0;
        for (uint32_t i = d->nfuncs; i < p->nfuncs; i++) k[i] = NULL;
        d->keys = k;
        d->nfuncs = p->nfuncs;
    }
    const Function *fn = &p->funcs[func];
    uint32_t from = fn->code_offset, to = fn->code_end, len = to - from;
    uint32_t *t = malloc((len ? len : 1) * sizeof *t);
    if (!t) return 0;
    for (uint32_t at = from; at < to; at++) {
        const LineEntry *e = line_at(p, at);
        t[at - from] = e && e->pc >= from && e->file < p->nfiles && e->line ? key_of(e) : 0;
    }
    d->keys[func] = t;
    return pc >= from && pc < to ? t[pc - from] : 0;
}

static int is_break(const Debugger *d, uint32_t key) {
    uint32_t lo = 0, hi = d->nbreaks;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2;
        if (d->breaks[mid] < key) lo = mid + 1;
        else if (d->breaks[mid] > key) hi = mid;
        else return 1;
    }
    return 0;
}

static int user_key(const Debugger *d, uint32_t key) { return (key >> 20) > d->user_files; }

/* The program stops at `at` (the instruction's start; for a raise, where
   it raised): <debug>'s frame above the frame on top, its registers the
   hook, the event, unit and the exception, and the VM at its first
   instruction. */
static int stop(VM *vm, Debugger *d, int event, uint32_t at, Value exn) {
    if (!d->has_hook || d->func == UINT32_MAX) return 0;
    const Function *fn = &vm->prog.funcs[d->func];
    size_t top = vm->sp;
    size_t need = top + fn->nlocals + fn->maxstack + 1;
    if (need > vm->stack_cap) vm_grow_stack(vm, need);
    d->stop_fp = vm->fp;
    d->stop_pc = at;
    /* the frames of the stop are the user's, above the REPL's handler as
       it is now: what the hook evaluates marks a handler of its own */
    d->stop_floor = vm->raise_mark && vm->raise_mark <= vm->hp ? vm->handlers[vm->raise_mark - 1].fp : 0;
    d->event = event;
    d->step = DBG_GO;
    d->step_fp = 0;
    d->pending = 0;
    d->resume = DBG_GO;
    d->in_hook = 1;
    dbg_update(d);
    Value hook = vm_handle_get(vm, d->hook);
    vm_push_frame(vm, d->func, NULL, at, top);
    Value *slot = vm->stack + top;
    slot[0] = hook;
    slot[1] = mk_int(event);
    for (uint32_t i = 2; i < fn->nlocals; i++) slot[i] = mk_unit();
    slot[3] = exn;
    vm->sp = top + fn->nlocals;
    vm->pc = fn->code_offset;
    return 1;
}

int dbg_event(VM *vm, uint32_t pc, uint32_t key) {
    Debugger *d = vm->dbg;
    size_t fp = vm->fp;
    if (!frame_keys(d, fp)) return 0;
    uint32_t old = d->frame_key[fp];
    d->frame_key[fp] = key;
    if (d->in_hook) return 0;
    if (!dbg_in_user(vm)) {
        /* the user's code has ended: so has its stepping */
        if (d->step != DBG_GO) { d->step = DBG_GO; d->step_fp = 0; dbg_update(d); }
        return 0;
    }
    if (d->pending) return stop(vm, d, DBG_PAUSE, pc, mk_unit());
    /* a step that has left its frame stops in the user's code it returned
       to; one that returned into the library's goes on from there, as if
       it had begun where it is now (a debugger's way with code it has no
       source of) */
    if (d->step != DBG_GO && fp < d->step_fp) {
        if (key && user_key(d, key)) return stop(vm, d, DBG_STEP, pc, mk_unit());
        d->step_fp = fp;
    }
    if (key == old || key == 0) return 0;
    if (d->nbreaks && is_break(d, key)) return stop(vm, d, DBG_BREAK, pc, mk_unit());
    if (user_key(d, key)) {
        if (d->step == DBG_STEP_IN) return stop(vm, d, DBG_STEP, pc, mk_unit());
        if (d->step == DBG_STEP_OVER && fp <= d->step_fp) return stop(vm, d, DBG_STEP, pc, mk_unit());
    }
    return 0;
}

int dbg_raise(VM *vm, Value exn) {
    Debugger *d = vm->dbg;
    if (!d->raise_mode || !d->running || d->in_hook || d->skip_raise || !dbg_in_user(vm)) return 0;
    int uncaught = vm->hp == vm->raise_mark;
    if (d->raise_mode == 2 && !uncaught) return 0;
    return stop(vm, d, uncaught ? DBG_UNCAUGHT : DBG_RAISE, vm->pc, exn);
}
