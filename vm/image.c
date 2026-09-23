/* fork by a second VM, for a system that has no fork (Windows) and for
   `runevm --emulate-fork`. The parent writes its whole state, the image, to
   a VM it has started as `runevm --resume TOKEN` (vm/sys.h,
   sys_fork_start), and that VM carries on in the dispatch loop with fork
   returning 0, as a child the kernel had copied would. The two are the
   same runevm, so the state goes as it lies in memory, and the child moves
   the pointers to where its own heap is (heap_relocate).

   The image holds everything the collector knows as a root, the heap
   itself, the program (not read again from its file, which the program may
   have moved away from), the counters and flags, the arguments, the
   rounding mode, and each file of the core by its descriptor and mode. The
   system layer hands on the descriptors themselves before the image. */
#include "vm.h"
#include "sys.h"
#include <fenv.h>

#define IMAGE_MAGIC "runevm image 1"

typedef struct Stream {
    FILE *f;
    int ok;
} Stream;

/* --- writing --- */

static void put(Stream *s, const void *p, size_t n) {
    if (s->ok && n > 0 && fwrite(p, 1, n, s->f) != n) s->ok = 0;
}
#define PUT(s, x) put((s), &(x), sizeof(x))

static void put_string(Stream *s, const char *text) {
    uint64_t n = strlen(text);
    PUT(s, n);
    put(s, text, (size_t)n);
}

static void write_image(VM *vm, Stream *s) {
    const Program *p = &vm->prog;
    put(s, IMAGE_MAGIC, sizeof IMAGE_MAGIC);
    uint32_t sizes[4] = { sizeof(Value), sizeof(Obj), sizeof(Frame), sizeof(void *) };
    PUT(s, sizes);

    int flags[5] = { vm->trace, vm->stats, vm->count, vm->emulate_fork, fegetround() };
    PUT(s, flags);
    PUT(s, vm->gc_stress);
    PUT(s, vm->gc_count);
    PUT(s, vm->gc_user_us);
    PUT(s, vm->gc_sys_us);
    PUT(s, vm->bytes_allocated);
    PUT(s, vm->objects_allocated);
    PUT(s, vm->instructions);
    PUT(s, vm->pc);
    PUT(s, vm->io_errno);

    put_string(s, vm->progname);
    PUT(s, vm->argc);
    for (int i = 0; i < vm->argc; i++) put_string(s, vm->argv[i]);

    PUT(s, p->nconsts);
    put(s, p->consts, (size_t)p->nconsts * sizeof(Value));
    PUT(s, p->nglobals);
    PUT(s, p->nfuncs);
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        PUT(s, p->funcs[i].code_offset);
        PUT(s, p->funcs[i].code_end);
        PUT(s, p->funcs[i].nlocals);
        put_string(s, p->funcs[i].name);
    }
    PUT(s, p->code_len);
    put(s, p->code, p->code_len);
    PUT(s, p->nfiles);
    for (uint32_t i = 0; i < p->nfiles; i++) put_string(s, p->files[i]);
    PUT(s, p->nlines);
    put(s, p->lines, (size_t)p->nlines * sizeof(LineEntry));

    /* the heap, with the address it is at: the pointers in it and in the
       roots are relative to that */
    uintptr_t base = (uintptr_t)vm->heap_from;
    PUT(s, base);
    PUT(s, vm->heap_size);
    PUT(s, vm->heap_used);
    put(s, vm->heap_from, vm->heap_used);

    put(s, vm->globals, (size_t)p->nglobals * sizeof(Value));
    put(s, vm->global_set, p->nglobals);
    put(s, vm->builtin_exns, sizeof vm->builtin_exns);
    PUT(s, vm->sp);
    put(s, vm->stack, vm->sp * sizeof(Value));
    PUT(s, vm->frames_active);
    PUT(s, vm->fp);
    if (vm->frames_active) put(s, vm->frames, (vm->fp + 1) * sizeof(Frame));
    PUT(s, vm->hp);
    put(s, vm->handlers, vm->hp * sizeof(Handler));

    /* each file by its descriptor, -1 for a closed slot: handles are never
       used again, so the slots go too */
    PUT(s, vm->nfiles);
    for (size_t i = 0; i < vm->nfiles; i++) {
        int fd = vm->files[i] ? sys_fileno(vm->files[i]) : -1;
        PUT(s, fd);
        PUT(s, vm->file_modes[i]);
    }
    put(s, IMAGE_MAGIC, sizeof IMAGE_MAGIC);
}

