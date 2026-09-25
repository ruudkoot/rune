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
   system layer hands on the descriptors themselves before the image.

   Nothing is written as it lies in memory. Writing a field at a time looks
   like the slower way and is not: a `Value` occupies 16 bytes in memory -- a
   tag, padding, then eight bytes of payload -- and goes into an image as
   nine, so a heap of list cells is carried in about two thirds of the bytes,
   and the pipe saves more than the encoding costs. Measured over 40 forks at
   64 MB live, three runs each: writing the structs took 224, 222 and 296 ms
   a fork, and this takes 200, 205 and 210. That only holds because the
   encoder writes into the stream's own buffer; a first version called stdio
   once a field and was 44% slower for each MB of live heap.

   A fork this way costs about 30 ms and 3 to 4 ms for each MB of live heap,
   most of the fixed part being the start of a process. The child checks the
   program it is given as the loader checks a .rbc, which costs about 3 us for
   each KB of code -- 14 us for a small program, 1.5 ms for bin/rune.rbc, the
   largest in the tree -- and is not worth a way to turn off (docs/building.md).

   Every number is little-endian and
   as many bytes wide as the format says, never as many as the machine has,
   and a pointer into the heap is written as its distance from the start of
   the heap. So an image written by one VM is read by another of a different
   width: `bin/runevm` writes one and `bin/runevm32.exe` resumes it. What a
   `Value` and an `Obj` are is the same on every VM already (docs/runtime.md),
   so the heap is rebuilt object by object at the same offsets, and the
   distances stay true; heap_relocate then turns each of them into a pointer
   and refuses an image whose heap is not sound. */
#include "vm.h"
#include "sys.h"
#include <fenv.h>
#include <errno.h>

/* The format of an image, and the instruction set of the program in it
   (src/isa): a VM refuses the image of another. Each VM's instruction set
   says it (vm/isa_stack.c, vm/new/isa_regs.c). */
#define IMAGE_MAGIC isa_image_magic

/* What a world that starts again from an image should do: a fork gives 0 to
   the child, a save gives `Restored` to the program that wrote it. */
#define IMAGE_FORK 0
#define IMAGE_SAVE 1

/* A buffer either way: the heap is written and read a field at a time, and a
   call to stdio for each of them would cost more than the encoding does. */
typedef struct Stream {
    FILE *f;
    int ok;
    size_t n, pos;              /* bytes in buf; where reading has got to */
    uint8_t buf[1 << 16];
} Stream;

/* --- writing --- */

static void wflush(Stream *s) {
    if (s->ok && s->n > 0 && fwrite(s->buf, 1, s->n, s->f) != s->n) s->ok = 0;
    s->n = 0;
}

static void put(Stream *s, const void *p, size_t n) {
    if (!s->ok || n == 0) return;
    if (n > sizeof s->buf - s->n) wflush(s);
    if (n > sizeof s->buf) {
        if (s->ok && fwrite(p, 1, n, s->f) != n) s->ok = 0;
        return;
    }
    memcpy(s->buf + s->n, p, n);
    s->n += n;
}

/* Room for the widest thing written in one go, so that the heap -- which is
   nearly all of an image -- is encoded straight into the buffer. */
static uint8_t *room(Stream *s, size_t n) {
    if (!s->ok) return NULL;
    if (n > sizeof s->buf - s->n) wflush(s);
    if (!s->ok) return NULL;
    uint8_t *at = s->buf + s->n;
    s->n += n;
    return at;
}

static void put_u8(Stream *s, uint8_t v) {
    uint8_t *b = room(s, 1);
    if (b) b[0] = v;
}

static void put_u16(Stream *s, uint16_t v) {
    uint8_t *b = room(s, 2);
    if (b) { b[0] = (uint8_t)v; b[1] = (uint8_t)(v >> 8); }
}

