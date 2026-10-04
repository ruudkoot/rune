/* The runtime: what a VM does besides dispatching instructions. The frames
   and handlers, raising, the trace of a failure, structural equality, how a
   program begins and how a run ends. runevm-stack is interp.c and main.c on top
   of it, heap.c, loader.c, prims.c, image.c and a system layer, and so is a
   program that runeopt made (docs/native.md). */
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
   resumed image -- is named without one. Where the code a frame is stopped
   in was inlined from other functions, each is a frame of its own, at the
   place the next called it from (the line table, docs/bytecode.md). */
void vm_print_trace(VM *vm, FILE *out) {
    if (!vm->frames_active) return;
    const Program *p = &vm->prog;
    for (size_t k = vm->fp + 1; k > 0; k--) {
        size_t i = k - 1;
        uint32_t f = vm->frames[i].func;
        const char *name = f < p->nfuncs ? p->funcs[f].name : "?";
        const LineEntry *e = line_at(p, frame_pc(vm, i));
        if (e && e->file < p->nfiles) {
            TraceFrame fs[64];
            uint32_t n = trace_frames(p, e, name, fs, 64);
            for (uint32_t j = 0; j < n; j++)
                fprintf(out, "  in %s at %s:%u:%u\n", fs[j].name, p->files[fs[j].file], fs[j].line, fs[j].col);
        } else
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

/* A stack that would exceed --stack-size: a recursion without end, most
   likely, which is stopped here rather than at the machine's memory. A VM
   made without vm_init (one an image is read into) has the default. */
#define STACK_LIMIT_DEFAULT ((size_t)1 << 30)   /* 1 GiB: 67 million values, or 26 million frames */
static size_t stack_limit(const VM *vm) { return vm->stack_limit ? vm->stack_limit : STACK_LIMIT_DEFAULT; }
void vm_limit(VM *vm, const char *message) {
    fflush(stdout);
    fprintf(stderr, "runevm: %s\n", message);
    vm_print_trace(vm, stderr);
    exit(2);
}
static void stack_overflow(VM *vm) {
    fprintf(stderr, "runevm: stack overflow: the stack would exceed %zu bytes (--stack-size N raises the limit)\n", stack_limit(vm));
    exit(2);
}

void vm_grow_stack(VM *vm, size_t need) {
    size_t ncap = vm->stack_cap ? vm->stack_cap : 1024;
    while (ncap < need) ncap *= 2;
    if (ncap == vm->stack_cap) return;
    if (ncap > stack_limit(vm) / sizeof(Value)) stack_overflow(vm);
    Value *ns = realloc(vm->stack, ncap * sizeof(Value));
    if (!ns) { fprintf(stderr, "runevm: out of memory (stack)\n"); exit(2); }
    vm->stack = ns;
    vm->stack_cap = ncap;
}

void vm_grow_frames(VM *vm) {
    size_t ncap = vm->frames_cap ? vm->frames_cap * 2 : 256;
    if (ncap > stack_limit(vm) / sizeof(Frame)) stack_overflow(vm);
    Frame *nf = realloc(vm->frames, ncap * sizeof(Frame));
    if (!nf) { fprintf(stderr, "runevm: out of memory (frames)\n"); exit(2); }
    vm->frames = nf;
    vm->frames_cap = ncap;
}

void vm_push_handler(VM *vm, uint32_t pc) {
    if (vm->hp >= vm->handlers_cap) {
        size_t ncap = vm->handlers_cap ? vm->handlers_cap * 2 : 64;
        if (ncap > stack_limit(vm) / sizeof(Handler)) stack_overflow(vm);
        Handler *nh = realloc(vm->handlers, ncap * sizeof(Handler));
        if (!nh) { fprintf(stderr, "runevm: out of memory (handlers)\n"); exit(2); }
        vm->handlers = nh;
        vm->handlers_cap = ncap;
    }
    vm->handlers[vm->hp].pc = pc;
    vm->handlers[vm->hp].sp = vm->sp;
    vm->handlers[vm->hp].fp = vm->fp;
    vm->handlers[vm->hp].native = NULL;
    vm->hp++;
}

/* A list cell is one object, the constructor :: (tag 1) of the two fields
   of its argument, head and tail -- a constructor whose argument is a tuple
   is made of its fields (src/backend/rep.sml; middle-end M11). */
void vm_cons(VM *vm) {
    Obj *cell = vm_alloc_fields(vm, K_CON, 1, 2);
    obj_fill_field(cell, 0, vm->stack[vm->sp - 1]);
    obj_fill_field(cell, 1, vm->stack[vm->sp - 2]);
    vm->sp -= 2;
    vm_push(vm, mk_ptr(cell));
}

/* --- structural equality --- */
int values_equal(VM *vm, Value a, Value b) {
    typedef struct { Obj *x, *y; uint32_t next; } Pending;
    Pending local[32], *pending = local;
    size_t count = 0, capacity = 32, steps = 0;
    size_t limit = vm->equality_work ? vm->equality_work : 1000000;
    int equal = 0;
    for (;;) {
        if (steps == limit) {
            if (pending != local) free(pending);
            vm_limit(vm, "equality work limit exceeded");
        }
        steps++;
        if (val_tag(a) != val_tag(b)) break;
        switch (val_tag(a)) {
        case T_UNIT: goto matched;
        case T_INT: case T_CHAR: case T_CON0:
            if (val_imm(a) != val_imm(b)) goto done;
            goto matched;
        case T_WORD:
            if (val_word(a) != val_word(b)) goto done;
            goto matched;
        case T_REAL:
            if (val_real(a) != val_real(b)) goto done;
            goto matched;
        case T_PTR: {
            Obj *x = val_ptr(a), *y = val_ptr(b);
            if (x == y) goto matched;
            if (obj_kind(x) != obj_kind(y)) goto done;
            switch (obj_kind(x)) {
            case K_STRING:
                if (obj_len(x) != obj_len(y) || memcmp(obj_bytes(x), obj_bytes(y), obj_len(x)) != 0) goto done;
                goto matched;
            case K_REF: case K_ARRAY: case K_CLOSURE: case K_EXNCON:
                goto done;
            case K_CON:
                if (obj_contag(x) != obj_contag(y)) goto done;
                /* fall through */
            case K_TUPLE: case K_EXN:
                if (obj_len(x) != obj_len(y)) goto done;
                if (obj_len(x) == 0) goto matched;
                if (obj_len(x) > 1) {
                    if (count == 65536) {
                        if (pending != local) free(pending);
                        vm_limit(vm, "equality exceeds 65536 pending comparisons");
                    }
                    if (count == capacity) {
                        size_t cap = capacity * 2;
                        Pending *grown = malloc(cap * sizeof(Pending));
                        if (!grown) {
                            if (pending != local) free(pending);
                            vm_fatal(vm, "out of memory comparing values");
                        }
                        memcpy(grown, pending, count * sizeof(Pending));
                        if (pending != local) free(pending);
                        pending = grown;
                        capacity = cap;
                    }
                    pending[count++] = (Pending){ x, y, 1 };
                }
                a = obj_field(x, 0);
                b = obj_field(y, 0);
                continue;
            default: goto done;
            }
        }
        default: goto done;
        }
matched:
        if (count == 0) { equal = 1; break; }
        Pending *p = &pending[count - 1];
        a = obj_field(p->x, p->next);
        b = obj_field(p->y, p->next);
        p->next++;
        if (p->next == obj_len(p->x)) count--;
    }
done:
    if (pending != local) free(pending);
    return equal;
}

/* --- exceptions --- */
static void print_exn_payload(FILE *out, Value v) {
    switch (val_tag(v)) {
    case T_UNIT: break;
    case T_INT: fprintf(out, " %lld", (long long)val_imm(v)); break;
    case T_WORD: fprintf(out, " 0wx%llX", (unsigned long long)val_word(v)); break;
    case T_REAL: fprintf(out, " %g", val_real(v)); break;
    case T_CHAR: fprintf(out, " #\"%c\"", (int)val_imm(v)); break;
    case T_PTR:
        if (obj_kind(val_ptr(v)) == K_STRING) fprintf(out, " \"%.*s\"", (int)obj_len(val_ptr(v)), obj_bytes(val_ptr(v)));
        else fprintf(out, " <value>");
        break;
    default: fprintf(out, " <value>");
    }
}

int vm_raise(VM *vm, Value exn) {
    if (vm->hp == 0) {
        fflush(stdout);
        fprintf(stderr, "runevm: uncaught exception ");
        if (val_is(exn, T_PTR) && obj_kind(val_ptr(exn)) == K_EXN) {
            Value con = obj_field(val_ptr(exn), 0);
            if (val_is(con, T_PTR) && obj_kind(val_ptr(con)) == K_EXNCON) {
                Value name = obj_field(val_ptr(con), 0);
                if (val_is(name, T_PTR) && obj_kind(val_ptr(name)) == K_STRING)
                    fprintf(stderr, "%.*s", (int)obj_len(val_ptr(name)), obj_bytes(val_ptr(name)));
            }
            print_exn_payload(stderr, obj_field(val_ptr(exn), 1));
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
    CENSUS_RUNTIME_BEGIN();
    Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);
    obj_fill_field(e, 0, mk_ptr(vm->builtin_exns[k]));
    obj_fill_field(e, 1, mk_unit());
    CENSUS_RUNTIME_END();
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
        obj_fill_field(con, 0, vm_pop(vm));
        vm->builtin_exns[i] = con;
    }

    /* toplevel frame: function 0 applied to unit */
    vm->sp = 0;
    vm_push(vm, mk_unit());
    for (uint32_t i = 1; i < p->funcs[0].nlocals; i++) vm_push(vm, mk_unit());
    vm_push_frame(vm, 0, NULL, 0, 0);
    vm->pc = p->funcs[0].code_offset;
}

/* Set by a program runeopt made (runtime/native/native.c): whether the world of an image
   runs the program it carries, which Runtime.restore asks (vm_become). */
int (*vm_same_program)(const VM *world) = NULL;

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
    if (!vm->stack_limit) vm->stack_limit = STACK_LIMIT_DEFAULT;
    heap_init(vm, heap);
}

/* Also for a VM that an image was read into only in part (vm_resume). */
void vm_release(VM *vm) {
    program_free_meta(&vm->prog);
    for (uint32_t i = 0; vm->prog.funcs && i < vm->prog.nfuncs; i++) free(vm->prog.funcs[i].name);
    free(vm->prog.funcs);
    free(vm->prog.consts);
    free(vm->prog.code);
    for (uint32_t i = 0; vm->prog.files && i < vm->prog.nfiles; i++) free(vm->prog.files[i]);
    free(vm->prog.files);
    free(vm->prog.lines);
    for (uint32_t i = 0; vm->prog.inlines && i < vm->prog.ninlines; i++) free(vm->prog.inlines[i].name);
    free(vm->prog.inlines);
    free(vm->globals);
    free(vm->global_set);
    free(vm->stack);
    free(vm->frames);
    free(vm->handlers);
    free(vm->heap_from);
    free(vm->heap_to);
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
    CENSUS_EXIT(vm);
    if (vm->count)
        fprintf(stderr, "runevm: count: %llu instructions, %llu bytes, %llu objects\n",
                (unsigned long long)vm->instructions, (unsigned long long)vm->bytes_allocated,
                (unsigned long long)vm->objects_allocated);
    if (vm->stats)
        fprintf(stderr, "runevm: %zu collections, %llu bytes allocated, semispace %zu bytes, %zu live, "
                "copied %llu, max live %zu, gc %lld us\n",
                vm->gc_count, (unsigned long long)vm->bytes_allocated, vm->heap_size, vm->heap_used,
                (unsigned long long)vm->copied, vm->max_live, (long long)(vm->gc_user_us + vm->gc_sys_us));
    fflush(stderr);
    vm_destroy(vm);
    exit(status);
}
