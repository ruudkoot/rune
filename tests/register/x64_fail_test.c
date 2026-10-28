/* Fail every allocation of an encoder workload, always moving realloc's
   storage. A failed encoder must still be safe to finish and destroy. */
#include "allocation_probe.h"

/* Instrument this translation unit without changing the production API
   or relying on a platform's linker wrapping or allocator behaviour. */
#define realloc probe_realloc
#define free probe_free
#define JIT_TARGET 1
#include "../../runtime/register/jit/x64.c"
#include "../../runtime/register/jit/asm_x64.c"
#undef realloc
#undef free
#include "trampoline_probe.h"

static int trial(int fail) {
    probe_start(fail);
    X64 a;
    X64Label label;
    x64_init(&a);
    x64_label_init(&label);
    for (int i = 0; i < 16; i++) x64_jmp(&a, &label);
    for (int i = 0; i < 4096; i++) x64_byte(&a, 0x90);
    x64_jcc(&a, CC_E, &label);
    x64_bind(&a, &label);
    int failed = fail ? !a.failed : a.failed;
    x64_label_free(&label);
    x64_free(&a);
    failed |= probe_finish();
    if (failed) printf("FAIL x64 allocation failure %d: invalid cleanup or missing failure\n", fail);
    return failed;
}

static int table_failure(int bound) {
    probe_start(0);
    X64 a;
    X64Label label;
    x64_init(&a);
    x64_label_init(&label);
    if (bound) x64_bind(&a, &label);
    for (int i = 0; i < 4096; i++) x64_byte(&a, 0x90);
    size_t at = a.n;
    fail_at = calls + 1;
    x64_u32(&a, 0);
    x64_offset32_at(&a, at, at, &label);
    if (!bound) x64_bind(&a, &label);
    int failed = !a.failed || a.n != at || label.nrefs != 0;
    x64_label_free(&label);
    x64_free(&a);
    failed |= probe_finish();
    if (failed) printf("FAIL x64 failed table word (%s label)\n", bound ? "bound" : "forward");
    return failed;
}

int main(void) {
    int failed = trial(0);
    int total = calls;
    for (int i = 1; i <= total; i++) failed |= trial(i);
    failed |= table_failure(0);
    failed |= table_failure(1);
    failed |= trampoline_failures();
    if (!failed) printf("x64 allocation failures: %d checked; failed table words checked\n", total);
    return failed != 0;
}