static void put_u32(Stream *s, uint32_t v) {
    uint8_t *b = room(s, 4);
    if (b) for (int i = 0; i < 4; i++) b[i] = (uint8_t)(v >> (8 * i));
}

static void put_u64(Stream *s, uint64_t v) {
    uint8_t *b = room(s, 8);
    if (b) for (int i = 0; i < 8; i++) b[i] = (uint8_t)(v >> (8 * i));
}

/* the distance of a heap object from the start of the heap; NONE for none */
#define OFF_NONE UINT64_MAX

static void put_obj(Stream *s, const Obj *o, const VM *vm) {
    put_u64(s, o ? (uint64_t)((const char *)o - vm->heap_from) : OFF_NONE);
}

static void put_value(Stream *s, Value v, const VM *vm) {
    uint64_t w = v.tag == T_PTR
               ? (v.u.p ? (uint64_t)((const char *)v.u.p - vm->heap_from) : OFF_NONE)
               : v.u.w;
    uint8_t *b = room(s, 9);
    if (!b) return;
    b[0] = v.tag;
    for (int i = 0; i < 8; i++) b[i + 1] = (uint8_t)(w >> (8 * i));
}

static void put_string(Stream *s, const char *text) {
    uint64_t n = strlen(text);
    put_u64(s, n);
    put(s, text, (size_t)n);
}

/* The heap, object by object at the offsets it has: a header of its own
   width, then the fields, or the bytes of a string. */
static void put_heap(Stream *s, VM *vm) {
    size_t scan = 0;
    while (s->ok && scan < vm->heap_used) {
        Obj *o = (Obj *)(vm->heap_from + scan);
        put_u8(s, o->kind);
        put_u16(s, o->contag);
        put_u32(s, o->len);
        if (o->kind == K_STRING) {
            put(s, OBJ_BYTES(o), o->len);
        } else {
            Value *f = OBJ_FIELDS(o);
            for (uint32_t i = 0; i < o->len; i++) put_value(s, f[i], vm);
        }
        scan += obj_size(o);
    }
}

