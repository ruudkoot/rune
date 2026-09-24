/* The runtime: what a VM does besides dispatching instructions. The frames
   and handlers, raising, the trace of a failure, structural equality, how a
   program begins and how a run ends. runevm is interp.c and main.c on top
   of it, heap.c, loader.c, prims.c, image.c and a system layer, and so is a
   program that runeopt made (docs/plans/codegen.md). */
#include "vm.h"
#include <stdarg.h>

/* Where a frame is stopped: the instruction being executed in the innermost
   one, and the call it is waiting on in every other. A pc points past the
   instruction it is in, so one byte back is inside it, and an entry of the
   line table never begins in the middle of an instruction. */
static uint32_t frame_pc(const VM *vm, size_t i) {
    uint32_t pc = (i == vm->fp) ? vm->pc : vm->frames[i + 1].ret_pc;
    return pc > 0 ? pc - 1 : 0;
}

/* The frames, innermost first, under a message that has already been
   printed. A frame whose position the program does not carry -- there is
   none for a file compiled before M5, and none for the outermost frame of a
   resumed image -- is named without one. */
void vm_print_trace(VM *vm, FILE *out) {
    if (!vm->frames_active) return;
    for (size_t k = vm->fp + 1; k > 0; k--) {
        size_t i = k - 1;
        uint32_t f = vm->frames[i].func;
        const char *name = f < vm->prog.nfuncs ? vm->prog.funcs[f].name : "?";
        const LineEntry *e = line_at(&vm->prog, frame_pc(vm, i));
        if (e && e->file < vm->prog.nfiles)
            fprintf(out, "  in %s at %s:%u:%u\n", name, vm->prog.files[e->file], e->line, e->col);
        else
            fprintf(out, "  in %s\n", name);
    }
}

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
    vm_print_trace(vm, stderr);
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

void vm_grow_frames(VM *vm) {
    size_t ncap = vm->frames_cap ? vm->frames_cap * 2 : 256;
    Frame *nf = realloc(vm->frames, ncap * sizeof(Frame));
    if (!nf) { fprintf(stderr, "runevm: out of memory (frames)\n"); exit(2); }
    vm->frames = nf;
    vm->frames_cap = ncap;
}

void vm_push_handler(VM *vm, uint32_t pc) {
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
        vm_print_trace(vm, stderr);
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

/* A program begins: the builtin exception constructors, then a frame for
   function 0 applied to unit, at its first instruction. What vm_run does
   before its loop, and what a program runeopt made does before its code. */
void vm_start(VM *vm) {
    Program *p = &vm->prog;

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
    vm_push_frame(vm, 0, NULL, 0, 0);
    vm->pc = p->funcs[0].code_offset;
}

/* A VM about to load a program: the three standard files, and a heap whose
   semispace is `heap` bytes. */
void vm_init(VM *vm, size_t heap) {
    vm->files_cap = 8;
    vm->files = calloc(vm->files_cap, sizeof(FILE *));
    vm->file_modes = calloc(vm->files_cap, 1);
    vm->file_paths = calloc(vm->files_cap, sizeof(char *));
    vm->files[0] = stdin; vm->files[1] = stdout; vm->files[2] = stderr;
    vm->file_modes[1] = vm->file_modes[2] = 1;
    vm->nfiles = 3;
    heap_init(vm, heap);
}

/* Also for a VM that an image was read into only in part (vm_resume). */
void vm_release(VM *vm) {
    for (uint32_t i = 0; vm->prog.funcs && i < vm->prog.nfuncs; i++) free(vm->prog.funcs[i].name);
    free(vm->prog.funcs);
    free(vm->prog.consts);
    free(vm->prog.code);
    for (uint32_t i = 0; vm->prog.files && i < vm->prog.nfiles; i++) free(vm->prog.files[i]);
    free(vm->prog.files);
    free(vm->prog.lines);
    free(vm->globals);
    free(vm->global_set);
    free(vm->stack);
    free(vm->frames);
    free(vm->handlers);
    free(vm->heap_from);
    for (size_t i = 3; i < vm->nfiles; i++) if (vm->files[i]) fclose(vm->files[i]);
    for (size_t i = 0; vm->file_paths && i < vm->nfiles; i++) free(vm->file_paths[i]);
    free(vm->files);
    free(vm->file_modes);
    free(vm->file_paths);
    if (vm->owns_args) {
        for (int i = 0; vm->argv && i < vm->argc; i++) free(vm->argv[i]);
        free(vm->argv);
        free((char *)vm->progname);
    }
}

void vm_destroy(VM *vm) {
    vm_release(vm);
    free(vm);
}

void vm_exit(VM *vm, int status) {
    fflush(stdout);
    if (vm->count)
        fprintf(stderr, "runevm: count: %llu instructions, %llu bytes, %llu objects\n",
                (unsigned long long)vm->instructions, (unsigned long long)vm->bytes_allocated,
                (unsigned long long)vm->objects_allocated);
    if (vm->stats)
        fprintf(stderr, "runevm: %zu collections, %llu bytes allocated, semispace %zu bytes, %zu live\n",
                vm->gc_count, (unsigned long long)vm->bytes_allocated, vm->heap_size, vm->heap_used);
    fflush(stderr);
    vm_destroy(vm);
    exit(status);
}
