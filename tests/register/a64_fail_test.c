/* Allocation failure must stop emission and patching on aarch64 too.
   This runs on any host: it inspects bytes, never executes ARM code. */
#include "allocation_probe.h"

#define realloc probe_realloc
#define free probe_free
#define JIT_TARGET 2
#include "../../runtime/register/jit/a64.c"
#include "../../runtime/register/jit/asm_a64.c"
#undef realloc
#undef free
#include "trampoline_probe.h"

static int trial(int fail) {
    probe_start(fail);
    A64 a;
    A64Label label;
    a64_init(&a);
    a64_label_init(&label);
    for (int i = 0; i < 16; i++) a64_b(&a, &label);
    for (int i = 0; i < 1024; i++) a64_word(&a, 0xD503201F);
    a64_bcond(&a, A64_EQ, &label);
    a64_adr(&a, X0, &label);
    size_t at = a.n;
    a64_u32(&a, 0);
    a64_offset32_at(&a, at, at, &label);
    a64_bind(&a, &label);
    int failed = fail ? !a.failed : a.failed;
    a64_label_free(&label);
    a64_free(&a);
    failed |= probe_finish();
    if (failed) printf("FAIL a64 allocation failure %d: invalid cleanup, continued allocation or missing failure\n", fail);
    return failed;
}

/* If the table's word cannot be emitted at a full buffer's end, neither
   an already bound label nor a forward reference may patch that word. */
static int table_failure(int bound) {
    probe_start(0);
    A64 a;
    A64Label label;
    a64_init(&a);
    a64_label_init(&label);
    if (bound) a64_bind(&a, &label);
    for (int i = 0; i < 256; i++) a64_word(&a, 0xD503201F);
    size_t at = a.n;
    fail_at = calls + 1;
    a64_u32(&a, 0);
    a64_offset32_at(&a, at, at, &label);
    if (!bound) a64_bind(&a, &label);
    int failed = !a.failed || a.n != at || label.nfix != 0;
    a64_label_free(&label);
    a64_free(&a);
    failed |= probe_finish();
    if (failed) printf("FAIL a64 failed table word (%s label)\n", bound ? "bound" : "forward");
    return failed;
}

/* Malformed patch offsets are rejected before even forming a pointer. */
static int bad_offset(size_t at, int bound, int branch) {
    probe_start(0);
    A64 a;
    A64Label label;
    a64_init(&a);
    a64_label_init(&label);
    a64_u32(&a, 0);
    if (bound) a64_bind(&a, &label);
    if (branch) a64_refer_b26(&a, &label, at);
    else a64_offset32_at(&a, at, 0, &label);
    if (!bound) a64_bind(&a, &label);
    int failed = !a.failed;
    a64_label_free(&label);
    a64_free(&a);
    failed |= probe_finish();
    if (failed) printf("FAIL a64 patch bounds (%s, %s)\n", bound ? "bound" : "forward", branch ? "branch" : "table");
    return failed;
}

int main(void) {
    int failed = trial(0);
    int total = calls;
    for (int i = 1; i <= total; i++) failed |= trial(i);
    for (int bound = 0; bound < 2; bound++) {
        failed |= table_failure(bound);
        for (int branch = 0; branch < 2; branch++) {
            failed |= bad_offset(1, bound, branch);
            failed |= bad_offset(4, bound, branch);
            failed |= bad_offset(SIZE_MAX, bound, branch);
        }
    }
    failed |= trampoline_failures();
    if (!failed) printf("a64 allocation failures: %d checked; failed table words and patch bounds checked\n", total);
    return failed != 0;
}
