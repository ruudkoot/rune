/* What is live where in a function of the register bytecode: one analysis,
   for tier 2's homes (jit/compile.c writes back what is live at a safepoint)
   and for the collector's roots (runtime/heap.c: a register that is dead
   where its frame waits for a call is no root). It reads the code and the
   instruction set's tables and nothing else, so every VM of the register
   bytecode has it, with or without a JIT. Registers past the 64th are not
   in an answer: who asks takes them for live. */
#include "live.h"
#include "regvm.h"

#include <stdlib.h>

/* The registers an instruction reads and the one it writes, as the tables
   say; a primitive's arguments as many as its arity. */
void reg_uses_defs(const Program *p, uint32_t pc, uint64_t *uses, uint64_t *def) {
    const uint8_t *code = p->code;
    uint8_t op = code[pc];
    *uses = 0; *def = 0;
    int dest = rop_dest[op];
    for (int k = 0; k < rop_nfixed[op]; k++)
        if (rop_kinds[op][k] == RK_REGISTER) {
            int32_t r = read_i32(code + pc + 1 + 4 * k);
            if (r >= 0 && r < 64) { if (k == dest) *def |= (uint64_t)1 << r; else *uses |= (uint64_t)1 << r; }
        }
    if (rop_list_at[op] >= 0) {
        uint32_t n;
        if (rop_list_prim[op]) {
            int prim = read_i32(code + pc + 1 + 4 * rop_list_at[op]);
            n = prim >= 0 && prim < PRIM__COUNT ? prim_arity[prim] : 0;
        } else n = (uint32_t)read_i32(code + pc + 1 + 4 * rop_list_at[op]);
        const uint8_t *L = code + pc + 1 + 4 * rop_nfixed[op];
        for (uint32_t i = 0; i < n; i++) {
            int32_t r = read_i32(L + 4 * i);
            if (r >= 0 && r < 64) *uses |= (uint64_t)1 << r;
        }
    }
}


static uint32_t length_at(const uint8_t *code, uint32_t pc) {
    uint32_t l = rop_length(code + pc);   /* before the table of a SWITCH is passed over */
    if (code[pc] == ROP_SWITCH) l += 5 * (uint32_t)read_i32(code + pc + 5);
    return l;
}

/* live_in[at]: the registers live at the entry of the instruction at
   from + at, by the usual backward walk to a fixed point; one word more
   than the code has bytes, the caller's to free, NULL where there is no
   memory. START says where an instruction begins (a byte each, as tier 2's
   scan has it), or is NULL and the code is walked. An instruction that may
   raise has every handler of the function among its successors, since a
   raise anywhere in a handler's region lands there; HANDLERS, where it is
   not NULL, gets what the handlers need at their entries. */
uint64_t *reg_liveness(const Program *p, uint32_t from, uint32_t to, const uint8_t *start, uint64_t *handlers) {
    const uint8_t *code = p->code;
    uint32_t len = to - from;
    uint64_t *live = calloc((size_t)len + 1, sizeof *live);
    uint32_t *starts = malloc(((size_t)len + 1) * sizeof *starts);
    if (!live || !starts) { free(live); free(starts); return NULL; }
    uint32_t nstarts = 0;
    if (start) { for (uint32_t at = 0; at < len; at++) if (start[at]) starts[nstarts++] = at; }
    else for (uint32_t pc = from; pc < to; pc += length_at(code, pc)) starts[nstarts++] = pc - from;
    uint64_t handlers_live = 0;
    int changed = 1;
    while (changed) {
        changed = 0;
        /* the handlers' labels */
        handlers_live = 0;
        for (uint32_t pc = from; pc < to; pc += length_at(code, pc))
            if (code[pc] == ROP_PUSHHANDLER) {
                int32_t h = read_i32(code + pc + 1);
                if (h >= (int32_t)from && (uint32_t)h < to) handlers_live |= live[(uint32_t)h - from];
            }
        /* backwards over the instructions */
        for (uint32_t k = nstarts; k-- > 0; ) {
            uint32_t at = starts[k], pc = from + at;
            uint8_t op = code[pc];
            uint32_t l = rop_length(code + pc);
            uint64_t out = 0;
            int flow = rop_flow[op];
            /* the successors */
            if (flow == FLOW_NEXT || flow == FLOW_BRANCH || flow == FLOW_CALL) {
                uint32_t nx = pc + l;
                if (op == ROP_SWITCH) nx += 5 * (uint32_t)read_i32(code + pc + 5);
                if (nx < to) out |= live[nx - from];
            }
            for (int q = 0; q < rop_nfixed[op]; q++)
                if (rop_kinds[op][q] == RK_LABEL || rop_kinds[op][q] == RK_HANDLER_LABEL) {
                    int32_t t = read_i32(code + pc + 1 + 4 * q);
                    if (t >= (int32_t)from && (uint32_t)t < to) out |= live[(uint32_t)t - from];
                }
            if (op == ROP_SWITCH) {
                uint32_t n = (uint32_t)read_i32(code + pc + 5);
                for (uint32_t e = 0; e < n; e++) {
                    int32_t t = read_i32(code + pc + l + 5 * e + 1);
                    if (t >= (int32_t)from && (uint32_t)t < to) out |= live[(uint32_t)t - from];
                }
                uint32_t past = pc + l + 5 * n;
                if (past < to) out |= live[past - from];
            }
            uint64_t uses, def;
            reg_uses_defs(p, pc, &uses, &def);
            uint64_t in = uses | (out & ~def);
            /* a raise, in the instruction or in what it calls, happens
               before the instruction defines anything: what a handler
               needs is live at its entry */
            if (rop_raises[op] || flow == FLOW_CALL || flow == FLOW_TAILCALL) in |= handlers_live;
            if (in != live[at]) { live[at] = in; changed = 1; }
        }
    }
    free(starts);
    if (handlers) *handlers = handlers_live;
    return live;
}

