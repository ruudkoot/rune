/* The hooks the collector to come needs, as the copier of today keeps them
   (docs/plans/heap-layout.md, M7): the header's four bits are zero, and
   with RUNE_GC_BITS, the build whose collector sets them, they go with
   their object and a kind is read through them; an object made an
   indirection in place is followed through its first field alone; young is
   told by address; two VMs of a process collect independently; the roots
   listed in heap.c are all there; with RUNE_BARRIER_CARDS a store into an
   object marks the card of its field; heap_check finds a heap that is not
   sound. Built by make test, and by make test-heap with
   each switch. */
#include "vm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fails;
#define CHECK(what, cond) do { if (!(cond)) { printf("FAIL %s (%s:%d)\n", what, __FILE__, __LINE__); fails++; } } while (0)

static VM *new_vm(size_t heap) {
    VM *vm = calloc(1, sizeof(VM));
    if (!vm) exit(2);
    vm_init(vm, heap);
    vm_grow_stack(vm, 64);
    return vm;
}

static Value tuple(VM *vm, uint32_t n, int64_t first) {
    Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, n);
    for (uint32_t i = 0; i < n; i++) obj_fill_field(t, i, mk_imm(first + i));
    return mk_ptr(t);
}

int main(void) {
    VM *vm = new_vm(1 << 16);

    /* a collection moves an object whole; the header's four bits are zero
       where no collector sets them, and where one does (RUNE_GC_BITS) a
       kind is read through them and they go with the object */
    vm_push(vm, tuple(vm, 3, 10));
    vm_push(vm, tuple(vm, 1, 20));
    Obj *a = val_ptr(vm->stack[0]), *b = val_ptr(vm->stack[1]);
    obj_set_field(a, 2, mk_ptr(b));
#ifdef RUNE_GC_BITS
    obj_set_gc_bits(a, 2 * OBJ_GC_AGE_ONE | OBJ_GC_PINNED);
    obj_set_gc_bits(b, OBJ_GC_REMEMBERED);
    CHECK("a kind is read through the collector's bits", obj_kind(a) == K_TUPLE && obj_kind(b) == K_TUPLE);
    CHECK("an object with bits has its fields", obj_has_fields(a) && obj_len(a) == 3);
#else
    CHECK("a fresh object has none of the collector's bits", obj_gc_bits(a) == 0 && obj_gc_bits(b) == 0);
#endif
    vm_gc(vm, 0);
    Obj *a2 = val_ptr(vm->stack[0]), *b2 = val_ptr(vm->stack[1]);
    CHECK("the collection moved them", a2 != a && b2 != b);
    CHECK("the copy is the object", obj_kind(a2) == K_TUPLE && obj_len(a2) == 3 && obj_field(a2, 0) == mk_imm(10));
    CHECK("its field follows the other", obj_field(a2, 2) == mk_ptr(b2) && obj_field(b2, 0) == mk_imm(20));
#ifdef RUNE_GC_BITS
    CHECK("the copy has the age it had and one collection more", (obj_gc_bits(a2) & OBJ_GC_AGE) == OBJ_GC_AGE);
    CHECK("the other is one collection old", (obj_gc_bits(b2) & OBJ_GC_AGE) == OBJ_GC_AGE_ONE);
    obj_set_gc_bits(a2, 0); obj_set_gc_bits(b2, 0);
    CHECK("the bits are cleared and the kind stays", obj_gc_bits(a2) == 0 && obj_kind(a2) == K_TUPLE);
#else
    CHECK("the copier sets none", obj_gc_bits(a2) == 0 && obj_gc_bits(b2) == 0);
#endif
    CHECK("what was left is forwarded", obj_forwarded(a) && obj_forwarding(a) == a2);

    /* an indirection made in place: the first field alone is followed */
    vm->sp = 0;
    vm_push(vm, mk_unit());                                     /* the suspension, when it is made */
    vm_push(vm, tuple(vm, 2, 30));                              /* its value */
    vm_push(vm, tuple(vm, 2, 40));                              /* what its second field held */
    Obj *th = vm_alloc_fields(vm, K_THUNK, 0, 3);
    obj_fill_field(th, 0, mk_imm(7));
    obj_fill_field(th, 1, vm->stack[2]);
    vm->stack[0] = mk_ptr(th);
    Obj *dead = val_ptr(vm->stack[2]);
    vm->sp = 2;                                                 /* the second field's object is reachable through the suspension alone */
#ifdef RUNE_GC_BITS
    obj_set_gc_bits(th, OBJ_GC_AGE_ONE);
#endif
    obj_become_ind(th, vm->stack[1]);
    CHECK("it is an indirection", obj_kind(th) == K_IND);
#ifdef RUNE_GC_BITS
    CHECK("with the bits it had", (obj_gc_bits(th) & OBJ_GC_AGE) == OBJ_GC_AGE_ONE);
#endif
    size_t before = vm->copied;
    vm_gc(vm, 0);
    Obj *ind = val_ptr(vm->stack[0]), *val = val_ptr(vm->stack[1]);
    CHECK("the indirection moved, the same size", obj_kind(ind) == K_IND && obj_len(ind) == 3);
    CHECK("its first field is the value, moved", obj_field(ind, 0) == mk_ptr(val) && obj_field(val, 0) == mk_imm(30));
    CHECK("what its other fields held was not followed", !obj_forwarded(dead));
    CHECK("the collection copied the two and the VM's boxes alone",
          vm->copied - before == obj_size(ind) + obj_size(val) + (size_t)REAL_BOXES * obj_size_of(K_REAL, 1));

    /* young, by address */
    static char elsewhere[64];
    CHECK("an object of the heap is young", heap_is_young(vm, ind) && heap_is_young(vm, val));
    CHECK("the space left behind is not", !heap_is_young(vm, th));
    CHECK("nor is what is not of the heap", !heap_is_young(vm, elsewhere) && !heap_is_young(vm, vm));
    CHECK("nor the end of the space", !heap_is_young(vm, vm->alloc.from + vm->alloc.size) && heap_is_young(vm, vm->alloc.from));

    /* every root of the list: a global, a constant, a frame's closure,
       a built-in exception's constructor, the VM's boxes */
    Value g = tuple(vm, 1, 50), k = tuple(vm, 1, 60);
    vm->globals = &g; vm->prog.nglobals = 1;
    vm->prog.consts = &k; vm->prog.nconsts = 1;
    Obj *clo = vm_alloc_fields(vm, K_CLOSURE, 0, 1);
    vm->frames = calloc(1, sizeof(Frame)); vm->frames_active = 1; vm->fp = 0;
    vm->frames[0].closure = clo;
    Obj *exn = vm_alloc_fields(vm, K_EXNCON, 0, 1);
    vm->builtin_exns[0] = exn;
    Obj *zero = vm->real_boxes[REAL_BOX_ZERO];
    vm->sp = 0;
    vm_gc(vm, 0);
    CHECK("a global is a root", val_ptr(g) != NULL && obj_field(val_ptr(g), 0) == mk_imm(50) && heap_is_young(vm, val_ptr(g)));
    CHECK("a constant is a root", obj_field(val_ptr(k), 0) == mk_imm(60) && heap_is_young(vm, val_ptr(k)));
    CHECK("a frame's closure is a root", vm->frames[0].closure != clo && obj_kind(vm->frames[0].closure) == K_CLOSURE);
    CHECK("a built-in exception is a root", vm->builtin_exns[0] != exn && obj_kind(vm->builtin_exns[0]) == K_EXNCON);
    CHECK("the VM's boxes are roots", vm->real_boxes[REAL_BOX_ZERO] != zero && obj_kind(vm->real_boxes[REAL_BOX_ZERO]) == K_REAL);
    vm->frames_active = 0; vm->prog.nglobals = 0; vm->prog.nconsts = 0; vm->builtin_exns[0] = NULL;

    /* two VMs: the one's collection is not the other's */
    VM *other = new_vm(1 << 16);
    vm_push(other, tuple(other, 2, 70));
    vm_push(vm, tuple(vm, 2, 80));
    Obj *mine = val_ptr(vm->stack[0]), *theirs = val_ptr(other->stack[0]);
    size_t n0 = vm->gc_count, m0 = other->gc_count;
    vm_gc(other, 0);
    CHECK("the other VM collected and this one did not", other->gc_count == m0 + 1 && vm->gc_count == n0);
    CHECK("this VM's object is where it was", val_ptr(vm->stack[0]) == mine && obj_field(mine, 0) == mk_imm(80));
    CHECK("the other's moved, whole", val_ptr(other->stack[0]) != theirs && obj_field(val_ptr(other->stack[0]), 1) == mk_imm(71));
    vm_gc(vm, 0);
    CHECK("and this one's after it", obj_field(val_ptr(vm->stack[0]), 1) == mk_imm(81) && obj_field(val_ptr(other->stack[0]), 0) == mk_imm(70));

    /* The arrays C can read (M8): an array of bytes and one of reals, each
       laid out as C has it, handed to a C function through the handle
       table and found again after a collection moved them; and a copy that
       stays where it is for C to keep a pointer to (vm_pin), given back. */
    {
        Obj *bytes = vm_alloc(vm, K_BYTES, 0, 5, 5);
        memcpy(obj_bytes(bytes), "hello", 5);
        size_t hb = vm_handle_new(vm, mk_ptr(bytes));
        Obj *reals = vm_alloc(vm, K_REALS, 0, 3, 24);
        double three[3] = { 1.5, -0.0, 1e300 };
        memcpy(obj_bytes(reals), three, sizeof three);
        size_t hr = vm_handle_new(vm, mk_ptr(reals));
        CHECK("an array of bytes takes a byte an element", obj_size(bytes) == sizeof(Obj) + 8 && !obj_has_fields(bytes));
        CHECK("an array of reals takes a double an element", obj_size(reals) == sizeof(Obj) + 24 && !obj_has_fields(reals));
        vm->sp = 0;
        vm_gc(vm, 0);                                   /* nothing but the handles holds them */
        Obj *b2 = val_ptr(vm_handle_get(vm, hb)), *r2 = val_ptr(vm_handle_get(vm, hr));
        CHECK("a handle is a root, and names the object where it is", b2 != bytes && r2 != reals && obj_kind(b2) == K_BYTES && obj_kind(r2) == K_REALS);
        CHECK("the bytes are C's", obj_len(b2) == 5 && memcmp(obj_bytes(b2), "hello", 5) == 0);
        CHECK("the reals are C's", memcmp(obj_bytes(r2), three, sizeof three) == 0);
        size_t n = 0;
        char *held = vm_pin(vm, hb, &n);
        CHECK("a pinned copy has the bytes", held && n == 5 && memcmp(held, "hello", 5) == 0);
        vm_gc(vm, 0);                                   /* the object moves; C's copy does not */
        if (held) memcpy(held, "HELLO", 5);
        vm_unpin(vm, hb, held);
        Obj *b3 = val_ptr(vm_handle_get(vm, hb));
        CHECK("what C wrote is in the object, where it is now", b3 != b2 && memcmp(obj_bytes(b3), "HELLO", 5) == 0);
        CHECK("a handle that names no such array pins nothing", vm_pin(vm, vm_handle_new(vm, mk_imm(3)), NULL) == NULL);
        vm_handle_free(vm, hb);
        size_t again = vm_handle_new(vm, mk_imm(9));
        CHECK("a freed handle is given again", again == hb && vm_handle_get(vm, again) == mk_imm(9));
        vm_handle_free(vm, hr); vm_handle_free(vm, again);
        uint64_t copied = vm->copied;
        vm_gc(vm, 0);
        CHECK("a freed handle keeps nothing", vm->copied - copied == (uint64_t)REAL_BOXES * obj_size_of(K_REAL, 1));
    }

    /* --gc-verify (heap_check): a sound heap passes, and a pointer that is
       to no object's start, in a field or on the stack, is found */
    {
        vm_push(vm, tuple(vm, 2, 90));
        vm_push(vm, tuple(vm, 2, 92));
        const void *at = NULL;
        CHECK("a sound heap passes heap_check", heap_check(vm, &at) == NULL);
        Obj *a = val_ptr(vm->stack[vm->sp - 2]), *b = val_ptr(vm->stack[vm->sp - 1]);
        Obj *inside = (Obj *)(void *)((char *)b + 8);
        obj_fill_field(a, 0, mk_ptr(inside));
        CHECK("a field into the middle of an object is found", heap_check(vm, &at) != NULL && at == inside);
        obj_fill_field(a, 0, mk_imm(90));
        vm->stack[vm->sp - 1] = mk_ptr(inside);
        CHECK("a slot of the stack into the middle of an object is found", heap_check(vm, &at) != NULL && at == inside);
        vm->stack[vm->sp - 1] = mk_ptr(b);
        CHECK("and the heap mended passes again", heap_check(vm, NULL) == NULL);
        vm->sp -= 2;
    }

#ifdef RUNE_BARRIER_CARDS
    /* the measuring barrier: a store into an object marks the card of its field, a fill of a fresh one does not */
    memset(rune_cards, 0, CARD_COUNT);
    Obj *r = val_ptr(vm->stack[0]);
    size_t card = ((uintptr_t)&obj_fields(r)[0] >> CARD_SHIFT) & (CARD_COUNT - 1);
    obj_fill_field(r, 0, mk_imm(1));
    CHECK("a fill marks nothing", rune_cards[card] == 0);
    obj_set_field(r, 0, mk_imm(2));
    CHECK("a store marks the card of its field", rune_cards[card] == 1);
#endif

    if (fails) { printf("heap_test: %d failed\n", fails); return 1; }
    printf("heap_test: the collector's hooks hold\n");
    return 0;
}
