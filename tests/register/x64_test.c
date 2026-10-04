/* A test of the JIT's encoder (runtime/register/jit/x64.h; make test-register-jit): the
   bytes of a few instructions against what the manual gives, and two
   functions written with it and run. */
#include "register/jit/x64.h"
#include "sys/sys.h"
#include <stdio.h>
#include <string.h>

static void *run(X64 *a) {
    void *m = sys_code_alloc(4096);
    memcpy(m, a->buf, a->n);
    sys_code_protect(m, 4096, 1);
    sys_code_flush(m, 4096);
    return m;
}
/* an object pointer is not a function pointer in ISO C: through memcpy */
typedef long (*Fn2)(long, long);
typedef void (*Cp)(void *, const void *);
static Fn2 as_fn2(void *p) { Fn2 f; memcpy(&f, &p, sizeof f); return f; }
static Cp as_cp(void *p) { Cp f; memcpy(&f, &p, sizeof f); return f; }
static int expect(const char *what, X64 *a, const char *hex) {
    char got[512]; got[0] = 0;
    for (size_t i = 0; i < a->n; i++) sprintf(got + strlen(got), "%02x", a->buf[i]);
    if (strcmp(got, hex) != 0) { printf("FAIL %s: %s, expected %s\n", what, got, hex); return 1; }
    return 0;
}
int main(void) {
    int fails = 0;
    X64 a;
    /* the bytes */
    x64_init(&a); x64_mov_rr(&a, RAX, R13); fails += expect("mov rax, r13", &a, "4c89e8"); x64_free(&a);
    x64_init(&a); x64_mov_rm(&a, RAX, R12, 8); fails += expect("mov rax, [r12+8]", &a, "498b442408"); x64_free(&a);
    x64_init(&a); x64_mov_rm(&a, RCX, R13, 0); fails += expect("mov rcx, [r13]", &a, "498b4d00"); x64_free(&a);
    x64_init(&a); x64_mov_mr(&a, RBP, 0x100, RAX); fails += expect("mov [rbp+256], rax", &a, "48898500010000"); x64_free(&a);
    x64_init(&a); x64_movups_xm(&a, XMM0, R13, 16); fails += expect("movups xmm0, [r13+16]", &a, "410f104510"); x64_free(&a);
    x64_init(&a); x64_movups_xmi(&a, XMM1, R13, RBP, 1, 32); fails += expect("movups xmm1, [r13+rbp+32]", &a, "410f104c2d20"); x64_free(&a);
    x64_init(&a); x64_mov_mi(&a, R13, 0, 1); fails += expect("mov qword [r13], 1", &a, "49c7450001000000"); x64_free(&a);
    x64_init(&a); x64_imul_rri(&a, RCX, R11, 72); fails += expect("imul rcx, r11, 72", &a, "4969cb48000000"); x64_free(&a);
    x64_init(&a); x64_movsd_xx(&a, XMM3, XMM9); fails += expect("movsd xmm3, xmm9", &a, "f2410f10d9"); x64_free(&a);
    x64_init(&a); x64_sqrtsd(&a, XMM0, XMM1); fails += expect("sqrtsd xmm0, xmm1", &a, "f20f51c1"); x64_free(&a);
    x64_init(&a); x64_movaps_xx(&a, XMM3, XMM9); fails += expect("movaps xmm3, xmm9", &a, "410f28d9"); x64_free(&a);
    x64_init(&a); x64_movaps_xx(&a, XMM0, XMM2); fails += expect("movaps xmm0, xmm2", &a, "0f28c2"); x64_free(&a);
    x64_init(&a); x64_cmp8_mi(&a, RAX, 0, 6); fails += expect("cmp byte [rax], 6", &a, "803806"); x64_free(&a);
    /* what the tagged word tests, sets and rotates (docs/plans/heap-layout.md, M4) */
    x64_init(&a); x64_test_ri(&a, R9, 1); fails += expect("test r9, 1", &a, "49f7c101000000"); x64_free(&a);
    x64_init(&a); x64_test8_mi(&a, R14, 8, 1); fails += expect("test byte [r14+8], 1", &a, "41f6460801"); x64_free(&a);
    x64_init(&a); x64_or_ri(&a, RAX, 1); fails += expect("or rax, 1", &a, "4883c801"); x64_free(&a);
    x64_init(&a); x64_ror_ri(&a, RDX, 12); fails += expect("ror rdx, 12", &a, "48c1ca0c"); x64_free(&a);
    x64_init(&a); x64_ror_ri(&a, RAX, 52); fails += expect("ror rax, 52", &a, "48c1c834"); x64_free(&a);
    x64_init(&a); x64_add_ri(&a, R15, 3); fails += expect("add r15, 3", &a, "4983c703"); x64_free(&a);
    x64_init(&a); x64_lea(&a, RAX, R13, RBP, 1, 48); fails += expect("lea rax, [r13+rbp+48]", &a, "498d442d30"); x64_free(&a);
    x64_init(&a); x64_jmp_r(&a, R11); fails += expect("jmp r11", &a, "41ffe3"); x64_free(&a);
    x64_init(&a); x64_call_r(&a, RAX); fails += expect("call rax", &a, "ffd0"); x64_free(&a);
    x64_init(&a); x64_movsd_xm(&a, XMM0, R13, 8); fails += expect("movsd xmm0, [r13+8]", &a, "f2410f104508"); x64_free(&a);
    x64_init(&a); x64_mov8_mr(&a, RAX, 0, RSI); fails += expect("mov [rax], sil", &a, "408830"); x64_free(&a);
    x64_init(&a); x64_setcc_r8(&a, CC_L, RAX); fails += expect("setl al", &a, "0f9cc0"); x64_free(&a);
    x64_init(&a); x64_jmp_m(&a, RAX, RCX, 8, 0); fails += expect("jmp [rax+rcx*8]", &a, "ff24c8"); x64_free(&a);
    /* a function: rdi + rsi with a loop, and a label bound after its use */
    x64_init(&a);
    X64Label top, done; x64_label_init(&top); x64_label_init(&done);
    x64_mov_rr(&a, RAX, RDI);                 /* rax = a */
    x64_bind(&a, &top);
    x64_test_rr(&a, RSI, RSI);
    x64_jcc(&a, CC_E, &done);
    x64_add_ri(&a, RAX, 1);
    x64_sub_ri(&a, RSI, 1);
    x64_jmp(&a, &top);
    x64_bind(&a, &done);
    x64_ret(&a);
    Fn2 f = as_fn2(run(&a));
    if (f(40, 2) != 42) { printf("FAIL loop: %ld\n", f(40, 2)); fails++; }
    x64_label_free(&top); x64_label_free(&done); x64_free(&a);
    /* a 16-byte copy through xmm0 */
    x64_init(&a);
    x64_movups_xm(&a, XMM0, RSI, 0);
    x64_movups_mx(&a, RDI, 0, XMM0);
    x64_ret(&a);
    Cp cp = as_cp(run(&a));
    char src[16] = "0123456789abcde", dst[16] = {0};
    cp(dst, src);
    if (memcmp(src, dst, 16) != 0) { printf("FAIL copy\n"); fails++; }
    x64_free(&a);
    printf(fails ? "x64: %d failures\n" : "x64: ok\n", fails);
    return fails != 0;
}