/* Called by posix_fork before it pops its argument. What was written is
   flushed, so that the child does not write it again, and each input that
   can seek has its descriptor put where the program stopped reading, which
   the child reads on from. What a pipe has buffered cannot follow. A child
   that dies before it has read the image is still a child, whose status
   says so: the pid comes back all the same. */
int64_t vm_fork(VM *vm) {
    fflush(NULL);
    for (size_t i = 0; i < vm->nfiles; i++) {
        FILE *f = vm->files[i];
        if (f && vm->file_modes[i] == 0 && sys_ftell(f) >= 0) sys_fseek(f, 0, SEEK_CUR);
    }
    FILE *out = sys_fork_start();
    if (!out) return -1;
    Stream s = { out, 1 };
    write_image(vm, &s);
    return sys_fork_finish(out);
}

/* --- reading --- */

static void get(Stream *s, void *p, size_t n) {
    if (s->ok && n > 0 && fread(p, 1, n, s->f) != n) s->ok = 0;
}
#define GET(s, x) get((s), &(x), sizeof(x))

/* n bytes read into new memory; NULL (and the stream no longer ok) when
   there is no such memory */
static void *get_new(Stream *s, size_t n) {
    if (!s->ok) return NULL;
    void *p = malloc(n > 0 ? n : 1);
    if (!p) { s->ok = 0; return NULL; }
    get(s, p, n);
    return p;
}

static char *get_string(Stream *s) {
    uint64_t n = 0;
    GET(s, n);
    if (!s->ok || n >= SIZE_MAX) { s->ok = 0; return NULL; }
    char *text = malloc((size_t)n + 1);
    if (!text) { s->ok = 0; return NULL; }
    get(s, text, (size_t)n);
    text[n] = 0;
    return text;
}

/* a count of things of `size` bytes that fits in memory, or 0 */
static int fits(uint64_t count, size_t size) {
    return count < SIZE_MAX / size;
}

static int failed(Stream *s, char *err, size_t errlen, const char *msg) {
    if (s->f) fclose(s->f);
    snprintf(err, errlen, "%s", msg);
    return 0;
}

