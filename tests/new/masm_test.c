/* A test of the JIT's macro-assembler (vm/new/jit/masm.h; make
   test-new-jit) on a small VM: the enter and leave stubs, values moved and
   made, a tuple allocated in line with its counts, the VM made exact, and
   an allocation's slow path taken. */
#include "masm.h"
#include "sys.h"
#include <stdio.h>
#include <string.h>

static void *place(X64 *a) {
    void *m = sys_code_alloc(65536);
    memcpy(m, a->buf, a->n);
    sys_code_protect(m, 65536, 1);
    sys_code_flush(m, 65536);
    return m;
}
typedef int (*Enter)(VM *, const void *);
static Enter as_enter(void *p) { Enter f; memcpy(&f, &p, sizeof f); return f; }

int main(void) {
    int fails = 0;
    X64 st; x64_init(&st);
    ms_emit_enter(&st, 0);
    size_t leave_at = st.n;
    ms_emit_leave(&st, 0);
    void *stubs = place(&st);
    const void *leave = (const char *)stubs + leave_at;

    /* a VM with one frame of 4 registers at base 3 of the stack */
    static VM vm;
    static Value stack[64];
    static Frame frames[4];
    static char heap[4096];
    memset(&vm, 0, sizeof vm);
    vm.stack = stack; vm.sp = 7; vm.stack_cap = 64;
    vm.frames = frames; vm.fp = 1; vm.frames_active = 1;
    frames[1].base = 3;
    vm.heap_from = heap; vm.heap_size = sizeof heap; vm.heap_used = 32;
    vm.instructions = 100;
    stack[3] = mk_int(7);
    stack[4] = mk_ptr(NULL);

    Masm m;
    ms_init(&m, 4, 0, 0, leave);
    X64Label bad; x64_label_init(&bad);
    ms_count(&m, 5);
    ms_copy(&m, 1, 0);                      /* R1 := R0 (int 7) */
    ms_set(&m, 2, T_CON0, 3);               /* R2 := constructor 3 */
    ms_load_payload(&m, RAX, 0);
    x64_add_ri(&m.a, RAX, 35);
    ms_set_reg(&m, 3, T_INT, RAX);          /* R3 := 42 */
    ms_check_tag(&m, 3, T_INT, &bad);
    ms_alloc(&m, K_TUPLE, 0, 2, &bad);      /* rax := a tuple of 2 */
    ms_store_field(&m, RAX, 0, 1);
    ms_store_field(&m, RAX, 1, 3);
    ms_set_reg(&m, 0, T_PTR, RAX);          /* R0 := the tuple */
    ms_sync(&m, 77, 0);
    ms_handback(&m, 2);
    x64_bind(&m.a, &bad);
    ms_handback(&m, 9);
    void *code = place(&m.a);
    int r = as_enter(stubs)(&vm, code);
    if (r != 2) { printf("FAIL answer %d\n", r); fails++; }
    if (stack[4].tag != T_INT || stack[4].u.i != 7) { printf("FAIL copy\n"); fails++; }
    if (stack[5].tag != T_CON0 || stack[5].u.i != 3) { printf("FAIL set\n"); fails++; }
    if (stack[6].tag != T_INT || stack[6].u.i != 42) { printf("FAIL set_reg\n"); fails++; }
    if (stack[3].tag != T_PTR) { printf("FAIL alloc tag\n"); fails++; }
    else {
        Obj *t = stack[3].u.p;
        if ((char *)t != heap + 32 || t->kind != K_TUPLE || t->len != 2 || t->contag != 0) { printf("FAIL header\n"); fails++; }
        if (OBJ_FIELDS(t)[0].u.i != 7 || OBJ_FIELDS(t)[1].u.i != 42) { printf("FAIL fields\n"); fails++; }
    }
    if (vm.heap_used != 32 + 8 + 32 || vm.bytes_allocated != 40 || vm.objects_allocated != 1) { printf("FAIL counts %zu %llu\n", vm.heap_used, (unsigned long long)vm.bytes_allocated); fails++; }
    if (vm.pc != 77 || vm.sp != 7 || vm.instructions != 105) { printf("FAIL sync pc %u sp %zu count %llu\n", vm.pc, vm.sp, (unsigned long long)vm.instructions); fails++; }
    /* the slow path: no room */
    vm.heap_used = sizeof heap - 8;
    r = as_enter(stubs)(&vm, code);
    if (r != 9) { printf("FAIL slow %d\n", r); fails++; }
    printf(fails ? "masm: %d failures\n" : "masm: ok\n", fails);
    return fails != 0;
}
