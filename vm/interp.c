/* The interpreter loop, stacks, calls and exceptions. */
#include "vm.h"
#include <stdarg.h>

void vm_fatal(VM *vm, const char *fmt, ...) {
    va_list ap;
    fflush(stdout);
    fprintf(stderr, "runevm: fatal error at pc %u", vm->pc);
    if (vm->frames_active && vm->fp < vm->frames_cap)
        fprintf(stderr, " in %s", vm->prog.funcs[vm->frames[vm->fp].func].name);
    fprintf(stderr, ": ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
    exit(2);
}

void vm_grow_stack(VM *vm, size_t need) {
    size_t ncap = vm->stack_cap ? vm->stack_cap : 1024;
    while (ncap < need) ncap *= 2;
    if (ncap == vm->stack_cap) return;
    Value *ns = realloc(vm->stack, ncap * sizeof(Value));
    if (!ns) { fprintf(stderr, "runevm: out of memory (stack)\n"); exit(2); }
    vm->stack = ns;
    vm->stack_cap = ncap;
}

Value vm_pop(VM *vm) {
    if (vm->sp == 0) vm_fatal(vm, "stack underflow");
    return vm->stack[--vm->sp];
}

Value *vm_top(VM *vm, size_t depth) {
    if (vm->sp <= depth) vm_fatal(vm, "stack underflow");
    return &vm->stack[vm->sp - 1 - depth];
}

static void push_frame(VM *vm, uint32_t func, Obj *closure, uint32_t ret_pc, size_t base) {
    size_t idx = vm->frames_active ? vm->fp + 1 : 0;
    if (idx >= vm->frames_cap) {
        size_t ncap = vm->frames_cap ? vm->frames_cap * 2 : 256;
        Frame *nf = realloc(vm->frames, ncap * sizeof(Frame));
        if (!nf) { fprintf(stderr, "runevm: out of memory (frames)\n"); exit(2); }
        vm->frames = nf;
        vm->frames_cap = ncap;
    }
    vm->frames[idx].func = func;
    vm->frames[idx].closure = closure;
    vm->frames[idx].ret_pc = ret_pc;
    vm->frames[idx].base = base;
    vm->fp = idx;
    vm->frames_active = 1;
}

static void push_handler(VM *vm, uint32_t pc) {
    if (vm->hp >= vm->handlers_cap) {
        size_t ncap = vm->handlers_cap ? vm->handlers_cap * 2 : 64;
        Handler *nh = realloc(vm->handlers, ncap * sizeof(Handler));
        if (!nh) { fprintf(stderr, "runevm: out of memory (handlers)\n"); exit(2); }
        vm->handlers = nh;
        vm->handlers_cap = ncap;
    }
    vm->handlers[vm->hp].pc = pc;
    vm->handlers[vm->hp].sp = vm->sp;
    vm->handlers[vm->hp].fp = vm->fp;
    vm->hp++;
}

void vm_cons(VM *vm) {
    Obj *cell = vm_alloc_fields(vm, K_TUPLE, 0, 2);
    OBJ_FIELDS(cell)[0] = vm->stack[vm->sp - 1];
    OBJ_FIELDS(cell)[1] = vm->stack[vm->sp - 2];
    vm->sp -= 2;
    vm_push(vm, mk_ptr(cell));
    Obj *con = vm_alloc_fields(vm, K_CON, 1, 1);
    OBJ_FIELDS(con)[0] = vm->stack[vm->sp - 1];
    vm->stack[vm->sp - 1] = mk_ptr(con);
}

/* --- structural equality --- */
int values_equal(Value a, Value b) {
    for (;;) {
        if (a.tag != b.tag) return 0;
        switch (a.tag) {
        case T_UNIT: return 1;
        case T_INT: case T_CHAR: case T_CON0: return a.u.i == b.u.i;
        case T_WORD: return a.u.w == b.u.w;
        case T_REAL: return a.u.d == b.u.d;
        case T_PTR: {
            Obj *x = a.u.p, *y = b.u.p;
            if (x == y) return 1;
            if (x->kind != y->kind) return 0;
            switch (x->kind) {
            case K_STRING:
                return x->len == y->len && memcmp(OBJ_BYTES(x), OBJ_BYTES(y), x->len) == 0;
            case K_REF: case K_ARRAY: case K_CLOSURE: case K_EXNCON:
                return 0;
            case K_CON:
                if (x->contag != y->contag) return 0;
                /* fall through */
            case K_TUPLE: case K_EXN: {
                if (x->len != y->len) return 0;
                if (x->len == 0) return 1;
                Value *fx = OBJ_FIELDS(x), *fy = OBJ_FIELDS(y);
                for (uint32_t i = 0; i + 1 < x->len; i++)
                    if (!values_equal(fx[i], fy[i])) return 0;
                a = fx[x->len - 1];
                b = fy[x->len - 1];
                continue;
            }
            default: return 0;
            }
        }
        default: return 0;
        }
    }
}

/* --- exceptions --- */
static void print_exn_payload(FILE *out, Value v) {
    switch (v.tag) {
    case T_UNIT: break;
    case T_INT: fprintf(out, " %lld", (long long)v.u.i); break;
    case T_WORD: fprintf(out, " 0wx%llX", (unsigned long long)v.u.w); break;
    case T_REAL: fprintf(out, " %g", v.u.d); break;
    case T_CHAR: fprintf(out, " #\"%c\"", (int)v.u.i); break;
    case T_PTR:
        if (v.u.p->kind == K_STRING) fprintf(out, " \"%.*s\"", (int)v.u.p->len, OBJ_BYTES(v.u.p));
        else fprintf(out, " <value>");
        break;
    default: fprintf(out, " <value>");
    }
}

int vm_raise(VM *vm, Value exn) {
    if (vm->hp == 0) {
        fflush(stdout);
        fprintf(stderr, "runevm: uncaught exception ");
        if (exn.tag == T_PTR && exn.u.p->kind == K_EXN) {
            Value con = OBJ_FIELDS(exn.u.p)[0];
            if (con.tag == T_PTR && con.u.p->kind == K_EXNCON) {
                Value name = OBJ_FIELDS(con.u.p)[0];
                if (name.tag == T_PTR && name.u.p->kind == K_STRING)
                    fprintf(stderr, "%.*s", (int)name.u.p->len, OBJ_BYTES(name.u.p));
            }
            print_exn_payload(stderr, OBJ_FIELDS(exn.u.p)[1]);
        } else {
            fprintf(stderr, "<invalid exception value>");
        }
        fprintf(stderr, "\n");
        vm_exit(vm, 1);
    }
    Handler h = vm->handlers[--vm->hp];
    vm->fp = h.fp;
    vm->sp = h.sp;
    vm_push(vm, exn);
    vm->pc = h.pc;
    return 1;
}

int vm_raise_builtin(VM *vm, int k) {
    Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);
    OBJ_FIELDS(e)[0] = mk_ptr(vm->builtin_exns[k]);
    OBJ_FIELDS(e)[1] = mk_unit();
    return vm_raise(vm, mk_ptr(e));
}

