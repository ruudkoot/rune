/* A failed buffer may be unaligned. Finishing a trampoline must return,
   including when a Windows trampoline's trailing padding cannot grow. */
static int trampoline_trial(int fail, int win) {
    probe_start(fail);
    Asm a;
    as_init(&a);
    as_u32(&a, 0);
    for (int i = 0; i < 300; i++) as_trampoline(&a, win, 0x12345678);
    int failed = fail ? !a.failed : a.failed;
    as_free(&a);
    failed |= probe_finish();
    if (failed) printf("FAIL trampoline allocation %d (windows=%d)\n", fail, win);
    return failed;
}

static int trampoline_failures(void) {
    int failed = 0;
    for (int win = 0; win < 2; win++) {
        failed |= trampoline_trial(0, win);
        int total = calls;
        for (int i = 1; i <= total; i++) failed |= trampoline_trial(i, win);
    }
    probe_start(0);
    Asm a;
    as_init(&a);
    as_u32(&a, 0);
    a.failed = 1;
    size_t at = a.n;
    as_trampoline(&a, 0, 0x12345678);
    failed |= !a.failed || a.n != at;
    as_free(&a);
    failed |= probe_finish();
    if (!failed) printf("trampoline allocation failures and failed unaligned buffer: ok\n");
    return failed;
}