/* The slot of a function's table of return points (Function.live_pc,
   live_at) for RET_PC: from a hash of it, the next until the slot holds it
   or is empty (LIVE_EMPTY). A table has a power of two of slots, at least
   twice its points, so the walk is short; it is 1.3 to 1.6 times faster
   than a binary search over them (docs/plans/garbage-collector-v2.md, D9,
   H8), at every waiting frame a collection asks about. */
#define LIVE_EMPTY UINT32_MAX
static uint32_t live_slot(const uint32_t *pcs, uint32_t mask, uint32_t ret_pc) {
    uint32_t h = ret_pc * 2654435761u;
    uint32_t i = (h ^ h >> 16) & mask;
    while (pcs[i] != ret_pc && pcs[i] != LIVE_EMPTY) i = (i + 1) & mask;
    return i;
}

/* The registers of FUNC that are live while a frame of it waits for the
   call that returns to RET_PC: what is live at the instruction the call
   returns to, and what any handler of the function needs, since the callee
   may raise into one. The function's return points and their answers are
   made the first time one of its frames is asked about (Function.live_pc,
   live_at, a table by RET_PC's hash) and go with the program. Every
   register where the answer is not known: a pc that is no return point of
   the function, no memory. */
uint64_t reg_frame_live(VM *vm, uint32_t func, uint32_t ret_pc) {
    Program *p = &vm->prog;
    if (func >= p->nfuncs) return ~(uint64_t)0;
    Function *fn = &p->funcs[func];
    if (!fn->live_made) {
        fn->live_made = 1;
        uint32_t from = fn->code_offset, to = fn->code_end, n = 0;
        for (uint32_t pc = from; pc < to; pc += length_at(p->code, pc))
            if (rop_flow[p->code[pc]] == FLOW_CALL) n++;
        uint64_t handlers = 0;
        uint64_t *live = n ? reg_liveness(p, from, to, NULL, &handlers) : NULL;
        uint32_t size = 2;
        while (size < 2 * n) size *= 2;
        uint32_t *pcs = n ? malloc(size * sizeof *pcs) : NULL;
        uint64_t *at = n ? malloc(size * sizeof *at) : NULL;
        if (live && pcs && at) {
            for (uint32_t i = 0; i < size; i++) pcs[i] = LIVE_EMPTY;
            for (uint32_t pc = from; pc < to; ) {
                uint32_t nx = pc + length_at(p->code, pc);
                if (rop_flow[p->code[pc]] == FLOW_CALL && nx < to) {
                    uint32_t i = live_slot(pcs, size - 1, nx);
                    pcs[i] = nx;
                    at[i] = live[nx - from] | handlers;
                }
                pc = nx;
            }
            fn->nlive = size; fn->live_pc = pcs; fn->live_at = at;
        } else { free(pcs); free(at); }
        free(live);
    }
    if (!fn->nlive) return ~(uint64_t)0;
    uint32_t i = live_slot(fn->live_pc, fn->nlive - 1, ret_pc);
    return fn->live_pc[i] == ret_pc ? fn->live_at[i] : ~(uint64_t)0;
}