/* --- checks --- */
static Obj *expect_obj(VM *vm, Value v, int kind, const char *what) {
    if (v.tag != T_PTR || v.u.p->kind != kind) vm_fatal(vm, "expected %s", what);
    return v.u.p;
}

/* --- main loop --- */
int vm_run(VM *vm) {
    Program *p = &vm->prog;
    const uint8_t *code = p->code;

    /* builtin exception constructors */
    static const char *const builtin_names[NUM_BUILTIN_EXNS] =
        { "Match", "Bind", "Overflow", "Div", "Subscript", "Size", "Chr", "Domain" };
    for (int i = 0; i < NUM_BUILTIN_EXNS; i++) {
        Obj *name = vm_string_from(vm, builtin_names[i], (uint32_t)strlen(builtin_names[i]));
        vm_push(vm, mk_ptr(name));
        Obj *con = vm_alloc_fields(vm, K_EXNCON, 0, 1);
        OBJ_FIELDS(con)[0] = vm_pop(vm);
        vm->builtin_exns[i] = con;
    }

    /* toplevel frame: function 0 applied to unit */
    vm->sp = 0;
    vm_push(vm, mk_unit());
    for (uint32_t i = 1; i < p->funcs[0].nlocals; i++) vm_push(vm, mk_unit());
    push_frame(vm, 0, NULL, 0, 0);
    vm->pc = p->funcs[0].code_offset;

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
                push_frame(vm, (uint32_t)fidx, c, vm->pc, base);
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
        case OP_JUMPIF: {
            Value v = vm_pop(vm);
            if (v.tag != T_CON0) vm_fatal(vm, "JUMPIF on non-bool");
            if (v.u.i != 0) vm->pc = (uint32_t)a;
            break;
        }
        case OP_PUSHHANDLER:
            push_handler(vm, (uint32_t)a);
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
            prim_table[a](vm);
            break;
        default:
            vm_fatal(vm, "invalid opcode %u", op);
        }
    }
}