static void write_image(VM *vm, Stream *s, int kind) {
    const Program *p = &vm->prog;
    put(s, IMAGE_MAGIC, ISA_IMAGE_MAGIC_SIZE);
    /* what the world should do when it starts again (IMAGE_FORK, IMAGE_SAVE) */
    put_u32(s, (uint32_t)kind);

    put_u32(s, (uint32_t)vm->trace);
    put_u32(s, (uint32_t)vm->stats);
    put_u32(s, (uint32_t)vm->count);
    put_u32(s, (uint32_t)vm->emulate_fork);
    put_u32(s, (uint32_t)fegetround());
    put_u32(s, (uint32_t)vm->heap_fill);
    put_u64(s, (uint64_t)vm->gc_stress);
    put_u64(s, (uint64_t)vm->gc_count);
    put_u64(s, (uint64_t)vm->gc_user_us);
    put_u64(s, (uint64_t)vm->gc_sys_us);
    put_u64(s, vm->bytes_allocated);
    put_u64(s, vm->objects_allocated);
    put_u64(s, vm->instructions);
    put_u32(s, vm->pc);
    put_u32(s, (uint32_t)vm->io_errno);

    put_string(s, vm->progname);
    put_u32(s, (uint32_t)vm->argc);
    for (int i = 0; i < vm->argc; i++) put_string(s, vm->argv[i]);

    /* the heap first, so that what follows can be written as offsets into it */
    put_u64(s, (uint64_t)vm->heap_size);
    put_u64(s, (uint64_t)vm->heap_used);
    put_heap(s, vm);

    put_u32(s, p->nconsts);
    for (uint32_t i = 0; i < p->nconsts; i++) put_value(s, p->consts[i], vm);
    put_u32(s, p->nglobals);
    put_u32(s, p->nfuncs);
    for (uint32_t i = 0; i < p->nfuncs; i++) {
        put_u32(s, p->funcs[i].code_offset);
        put_u32(s, p->funcs[i].code_end);
        put_u32(s, p->funcs[i].nlocals);
        put_string(s, p->funcs[i].name);
    }
    put_u32(s, p->code_len);
    put(s, p->code, p->code_len);
    put_u32(s, p->nfiles);
    for (uint32_t i = 0; i < p->nfiles; i++) put_string(s, p->files[i]);
    put_u32(s, p->nlines);
    for (uint32_t i = 0; i < p->nlines; i++) {
        put_u32(s, p->lines[i].pc);
        put_u32(s, p->lines[i].file);
        put_u32(s, p->lines[i].line);
        put_u32(s, p->lines[i].col);
        put_u32(s, p->lines[i].inl);
    }
    put_u32(s, p->ninlines);
    for (uint32_t i = 0; i < p->ninlines; i++) {
        put_string(s, p->inlines[i].name);
        put_u32(s, p->inlines[i].file);
        put_u32(s, p->inlines[i].line);
        put_u32(s, p->inlines[i].col);
        put_u32(s, p->inlines[i].parent);
    }

    for (uint32_t i = 0; i < p->nglobals; i++) put_value(s, vm->globals[i], vm);
    put(s, vm->global_set, p->nglobals);
    for (int i = 0; i < NUM_BUILTIN_EXNS; i++) put_obj(s, vm->builtin_exns[i], vm);
    put_u64(s, (uint64_t)vm->sp);
    for (size_t i = 0; i < vm->sp; i++) put_value(s, vm->stack[i], vm);
    put_u32(s, (uint32_t)vm->frames_active);
    put_u64(s, (uint64_t)vm->fp);
    if (vm->frames_active)
        for (size_t i = 0; i <= vm->fp; i++) {
            put_u32(s, vm->frames[i].func);
            put_u32(s, vm->frames[i].ret_pc);
            put_u64(s, (uint64_t)vm->frames[i].base);
            put_obj(s, vm->frames[i].closure, vm);
        }
    put_u64(s, (uint64_t)vm->hp);
    for (size_t i = 0; i < vm->hp; i++) {
        put_u32(s, vm->handlers[i].pc);
        put_u64(s, (uint64_t)vm->handlers[i].sp);
        put_u64(s, (uint64_t)vm->handlers[i].fp);
    }

    /* Each file by its descriptor, -1 for a closed slot: handles are never
       used again, so the slots go too. A fork's child has the descriptors
       themselves, from the system layer; a saved image is read by a process
       that has none of them, so the path and the position go too and the
       file is opened again where it was left. */
    put_u64(s, (uint64_t)vm->nfiles);
    for (size_t i = 0; i < vm->nfiles; i++) {
        int fd = vm->files[i] ? sys_fileno(vm->files[i]) : -1;
        put_u32(s, (uint32_t)fd);
        put_u8(s, vm->file_modes[i]);
        if (kind == IMAGE_SAVE) {
            const char *path = i >= 3 && vm->files[i] && vm->file_paths[i] ? vm->file_paths[i] : "";
            int64_t at = i >= 3 && vm->files[i] ? sys_ftell(vm->files[i]) : -1;
            put_string(s, path);
            put_u64(s, (uint64_t)at);
        }
    }
    put(s, IMAGE_MAGIC, ISA_IMAGE_MAGIC_SIZE);
    wflush(s);
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
    Stream s = { out, 1, 0, 0, {0} };
    write_image(vm, &s, IMAGE_FORK);
    return sys_fork_finish(out);
}

/* Runtime.save: the whole VM in a file of its own, for a process that will
   read it later and carry on from here. Unlike a fork, nothing is inherited:
   what the system layer holds -- sockets, directory streams, a pipe -- is not
   in the image, and the files that are come back by their path. */
