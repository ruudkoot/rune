/* The interpreter loop: an instruction at a time, from vm->pc. */
#include "vm.h"

/* --- checks --- */
static Obj *expect_obj(VM *vm, Value v, int kind, const char *what) {
    if (v.tag != T_PTR || v.u.p->kind != kind) vm_fatal(vm, "expected %s", what);
    return v.u.p;
}

/* --- main loop --- */
int vm_run(VM *vm) {
    vm_start(vm);
    return vm_loop(vm);
}

/* The loop alone: a VM resumed from an image (vm/image.c) enters it here,
   its built-in exceptions and frames being those of the image. */
int vm_loop(VM *vm) {
    Program *p = &vm->prog;
    const uint8_t *code = p->code;
    for (;;) {
        uint32_t pc = vm->pc;
        uint8_t op = code[pc];
        int32_t a = op_nargs[op] > 0 ? read_i32(code + pc + 1) : 0;
        int32_t b = op_nargs[op] > 1 ? read_i32(code + pc + 5) : 0;
        if (vm->trace) fprintf(stderr, "[%6u] %-12s %d %d  sp=%zu fp=%zu\n", pc, op_names[op], a, b, vm->sp, vm->fp);
        vm->instructions++;
        vm->pc = pc + instr_length(op);
        Frame *fr = &vm->frames[vm->fp];

        switch (op) {
        case OP_HALT:
            return 0;
        case OP_CONST:
            vm_push(vm, p->consts[a]);
            break;
        case OP_INT:
            vm_push(vm, mk_int(a));
            break;
        case OP_UNIT:
            vm_push(vm, mk_unit());
            break;
        case OP_CON0:
            vm_push(vm, mk_con0(a));
            break;
        case OP_LOCAL:
            vm_push(vm, vm->stack[fr->base + (size_t)a]);
            break;
        case OP_SETLOCAL:
            vm->stack[fr->base + (size_t)a] = vm_pop(vm);
            break;
        case OP_ENV: {
            Obj *c = fr->closure;
            if (!c || (uint32_t)a + 1 >= c->len) vm_fatal(vm, "environment slot %d out of range", a);
            vm_push(vm, OBJ_FIELDS(c)[a + 1]);
            break;
        }
        case OP_SELF:
            if (!fr->closure) vm_fatal(vm, "SELF outside a closure");
            vm_push(vm, mk_ptr(fr->closure));
            break;
        case OP_GLOBAL:
            if (!vm->global_set[a]) vm_fatal(vm, "global %d read before initialization", a);
            vm_push(vm, vm->globals[a]);
            break;
        case OP_SETGLOBAL:
            vm->globals[a] = vm_pop(vm);
            vm->global_set[a] = 1;
            break;
        case OP_POP:
            (void)vm_pop(vm);
            break;
        case OP_TUPLE: {
            if (a == 0) { vm_push(vm, mk_unit()); break; }
            if ((size_t)a > vm->sp) vm_fatal(vm, "stack underflow");
            Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, (uint32_t)a);
            Value *f = OBJ_FIELDS(t);
            for (int32_t i = 0; i < a; i++) f[i] = vm->stack[vm->sp - (size_t)a + (size_t)i];
            vm->sp -= (size_t)a;
            vm_push(vm, mk_ptr(t));
            break;
        }
        case OP_SELECT: {
            Value v = vm_pop(vm);
            Obj *t = expect_obj(vm, v, K_TUPLE, "tuple");
            if ((uint32_t)a >= t->len) vm_fatal(vm, "tuple index %d out of range", a);
            vm_push(vm, OBJ_FIELDS(t)[a]);
            break;
        }
        case OP_CON: {
            Obj *c = vm_alloc_fields(vm, K_CON, (uint16_t)a, 1);
            OBJ_FIELDS(c)[0] = *vm_top(vm, 0);
            *vm_top(vm, 0) = mk_ptr(c);
            break;
        }
        case OP_DECON: {
            Value v = vm_pop(vm);
            Obj *c = expect_obj(vm, v, K_CON, "constructor with argument");
            vm_push(vm, OBJ_FIELDS(c)[0]);
            break;
        }
        case OP_CONTAG: {
            Value v = vm_pop(vm);
            if (v.tag == T_CON0) vm_push(vm, mk_int(v.u.i));
            else if (v.tag == T_PTR && v.u.p->kind == K_CON) vm_push(vm, mk_int(v.u.p->contag));
            else vm_fatal(vm, "CONTAG on non-constructor");
            break;
        }
        case OP_CLOSURE: {
            if ((size_t)b > vm->sp) vm_fatal(vm, "stack underflow");
            Obj *c = vm_alloc_fields(vm, K_CLOSURE, 0, (uint32_t)b + 1);
            Value *f = OBJ_FIELDS(c);
            f[0] = mk_int(a);
            for (int32_t i = 0; i < b; i++) f[i + 1] = vm->stack[vm->sp - (size_t)b + (size_t)i];
            vm->sp -= (size_t)b;
            vm_push(vm, mk_ptr(c));
            break;
        }
        case OP_SETENV: {
            Value v = vm_pop(vm);
            Value cv = vm_pop(vm);
            Obj *c = expect_obj(vm, cv, K_CLOSURE, "closure");
            if ((uint32_t)a + 1 >= c->len) vm_fatal(vm, "environment slot %d out of range", a);
            OBJ_FIELDS(c)[a + 1] = v;
            break;
        }
        case OP_CALL:
        case OP_TAILCALL: {
            Value arg = vm_pop(vm);
            Value cv = vm_pop(vm);
            Obj *c = expect_obj(vm, cv, K_CLOSURE, "closure in call");
            int64_t fidx = OBJ_FIELDS(c)[0].u.i;
            if (fidx < 0 || (uint64_t)fidx >= p->nfuncs) vm_fatal(vm, "bad function index");
            Function *fn = &p->funcs[fidx];
            if (op == OP_TAILCALL) {
                vm->sp = fr->base;
                fr->func = (uint32_t)fidx;
                fr->closure = c;
            } else {
                size_t base = vm->sp;
                vm_push_frame(vm, (uint32_t)fidx, c, vm->pc, base);
            }
            /* local 0 is the argument; the other locals start as unit */
            if (vm->sp + fn->nlocals > vm->stack_cap) vm_grow_stack(vm, vm->sp + fn->nlocals);
            Value *slot = &vm->stack[vm->sp];
            slot[0] = arg;
            for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();
            vm->sp += fn->nlocals;
            vm->pc = fn->code_offset;
            break;
        }
        case OP_RET: {
            Value v = vm_pop(vm);
            vm->sp = fr->base;
            vm->pc = fr->ret_pc;
            if (vm->fp == 0) { vm_push(vm, v); return 0; }
            vm->fp--;
            vm_push(vm, v);
            break;
        }
        case OP_JUMP:
            vm->pc = (uint32_t)a;
            break;
        case OP_JUMPIFNOT: {
            Value v = vm_pop(vm);
            if (v.tag != T_CON0) vm_fatal(vm, "JUMPIFNOT on non-bool");
            if (v.u.i == 0) vm->pc = (uint32_t)a;
            break;
        }
        case OP_JUMPIFNOTTAG: {
            /* CONTAG; INT t; PRIM poly_eq; JUMPIFNOT o, the test of a match
               against a constructor, in one */
            Value v = vm_pop(vm);
            int64_t tag = 0;
            if (v.tag == T_CON0) tag = v.u.i;
            else if (v.tag == T_PTR && v.u.p->kind == K_CON) tag = v.u.p->contag;
            else vm_fatal(vm, "JUMPIFNOTTAG on non-constructor");
            if (tag != b) vm->pc = (uint32_t)a;
            break;
        }
        case OP_JUMPIF: {
            Value v = vm_pop(vm);
            if (v.tag != T_CON0) vm_fatal(vm, "JUMPIF on non-bool");
            if (v.u.i != 0) vm->pc = (uint32_t)a;
            break;
        }
        case OP_PUSHHANDLER:
            vm_push_handler(vm, (uint32_t)a);
            break;
        case OP_POPHANDLER:
            if (vm->hp == 0) vm_fatal(vm, "POPHANDLER with no handler");
            vm->hp--;
            break;
        case OP_RAISE: {
            Value v = vm_pop(vm);
            if (v.tag != T_PTR || v.u.p->kind != K_EXN) vm_fatal(vm, "RAISE of non-exception");
            vm_raise(vm, v);
            break;
        }
        case OP_NEWEXN: {
            Obj *c = vm_alloc_fields(vm, K_EXNCON, 0, 1);
            OBJ_FIELDS(c)[0] = p->consts[a];
            vm_push(vm, mk_ptr(c));
            break;
        }
        case OP_BUILTINEXN:
            vm_push(vm, mk_ptr(vm->builtin_exns[a]));
            break;
        case OP_MKEXN: {
            if (vm->sp < 2) vm_fatal(vm, "stack underflow");
            Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);
            Value con = vm->stack[vm->sp - 2];
            if (con.tag != T_PTR || con.u.p->kind != K_EXNCON) vm_fatal(vm, "MKEXN on non-constructor");
            OBJ_FIELDS(e)[0] = con;
            OBJ_FIELDS(e)[1] = vm->stack[vm->sp - 1];
            vm->sp -= 2;
            vm_push(vm, mk_ptr(e));
            break;
        }
        case OP_EXNCON: {
            Value v = vm_pop(vm);
            Obj *e = expect_obj(vm, v, K_EXN, "exception");
            vm_push(vm, OBJ_FIELDS(e)[0]);
            break;
        }
        case OP_EXNARG: {
            Value v = vm_pop(vm);
            Obj *e = expect_obj(vm, v, K_EXN, "exception");
            vm_push(vm, OBJ_FIELDS(e)[1]);
            break;
        }
        case OP_PRIM:
            if (vm->sp < prim_arity[a]) vm_fatal(vm, "stack underflow in primitive %s", prim_names[a]);
            /* A primitive that says PRIM_NEW_WORLD has put another program
               here (Runtime.restore), so the code this loop is reading from
               has been freed: take it again, and the pc with it. */
            if (prim_table[a](vm) == PRIM_NEW_WORLD) code = p->code;
            break;
        default:
            vm_fatal(vm, "invalid opcode %u", op);
        }
    }
}
