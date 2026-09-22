/* Cheney semispace copying collector. Objects are 8-byte aligned; the payload
   is rounded up to a multiple of 16 bytes and is at least 16 bytes so that a
   forwarding pointer always fits. */
#include "vm.h"
#include "sys.h"

static size_t payload_size(size_t bytes) {
    size_t s = (bytes + 15) & ~(size_t)15;
    return s < 16 ? 16 : s;
}

static size_t obj_size(const Obj *o) {
    size_t payload = (o->kind == K_STRING) ? o->len : (size_t)o->len * sizeof(Value);
    return sizeof(Obj) + payload_size(payload);
}

void heap_init(VM *vm, size_t semispace_bytes) {
    vm->heap_size = semispace_bytes;
    vm->heap_from = malloc(semispace_bytes);
    vm->heap_to = NULL;
    vm->heap_used = 0;
    vm->gc_count = 0;
    vm->gc_user_us = 0;
    vm->gc_sys_us = 0;
    vm->bytes_allocated = 0;
    vm->objects_allocated = 0;
    if (!vm->heap_from) { fprintf(stderr, "runevm: cannot allocate heap\n"); exit(2); }
}

Obj *vm_alloc(VM *vm, uint8_t kind, uint16_t contag, uint32_t len, size_t payload_bytes) {
    size_t size = sizeof(Obj) + payload_size(payload_bytes);
    if (size > vm->heap_size - vm->heap_used ||
        (vm->gc_stress && vm->objects_allocated % vm->gc_stress == 0)) {
        vm_gc(vm, size);
    }
    Obj *o = (Obj *)(vm->heap_from + vm->heap_used);
    vm->heap_used += size;
    vm->bytes_allocated += size;
    vm->objects_allocated++;
    o->kind = kind;
    o->pad = 0;
    o->contag = contag;
    o->len = len;
    return o;
}

Obj *vm_alloc_fields(VM *vm, uint8_t kind, uint16_t contag, uint32_t nfields) {
    Obj *o = vm_alloc(vm, kind, contag, nfields, (size_t)nfields * sizeof(Value));
    Value *f = OBJ_FIELDS(o);
    for (uint32_t i = 0; i < nfields; i++) f[i] = mk_unit();
    return o;
}

Obj *vm_alloc_string(VM *vm, uint32_t len) {
    return vm_alloc(vm, K_STRING, 0, len, len);
}

Obj *vm_string_from(VM *vm, const char *s, uint32_t len) {
    Obj *o = vm_alloc_string(vm, len);
    if (len) memcpy(OBJ_BYTES(o), s, len);
    return o;
}

/* --- collection --- */

static char *to_space;
static size_t to_used;

static Obj *copy_obj(Obj *o) {
    if (o->kind == K_FORWARD) return *(Obj **)OBJ_BYTES(o);
    size_t size = obj_size(o);
    Obj *n = (Obj *)(to_space + to_used);
    memcpy(n, o, size);
    to_used += size;
    o->kind = K_FORWARD;
    *(Obj **)OBJ_BYTES(o) = n;
    return n;
}

static void copy_value(Value *v) {
    if (v->tag == T_PTR && v->u.p) v->u.p = copy_obj(v->u.p);
}

static void collect_into(VM *vm, size_t new_size) {
    to_space = malloc(new_size);
    if (!to_space) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
    to_used = 0;

    /* roots */
    for (size_t i = 0; i < vm->sp; i++) copy_value(&vm->stack[i]);
    for (uint32_t i = 0; i < vm->prog.nglobals; i++) copy_value(&vm->globals[i]);
    for (uint32_t i = 0; i < vm->prog.nconsts; i++) copy_value(&vm->prog.consts[i]);
    if (vm->frames_active)
        for (size_t i = 0; i <= vm->fp; i++)
            if (vm->frames[i].closure) vm->frames[i].closure = copy_obj(vm->frames[i].closure);
    for (int i = 0; i < NUM_BUILTIN_EXNS; i++)
        if (vm->builtin_exns[i]) vm->builtin_exns[i] = copy_obj(vm->builtin_exns[i]);

    /* scan */
    size_t scan = 0;
    while (scan < to_used) {
        Obj *o = (Obj *)(to_space + scan);
        size_t size = obj_size(o);
        if (o->kind != K_STRING) {
            Value *f = OBJ_FIELDS(o);
            for (uint32_t i = 0; i < o->len; i++) copy_value(&f[i]);
        }
        scan += size;
    }

    free(vm->heap_from);
    vm->heap_from = to_space;
    vm->heap_used = to_used;
    vm->heap_size = new_size;
    vm->gc_count++;
    to_space = NULL;
}