int vm_save(VM *vm, const char *path) {
    FILE *f = sys_fopen(path, "wb");
    if (!f) { vm->io_errno = errno; return 0; }
    fflush(NULL);
    Stream *s = malloc(sizeof(Stream));
    if (!s) { fclose(f); vm->io_errno = ENOMEM; return 0; }
    s->f = f;
    s->ok = 1;
    s->n = 0;
    s->pos = 0;
    write_image(vm, s, IMAGE_SAVE);
    int ok = s->ok;
    free(s);
    if (fclose(f) != 0) ok = 0;
    if (!ok) vm->io_errno = errno;
    return ok;
}

/* --- reading --- */

static void get(Stream *s, void *p, size_t n) {
    uint8_t *d = p;
    while (s->ok && n > 0) {
        if (s->pos >= s->n) {
            s->pos = 0;
            s->n = fread(s->buf, 1, sizeof s->buf, s->f);
            if (s->n == 0) { s->ok = 0; return; }
        }
        size_t take = s->n - s->pos;
        if (take > n) take = n;
        memcpy(d, s->buf + s->pos, take);
        s->pos += take;
        d += take;
        n -= take;
    }
}

/* The next n bytes where they are already in the buffer, else NULL and the
   caller reads them the slow way. */
static const uint8_t *have(Stream *s, size_t n) {
    if (!s->ok || s->n - s->pos < n) return NULL;
    const uint8_t *at = s->buf + s->pos;
    s->pos += n;
    return at;
}

static uint8_t get_u8(Stream *s) {
    const uint8_t *b = have(s, 1);
    if (b) return b[0];
    uint8_t v = 0;
    get(s, &v, 1);
    return v;
}

static uint16_t get_u16(Stream *s) {
    uint8_t tmp[2] = { 0, 0 };
    const uint8_t *b = have(s, 2);
    if (!b) { get(s, tmp, 2); b = tmp; }
    return (uint16_t)((uint16_t)b[0] | ((uint16_t)b[1] << 8));
}

static uint32_t get_u32(Stream *s) {
    uint8_t tmp[4] = { 0, 0, 0, 0 };
    const uint8_t *b = have(s, 4);
    uint32_t v = 0;
    if (!b) { get(s, tmp, 4); b = tmp; }
    for (int i = 3; i >= 0; i--) v = (v << 8) | b[i];
    return v;
}

