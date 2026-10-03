/* main.c -- ./harness-LX kernel [n] [-s semispace_MiB]
   prints: kernel n checksum cycles_total gc_cycles gc_share
   The kernel runs on a thread with a 1 GiB stack (the recursive kernels
   go 100k deep, as the VM's growable stack lets them). */
#define _GNU_SOURCE
#include <pthread.h>
#include "harness.h"
#include "kernels.c"

#ifndef LAYOUT_NAME
#define STR_(x) #x
#define STR(x) STR_(x)
#define LAYOUT_NAME STR(LAYOUT)
#endif

static const kernel_def *kd;
static int64_t arg_n;
static uint64_t total_cycles;

static void *run(void *p) {
    (void)p;
    uint64_t t0 = cycles_now();
    kd->fn(arg_n);
    total_cycles = cycles_now() - t0;
    return NULL;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s kernel [n] [-s semispace_MiB]\nkernels:", argv[0]);
        for (const kernel_def *k = kernels; k->name; k++) fprintf(stderr, " %s", k->name);
        fprintf(stderr, "\n");
        return 2;
    }
    for (kd = kernels; kd->name; kd++) if (!strcmp(kd->name, argv[1])) break;
    if (!kd->name) die("unknown kernel");
    arg_n = kd->n;
    size_t semi = (size_t)kd->semispace_mib << 20;
    for (int i = 2; i < argc; i++) {
        if (!strcmp(argv[i], "-s") && i + 1 < argc) semi = (size_t)atol(argv[++i]) << 20;
        else arg_n = atoll(argv[i]);
    }
    heap_init(semi);
    pthread_attr_t attr; pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, (size_t)1 << 30);
    pthread_t th;
    if (pthread_create(&th, &attr, run, NULL)) die("pthread_create");
    pthread_join(th, NULL);
    double share = total_cycles ? (double)gc_cycles / (double)total_cycles : 0;
    printf("%s %lld %016llx %llu %llu %.4f\n", kd->name, (long long)arg_n, (unsigned long long)ck_h,
           (unsigned long long)total_cycles, (unsigned long long)gc_cycles, share);
    fprintf(stderr, "# %s %s: gc_count %llu copied %llu MiB semispace %zu MiB\n", LAYOUT_NAME, kd->name,
            (unsigned long long)gc_count, (unsigned long long)(gc_bytes_copied >> 20), semi >> 20);
    if (lazy_forced) {
        /* a lazy kernel: the thunks forced, the indirections the collections
           took out (by reference) and the bytes they held until then, and the
           updates that stored a young value into an old thunk */
        unsigned long long cards = 0;
#ifdef BARRIER_CARD
        for (size_t i = 0; i < sizeof card_table; i++) cards += card_table[i] != 0;
#endif
        fprintf(stderr, "# %s %s: forced %llu ind_out %llu ind_bytes %llu old_to_young %llu cards %llu\n", LAYOUT_NAME, kd->name,
                (unsigned long long)lazy_forced, (unsigned long long)gc_ind_skipped, (unsigned long long)gc_ind_bytes,
                (unsigned long long)lazy_old_to_young, cards);
    }
    return 0;
}