int vm_resume(VM *vm, const char *token, char *err, size_t errlen) {
    Stream s = { sys_resume(token), 1 };
    if (!s.f) return failed(&s, err, errlen, "no image to resume from");
    Program *p = &vm->prog;

    char magic[sizeof IMAGE_MAGIC];
    uint32_t sizes[4];
    get(&s, magic, sizeof magic);
    GET(&s, sizes);
    if (!s.ok || memcmp(magic, IMAGE_MAGIC, sizeof magic) != 0 || sizes[0] != sizeof(Value) ||
        sizes[1] != sizeof(Obj) || sizes[2] != sizeof(Frame) || sizes[3] != sizeof(void *))
        return failed(&s, err, errlen, "not an image of this runevm");

    int flags[5];
    GET(&s, flags);
    vm->trace = flags[0];
    vm->stats = flags[1];
    vm->count = flags[2];
    vm->emulate_fork = flags[3];
    fesetround(flags[4]);
    GET(&s, vm->gc_stress);
    GET(&s, vm->gc_count);
    GET(&s, vm->gc_user_us);
    GET(&s, vm->gc_sys_us);
    GET(&s, vm->bytes_allocated);
    GET(&s, vm->objects_allocated);
    GET(&s, vm->instructions);
    GET(&s, vm->pc);
    GET(&s, vm->io_errno);

    vm->owns_args = 1;
    vm->progname = get_string(&s);
    GET(&s, vm->argc);
    if (!s.ok || vm->argc < 0) return failed(&s, err, errlen, "the image is cut short");
    vm->argv = calloc((size_t)vm->argc + 1, sizeof(char *));
    if (!vm->argv) return failed(&s, err, errlen, "out of memory");
    for (int i = 0; i < vm->argc; i++) vm->argv[i] = get_string(&s);

    GET(&s, p->nconsts);
    if (s.ok && fits(p->nconsts, sizeof(Value))) p->consts = get_new(&s, (size_t)p->nconsts * sizeof(Value));
    GET(&s, p->nglobals);
    GET(&s, p->nfuncs);
    if (s.ok && fits(p->nfuncs, sizeof(Function))) p->funcs = calloc(p->nfuncs > 0 ? p->nfuncs : 1, sizeof(Function));
    if (!s.ok || !p->consts || !p->funcs) return failed(&s, err, errlen, "the image is cut short");
    for (uint32_t i = 0; i < p->nfuncs && s.ok; i++) {
        GET(&s, p->funcs[i].code_offset);
        GET(&s, p->funcs[i].code_end);
        GET(&s, p->funcs[i].nlocals);
        p->funcs[i].name = get_string(&s);
    }
    GET(&s, p->code_len);
    p->code = get_new(&s, p->code_len);
    GET(&s, p->nfiles);
    if (s.ok && fits(p->nfiles, sizeof(char *))) p->files = calloc(p->nfiles > 0 ? p->nfiles : 1, sizeof(char *));
    if (!s.ok || !p->files) return failed(&s, err, errlen, "the image is cut short");
    for (uint32_t i = 0; i < p->nfiles && s.ok; i++) p->files[i] = get_string(&s);
    GET(&s, p->nlines);
    if (!s.ok || !fits(p->nlines, sizeof(LineEntry))) return failed(&s, err, errlen, "the image is cut short");
    p->lines = get_new(&s, (size_t)p->nlines * sizeof(LineEntry));

    uintptr_t base = 0;
    GET(&s, base);
    GET(&s, vm->heap_size);
    GET(&s, vm->heap_used);
    if (!s.ok || vm->heap_used > vm->heap_size) return failed(&s, err, errlen, "the image is cut short");
    vm->heap_from = malloc(vm->heap_size);
    if (!vm->heap_from) return failed(&s, err, errlen, "cannot allocate heap");
    get(&s, vm->heap_from, vm->heap_used);

    if (s.ok && fits(p->nglobals, sizeof(Value))) {
        vm->globals = get_new(&s, (size_t)p->nglobals * sizeof(Value));
        vm->global_set = get_new(&s, p->nglobals);
    }
    get(&s, vm->builtin_exns, sizeof vm->builtin_exns);
    size_t sp = 0;
    GET(&s, sp);
    if (!s.ok || !fits(sp, sizeof(Value))) return failed(&s, err, errlen, "the image is cut short");
    vm_grow_stack(vm, sp + 1);
    vm->sp = sp;
    get(&s, vm->stack, sp * sizeof(Value));
    GET(&s, vm->frames_active);
    GET(&s, vm->fp);
    if (vm->frames_active) {
        if (!s.ok || !fits(vm->fp + 1, sizeof(Frame))) return failed(&s, err, errlen, "the image is cut short");
        vm->frames_cap = vm->fp + 1 < 256 ? 256 : vm->fp + 1;
        vm->frames = malloc(vm->frames_cap * sizeof(Frame));
        if (!vm->frames) return failed(&s, err, errlen, "out of memory");
        get(&s, vm->frames, (vm->fp + 1) * sizeof(Frame));
    }
    GET(&s, vm->hp);
    if (!s.ok || !fits(vm->hp, sizeof(Handler))) return failed(&s, err, errlen, "the image is cut short");
    vm->handlers_cap = vm->hp < 64 ? 64 : vm->hp;
    vm->handlers = malloc(vm->handlers_cap * sizeof(Handler));
    if (!vm->handlers) return failed(&s, err, errlen, "out of memory");
    get(&s, vm->handlers, vm->hp * sizeof(Handler));

    size_t nfiles = 0;
    GET(&s, nfiles);
    if (!s.ok || nfiles < 3 || !fits(nfiles, sizeof(FILE *))) return failed(&s, err, errlen, "the image is cut short");
    vm->files_cap = nfiles < 8 ? 8 : nfiles;
    vm->files = calloc(vm->files_cap, sizeof(FILE *));
    vm->file_modes = calloc(vm->files_cap, 1);
    if (!vm->files || !vm->file_modes) return failed(&s, err, errlen, "out of memory");
    vm->nfiles = nfiles;
    vm->files[0] = stdin;
    vm->files[1] = stdout;
    vm->files[2] = stderr;
    for (size_t i = 0; i < nfiles && s.ok; i++) {
        int fd = -1;
        GET(&s, fd);
        GET(&s, vm->file_modes[i]);
        if (i >= 3 && fd >= 0 && s.ok) {
            uint8_t mode = vm->file_modes[i];
            vm->files[i] = sys_fdopen(fd, mode == 0 ? "rb" : mode == 1 ? "wb" : "ab");
        }
    }
    get(&s, magic, sizeof magic);
    if (!s.ok || memcmp(magic, IMAGE_MAGIC, sizeof magic) != 0 || !p->code || !vm->globals || !vm->global_set)
        return failed(&s, err, errlen, "the image is cut short");
    fclose(s.f);
    if (!heap_relocate(vm, base)) {
        snprintf(err, errlen, "the heap of the image is not sound");
        return 0;
    }
    /* the image was written inside posix_fork, its argument still on the
       stack: fork gives 0 here */
    if (vm->sp == 0) { snprintf(err, errlen, "the image was not made by fork"); return 0; }
    vm->sp--;
    vm_push(vm, mk_int(0));
    return 1;
}