static uint64_t get_u64(Stream *s) {
    uint8_t tmp[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t *b = have(s, 8);
    uint64_t v = 0;
    if (!b) { get(s, tmp, 8); b = tmp; }
    for (int i = 7; i >= 0; i--) v = (v << 8) | b[i];
    return v;
}

/* An offset is kept where the pointer will go, one more than it is: the
   first object of the heap is at 0, which as a pointer is no object, and was
   lost so (M9 of docs/plans/codegen.md found it). heap_relocate, told of the
   one, turns every one of them into a pointer, and refuses the image if any
   is not in the heap. */
static Obj *get_obj(Stream *s) {
    uint64_t w = get_u64(s);
    return w == OFF_NONE ? NULL : (Obj *)(uintptr_t)(w + 1);
}

static Value get_value(Stream *s) {
    Value v;
    const uint8_t *b = have(s, 9);
    uint64_t w = 0;
    if (b) {
        v.tag = b[0];
        for (int i = 8; i >= 1; i--) w = (w << 8) | b[i];
    } else {
        v.tag = get_u8(s);
        w = get_u64(s);
    }
    if (v.tag == T_PTR) v.u.p = w == OFF_NONE ? NULL : (Obj *)(uintptr_t)(w + 1);
    else v.u.w = w;
    return v;
}

/* The heap, rebuilt at the offsets it was written from, so that the
   distances the rest of the image holds stay true. */
static int get_heap(Stream *s, VM *vm) {
    size_t scan = 0;
    while (scan < vm->heap_used) {
        if (vm->heap_used - scan < sizeof(Obj)) return 0;
        Obj *o = (Obj *)(vm->heap_from + scan);
        o->kind = get_u8(s);
        o->pad = 0;
        o->contag = get_u16(s);
        o->len = get_u32(s);
        if (!s->ok || o->kind < K_TUPLE || o->kind > K_EXNCON) return 0;
        size_t size = obj_size(o);
        if (size > vm->heap_used - scan) return 0;
        if (o->kind == K_STRING) {
            get(s, OBJ_BYTES(o), o->len);
        } else {
            Value *f = OBJ_FIELDS(o);
            for (uint32_t i = 0; i < o->len; i++) f[i] = get_value(s);
        }
        scan += size;
    }
    return s->ok;
}

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
    uint64_t n = get_u64(s);
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

static int read_image(VM *vm, FILE *in, int want, char *err, size_t errlen) {
    Stream s = { in, 1, 0, 0, {0} };
    if (!s.f) return failed(&s, err, errlen, "no image to resume from");
    Program *p = &vm->prog;

    char magic[ISA_IMAGE_MAGIC_SIZE];
    get(&s, magic, sizeof magic);
    if (!s.ok || memcmp(magic, IMAGE_MAGIC, sizeof magic) != 0)
        return failed(&s, err, errlen, "not an image of this runevm");
    int kind = (int)get_u32(&s);
    if (!s.ok || kind != want)
        return failed(&s, err, errlen,
                      want == IMAGE_FORK ? "the image was not made by fork"
                                         : "the image was not made by Runtime.save");

    vm->trace = (int)get_u32(&s);
    vm->stats = (int)get_u32(&s);
    vm->count = (int)get_u32(&s);
    vm->emulate_fork = (int)get_u32(&s);
    fesetround((int)get_u32(&s));
    vm->heap_fill = get_u32(&s);
    if (s.ok && (vm->heap_fill < 1 || vm->heap_fill > 100))
        return failed(&s, err, errlen, "the image is not sound");
    vm->gc_stress = (size_t)get_u64(&s);
    vm->gc_count = (size_t)get_u64(&s);
    vm->gc_user_us = (int64_t)get_u64(&s);
    vm->gc_sys_us = (int64_t)get_u64(&s);
    vm->bytes_allocated = get_u64(&s);
    vm->objects_allocated = get_u64(&s);
    vm->instructions = get_u64(&s);
    vm->pc = get_u32(&s);
    vm->io_errno = (int)get_u32(&s);

    vm->owns_args = 1;
    vm->progname = get_string(&s);
    vm->argc = (int)get_u32(&s);
    if (!s.ok || vm->argc < 0 || !fits((uint64_t)vm->argc, sizeof(char *)))
        return failed(&s, err, errlen, "the image is cut short");
    vm->argv = calloc(vm->argc > 0 ? (size_t)vm->argc : 1, sizeof(char *));
    if (!vm->argv) return failed(&s, err, errlen, "out of memory");
    for (int i = 0; i < vm->argc; i++) vm->argv[i] = get_string(&s);

    /* the heap, before what points into it */
    uint64_t heap_size = get_u64(&s);
    uint64_t heap_used = get_u64(&s);
    if (!s.ok || heap_used > heap_size || heap_size > SIZE_MAX)
        return failed(&s, err, errlen, "the image is cut short");
    vm->heap_size = (size_t)heap_size;
    vm->heap_used = (size_t)heap_used;
    vm->heap_from = malloc(vm->heap_size > 0 ? vm->heap_size : 1);
    if (!vm->heap_from) return failed(&s, err, errlen, "cannot allocate heap");
    if (!get_heap(&s, vm)) return failed(&s, err, errlen, "the heap of the image is not sound");

    p->nconsts = get_u32(&s);
    if (!s.ok || !fits(p->nconsts, sizeof(Value))) return failed(&s, err, errlen, "the image is cut short");
    p->consts = calloc(p->nconsts > 0 ? p->nconsts : 1, sizeof(Value));
    if (!p->consts) return failed(&s, err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->nconsts; i++) p->consts[i] = get_value(&s);
    p->nglobals = get_u32(&s);
    p->nfuncs = get_u32(&s);
    if (!s.ok || !fits(p->nfuncs, sizeof(Function))) return failed(&s, err, errlen, "the image is cut short");
    p->funcs = calloc(p->nfuncs > 0 ? p->nfuncs : 1, sizeof(Function));
    if (!p->funcs) return failed(&s, err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->nfuncs && s.ok; i++) {
        p->funcs[i].code_offset = get_u32(&s);
        p->funcs[i].code_end = get_u32(&s);
        p->funcs[i].nlocals = get_u32(&s);
        p->funcs[i].name = get_string(&s);
    }
    p->code_len = get_u32(&s);
    p->code = get_new(&s, p->code_len);
    p->nfiles = get_u32(&s);
    if (!s.ok || !fits(p->nfiles, sizeof(char *))) return failed(&s, err, errlen, "the image is cut short");
    p->files = calloc(p->nfiles > 0 ? p->nfiles : 1, sizeof(char *));
    if (!p->files) return failed(&s, err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->nfiles && s.ok; i++) p->files[i] = get_string(&s);
    p->nlines = get_u32(&s);
    if (!s.ok || !fits(p->nlines, sizeof(LineEntry))) return failed(&s, err, errlen, "the image is cut short");
    p->lines = calloc(p->nlines > 0 ? p->nlines : 1, sizeof(LineEntry));
    if (!p->lines) return failed(&s, err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->nlines && s.ok; i++) {
        p->lines[i].pc = get_u32(&s);
        p->lines[i].file = get_u32(&s);
        p->lines[i].line = get_u32(&s);
        p->lines[i].col = get_u32(&s);
        p->lines[i].inl = get_u32(&s);
    }
    p->ninlines = get_u32(&s);
    if (!s.ok || !fits(p->ninlines, sizeof(Inlined))) return failed(&s, err, errlen, "the image is cut short");
    p->inlines = calloc(p->ninlines > 0 ? p->ninlines : 1, sizeof(Inlined));
    if (!p->inlines) return failed(&s, err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->ninlines && s.ok; i++) {
        p->inlines[i].name = get_string(&s);
        p->inlines[i].file = get_u32(&s);
        p->inlines[i].line = get_u32(&s);
        p->inlines[i].col = get_u32(&s);
        p->inlines[i].parent = get_u32(&s);
        /* an image is untrusted input: a frame names a file and a frame
           before it (vm_print_trace follows the chain) */
        if (s.ok && ((p->inlines[i].line != 0 && p->inlines[i].file >= p->nfiles) ||
                     (p->inlines[i].line == 0 && p->inlines[i].file != 0) || p->inlines[i].parent > i))
            return failed(&s, err, errlen, "a bad table of inlined functions");
    }
    for (uint32_t i = 0; i < p->nlines && s.ok; i++)
        if (p->lines[i].inl > p->ninlines) return failed(&s, err, errlen, "a bad line table");

    if (!s.ok || !fits(p->nglobals, sizeof(Value))) return failed(&s, err, errlen, "the image is cut short");
    vm->globals = calloc(p->nglobals > 0 ? p->nglobals : 1, sizeof(Value));
    vm->global_set = calloc(p->nglobals > 0 ? p->nglobals : 1, 1);
    if (!vm->globals || !vm->global_set) return failed(&s, err, errlen, "out of memory");
    for (uint32_t i = 0; i < p->nglobals; i++) vm->globals[i] = get_value(&s);
    get(&s, vm->global_set, p->nglobals);
    for (int i = 0; i < NUM_BUILTIN_EXNS; i++) vm->builtin_exns[i] = get_obj(&s);

    uint64_t sp = get_u64(&s);
    if (!s.ok || !fits(sp, sizeof(Value))) return failed(&s, err, errlen, "the image is cut short");
    vm_grow_stack(vm, (size_t)sp + 1);
    vm->sp = (size_t)sp;
    for (size_t i = 0; i < vm->sp; i++) vm->stack[i] = get_value(&s);

    vm->frames_active = (int)get_u32(&s);
    vm->fp = (size_t)get_u64(&s);
    if (vm->frames_active) {
        if (!s.ok || !fits((uint64_t)vm->fp + 1, sizeof(Frame))) return failed(&s, err, errlen, "the image is cut short");
        vm->frames_cap = vm->fp + 1 < 256 ? 256 : vm->fp + 1;
        vm->frames = malloc(vm->frames_cap * sizeof(Frame));
        if (!vm->frames) return failed(&s, err, errlen, "out of memory");
        for (size_t i = 0; i <= vm->fp && s.ok; i++) {
            vm->frames[i].func = get_u32(&s);
            vm->frames[i].ret_pc = get_u32(&s);
            vm->frames[i].base = (size_t)get_u64(&s);
            vm->frames[i].closure = get_obj(&s);
        }
    }
    vm->hp = (size_t)get_u64(&s);
    if (!s.ok || !fits((uint64_t)vm->hp, sizeof(Handler))) return failed(&s, err, errlen, "the image is cut short");
    vm->handlers_cap = vm->hp < 64 ? 64 : vm->hp;
    vm->handlers = malloc(vm->handlers_cap * sizeof(Handler));
    if (!vm->handlers) return failed(&s, err, errlen, "out of memory");
    for (size_t i = 0; i < vm->hp && s.ok; i++) {
        vm->handlers[i].pc = get_u32(&s);
        vm->handlers[i].sp = (size_t)get_u64(&s);
        vm->handlers[i].fp = (size_t)get_u64(&s);
    }

    uint64_t nfiles = get_u64(&s);
    if (!s.ok || nfiles < 3 || !fits(nfiles, sizeof(FILE *))) return failed(&s, err, errlen, "the image is cut short");
    vm->files_cap = nfiles < 8 ? 8 : (size_t)nfiles;
    vm->files = calloc(vm->files_cap, sizeof(FILE *));
    vm->file_modes = calloc(vm->files_cap, 1);
    vm->file_paths = calloc(vm->files_cap, sizeof(char *));
    if (!vm->files || !vm->file_modes || !vm->file_paths) return failed(&s, err, errlen, "out of memory");
    vm->nfiles = (size_t)nfiles;
    vm->files[0] = stdin;
    vm->files[1] = stdout;
    vm->files[2] = stderr;
    for (size_t i = 0; i < vm->nfiles && s.ok; i++) {
        int fd = (int)get_u32(&s);
        vm->file_modes[i] = get_u8(&s);
        uint8_t mode = vm->file_modes[i];
        if (kind == IMAGE_FORK) {
            /* the descriptors came with the child */
            if (i >= 3 && fd >= 0 && s.ok)
                vm->files[i] = sys_fdopen(fd, mode == 0 ? "rb" : mode == 1 ? "wb" : "ab");
        } else {
            /* nothing was inherited: open the file again where it was left.
               A file written to is opened for update, not truncated. */
            char *path = get_string(&s);
            int64_t at = (int64_t)get_u64(&s);
            if (!s.ok) { free(path); break; }
            if (i >= 3 && path && path[0]) {
                FILE *f = sys_fopen(path, mode == 0 ? "rb" : mode == 1 ? "r+b" : "ab");
                if (!f) {
                    free(path);
                    return failed(&s, err, errlen, "a file the image was saved with cannot be opened again");
                }
                if (at >= 0 && mode != 2) sys_fseek(f, at, SEEK_SET);
                vm->files[i] = f;
                vm->file_paths[i] = path;
            } else {
                free(path);
            }
        }
    }
    get(&s, magic, sizeof magic);
    if (!s.ok || memcmp(magic, IMAGE_MAGIC, sizeof magic) != 0 || !p->code)
        return failed(&s, err, errlen, "the image is cut short");
    fclose(s.f);
    /* every pointer is a distance from the start of the heap, and one more:
       moving them by where the heap is now both places them and checks that
       they are in it */
    if (!heap_relocate(vm, 1)) {
        snprintf(err, errlen, "the heap of the image is not sound");
        return 0;
    }
    /* An image carries code, and since Runtime.restore it comes from a file
       like any other: it is checked as a .rbc is, and then the places this
       world is stopped at are checked to be instructions of it. */
    {
        uint8_t *starts = validate_program(p, err, errlen);
        if (!starts) return 0;
        int ok = vm->pc < p->code_len && starts[vm->pc];
        if (ok && vm->frames_active) {
            if (vm->fp >= vm->frames_cap) ok = 0;
            for (size_t i = 0; ok && i <= vm->fp; i++)
                ok = vm->frames[i].func < p->nfuncs
                     && vm->frames[i].base <= vm->sp
                     && (i == 0 || (vm->frames[i].ret_pc < p->code_len && starts[vm->frames[i].ret_pc]));
        }
        for (size_t i = 0; ok && i < vm->hp; i++)
            ok = vm->handlers[i].pc < p->code_len && starts[vm->handlers[i].pc]
                 && vm->handlers[i].sp <= vm->sp
                 && (!vm->frames_active || vm->handlers[i].fp <= vm->fp);
        free(starts);
        if (!ok) {
            snprintf(err, errlen, "the image stopped somewhere its program does not go");
            return 0;
        }
    }
    /* The image was written inside the primitive that made it, whose
       argument is still on the stack. What replaces it is what that call
       gives back in the world that starts again: 0 for the child of a fork,
       and 1 -- `Restored` -- for the program that saved itself. */
    if (vm->sp == 0) { snprintf(err, errlen, "the image has nothing on its stack"); return 0; }
    vm->sp--;
    vm_push(vm, mk_int(kind == IMAGE_FORK ? 0 : 1));
    return 1;
}

int vm_resume(VM *vm, const char *token, char *err, size_t errlen) {
    return read_image(vm, sys_resume(token), IMAGE_FORK, err, errlen);
}

int vm_restore(VM *vm, const char *path, char *err, size_t errlen) {
    return read_image(vm, sys_fopen(path, "rb"), IMAGE_SAVE, err, errlen);
}

/* Runtime.restore: this world becomes the one in the file, bytecode and all,
   so what runs afterwards may be another program. The image is read into a
   world of its own and only moved over once it is whole: a file that is not
   an image, or is cut short, leaves this world running and able to raise.
   The world that was here is let go -- its files closed, its heap and its
   program freed -- which is what a program that restores in a loop needs. */
int vm_become(VM *vm, const char *path) {
    VM *next = calloc(1, sizeof(VM));
    char err[256];
    if (!next) { vm->io_errno = ENOMEM; return 0; }
    fflush(NULL);
    if (!read_image(next, sys_fopen(path, "rb"), IMAGE_SAVE, err, sizeof err)) {
        vm_release(next);
        free(next);
        vm->io_errno = EINVAL;
        return 0;
    }
    /* Native code runs its own program and no other (docs/native.md,
       Images): an image of another is refused, and this world goes on. */
    if (vm->native) {
        if (!vm_same_program || !vm_same_program(next)) {
            vm_release(next);
            free(next);
            sys_set_errno(ENOEXEC);
            return 0;
        }
        next->native = 1;
    }
    /* the JIT's options are this process's, not the image's (vm/new) */
    next->jit_mode = vm->jit_mode;
    next->jit_stats = vm->jit_stats;
    /* Nothing of this world is read again, so it goes before the other takes
       its place; the path was copied out of the heap by the caller. */
    vm_release(vm);
    *vm = *next;
    free(next);
    return 1;
}
