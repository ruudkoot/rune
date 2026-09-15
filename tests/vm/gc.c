/* Exercise collector graphs that immutable Rune values cannot construct. */
#define main rune_vm_main
#include "../../vm/vm.c"
#undef main
#include <assert.h>

static void reset(void) {
    cleanup();
    vm = (Machine){.heap_limit = MAX_HEAP, .next_gc = GC_INTERVAL};
}
static size_t bytes(void *p) { return ((Allocation *)p - 1)->bytes; }

static void roots(void) {
    Value temporary[1] = {{INVALID, {0}}};
    Root root = {NULL, temporary, 1};
    size_t source_bytes, constant_bytes, stack_bytes, local_bytes, frame_bytes, temp_bytes;
    vm.gc_stress = 1;
    vm.roots = &root;
    vm.source = blob(4); source_bytes = bytes(vm.source);
    vm.constants = checked_calloc(2, sizeof(Value)); vm.constant_count = 2;
    vm.constants[0] = string_value(blob(5)); constant_bytes = bytes(vm.constants[0].as.string);
    vm.stack = checked_calloc(2, sizeof(Value)); vm.sp = 1;
    vm.stack[0] = string_value(blob(6)); stack_bytes = bytes(vm.stack[0].as.string);
    vm.locals = checked_calloc(2, sizeof(Value)); vm.local_used = 1;
    vm.locals[0] = aggregate_value(TUPLE, aggregate(2, 0)); local_bytes = bytes(vm.locals[0].as.aggregate);
    vm.frames = checked_calloc(2, sizeof(Frame)); vm.fp = 1;
    vm.frames[0].closure = aggregate_value(CLOSURE, aggregate(0, 1));
    frame_bytes = bytes(vm.frames[0].closure.as.aggregate);
    temporary[0] = string_value(blob(7)); temp_bytes = bytes(temporary[0].as.string);
    /* Stale capacity slots are not roots, even when their tags look live. */
    vm.stack[1] = string_value(blob(8));
    vm.locals[1] = string_value(blob(9));
    vm.frames[1].closure = aggregate_value(CLOSURE, aggregate(0, 1));
    collect();
    assert(vm.allocated == source_bytes + constant_bytes + stack_bytes + local_bytes + frame_bytes + temp_bytes);
    assert(vm.source->length == 4 && temporary[0].as.string->length == 7);
    vm.roots = NULL; collect();
    assert(vm.allocated == source_bytes + constant_bytes + stack_bytes + local_bytes + frame_bytes);
    vm.sp = 0; vm.local_used = 0; vm.fp = 0; collect();
    assert(vm.allocated == source_bytes + constant_bytes);
    vm.constants[0].tag = INVALID; collect(); assert(vm.allocated == source_bytes);
    vm.source = NULL; collect(); assert(vm.allocated == 0);
    reset();
}

static void cycles(void) {
    Value values[3] = {{INVALID, {0}}, {INVALID, {0}}, {INVALID, {0}}};
    Root root = {NULL, values, 3};
    Aggregate *a, *b;
    size_t live;
    vm.roots = &root; vm.gc_stress = 1;
    values[0] = aggregate_value(CLOSURE, aggregate(2, 1));
    values[1] = aggregate_value(TUPLE, aggregate(3, 0));
    values[2] = string_value(blob(12));
    a = values[0].as.aggregate; b = values[1].as.aggregate;
    a->values[0] = values[1]; a->values[1] = values[2];
    b->values[0] = values[0]; b->values[1] = values[1]; b->values[2] = values[2];
    live = vm.allocated;
    root.count = 1;
    collect(); collect();
    assert(vm.allocated == live && b->values[2].as.string->length == 12);
    vm.roots = NULL; collect(); assert(vm.allocated == 0);
    reset();
}

static void deep_graph(void) {
    Value head = scalar(UNIT, 0);
    Root root = {NULL, &head, 1};
    uint32_t i;
    size_t live;
    vm.roots = &root;
    for (i = 0; i < 100000; ++i) {
        Aggregate *a = aggregate(1, 1);
        a->values[0] = head;
        head = aggregate_value(CLOSURE, a);
    }
    live = vm.allocated; collect(); assert(vm.allocated == live);
    for (i = 0; i < 100000; ++i) head = head.as.aggregate->values[0];
    assert(head.tag == UNIT);
    collect(); assert(vm.allocated == 0);
    vm.roots = NULL; reset();
}

static void exact_limit(void) {
    size_t size = sizeof(Allocation) + sizeof(Blob) + 2;
    vm.heap_limit = size; vm.next_gc = size;
    (void)blob(1); assert(vm.allocated == size);
    /* The next allocation fits only if the first object is reclaimed. */
    vm.source = blob(1); assert(vm.allocated == size);
    collect(); assert(vm.allocated == size);
    vm.source = NULL; collect(); assert(vm.allocated == 0);
    reset();
}

int main(void) {
    roots(); cycles(); deep_graph(); exact_limit();
    puts("GC: roots, stale slots, shared cycles, 100000-object graph, and exact heap limit passed.");
    return 0;
}