void vm_gc(VM *vm, size_t needed) {
    /* The processor time of a collection, for Timer.checkCPUTimes and
       checkGCTime: read once around the whole of it, so that growing the
       heap counts as one collection and not two. */
    int64_t user0 = sys_time_user(), sys0 = sys_time_sys();
    /* live data always fits in a semispace of the current size */
    collect_into(vm, vm->heap_size);
    /* keep the heap at most half full after collection to avoid thrashing;
       written so that nothing wraps where a size_t is 32 bits */
    size_t want = vm->heap_size;
    while (vm->heap_used > want / 2 || needed > want / 2 - vm->heap_used) {
        if (want > SIZE_MAX / 2) { fprintf(stderr, "runevm: out of memory\n"); exit(2); }
        want *= 2;
    }
    if (want != vm->heap_size) collect_into(vm, want);
    vm->gc_user_us += sys_time_user() - user0;
    vm->gc_sys_us += sys_time_sys() - sys0;
}

/* --- relocation, for an image of the VM (vm/image.c) --- */

/* The heap and every root were read as the parent had them, its addresses
   in them: each pointer moves by the distance between the two heaps. A
   pointer that is not into the heap's used part, or an object that is not
   one, makes the image unsound (0). */
static uintptr_t reloc_old;
static int reloc_ok;

static Obj *relocate_obj(VM *vm, Obj *o) {
    uintptr_t at = (uintptr_t)o;
    if (at < reloc_old || at - reloc_old >= vm->heap_used) { reloc_ok = 0; return NULL; }
    return (Obj *)(vm->heap_from + (at - reloc_old));
}

static void relocate_value(VM *vm, Value *v) {
    if (v->tag == T_PTR && v->u.p) v->u.p = relocate_obj(vm, v->u.p);
}

int heap_relocate(VM *vm, uintptr_t old_base) {
    reloc_old = old_base;
    reloc_ok = 1;
    size_t scan = 0;
    while (reloc_ok && scan < vm->heap_used) {
        Obj *o = (Obj *)(vm->heap_from + scan);
        if (vm->heap_used - scan < sizeof(Obj) || o->kind < K_TUPLE || o->kind > K_EXNCON) return 0;
        size_t size = obj_size(o);
        if (size > vm->heap_used - scan) return 0;
        if (o->kind != K_STRING) {
            Value *f = OBJ_FIELDS(o);
            for (uint32_t i = 0; i < o->len; i++) relocate_value(vm, &f[i]);
        }
        scan += size;
    }
    for (size_t i = 0; i < vm->sp; i++) relocate_value(vm, &vm->stack[i]);
    for (uint32_t i = 0; i < vm->prog.nglobals; i++) relocate_value(vm, &vm->globals[i]);
    for (uint32_t i = 0; i < vm->prog.nconsts; i++) relocate_value(vm, &vm->prog.consts[i]);
    if (vm->frames_active)
        for (size_t i = 0; i <= vm->fp; i++)
            if (vm->frames[i].closure) vm->frames[i].closure = relocate_obj(vm, vm->frames[i].closure);
    for (int i = 0; i < NUM_BUILTIN_EXNS; i++)
        if (vm->builtin_exns[i]) vm->builtin_exns[i] = relocate_obj(vm, vm->builtin_exns[i]);
    return reloc_ok;
}
