/* main.c -- gcbench SUBCOMMAND [NAME=VALUE ...]: one experiment of
   docs/plans/garbage-collector-v2.md (H1-H10), its rows on stdout as TSV
   (gcb.h, out_row), a comment line per configuration on stderr; or one of
   the two tools beside them, mktrace (a synthetic census trace) and
   alloc-test (alloc.h against its closed forms and a shadow heap). The
   experiment runs on a thread with a 1 GiB stack (the recursive builders
   go deep). check=1 turns on every check the experiment has, and the exit
   status is 1 if one failed. README.md says what each subcommand measures. */
#include "gcb.h"
#include <pthread.h>
/* one translation unit: gcb.h's counters and options are static */
#include "h1.c"
#include "h2.c"
#include "h3.c"
#include "h5.c"
#include "h6.c"
#include "h7.c"
#include "h8.c"
#include "h9.c"
#include "h10.c"
static const struct { const char *name; exp_fn fn; const char *what; } exps[] = {
    { "h1",  exp_h1,  "nursery size against the caches, lifetimes from a census trace" },
    { "h2",  exp_h2,  "copy and mark cost per object and per byte" },
    { "h3",  exp_h3,  "mark bits in the header or a bitmap: clearing and sweeping" },
    { "h5",  exp_h5,  "allocators replaying a trace: fragmentation and the traversal after" },
    { "h6",  exp_h6,  "write barriers on four kernels" },
    { "h7",  exp_h7,  "placement order and the mutator" },
    { "h8",  exp_h8,  "stack scanning: per slot and per frame with the liveness lookup" },
    { "h9",  exp_h9,  "pages: first touch, mmap/munmap, madvise, huge pages" },
    { "h10", exp_h10, "latency chain and bandwidth baselines" },
    { "mktrace", exp_mktrace, "write a synthetic census trace (for check.sh; not a workload)" },
    { "alloc-test", exp_alloc_test, "alloc.h's allocators against their closed forms and a shadow heap" },
};

static exp_fn chosen;
static const char *chosen_name;
/* the counters count the thread that opens them: the experiment's */
static void *run(void *p) {
    (void)p;
    pc_init();
    fprintf(stderr, "# gcbench %s: tsc %.3f GHz, counters %s, events %s%s\n", chosen_name, tsc_ghz, pc_ok ? "rdpmc" : "none",
            pc_set_name(), gcb_check ? ", checks on" : "");
    chosen();
    return NULL;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: gcbench SUBCOMMAND [NAME=VALUE ...] [check=1]   (GCB_EV=mem|l2|br|tlb|none picks the four events)\n");
        for (size_t i = 0; i < sizeof exps / sizeof exps[0]; i++) fprintf(stderr, "  %-10s %s\n", exps[i].name, exps[i].what);
        return 2;
    }
    for (size_t i = 0; i < sizeof exps / sizeof exps[0]; i++) if (!strcmp(exps[i].name, argv[1])) { chosen = exps[i].fn; chosen_name = exps[i].name; }
    if (!chosen) die("unknown subcommand");
    g_argc = argc - 2; g_argv = argv + 2;
    gcb_check = (int)opt_n("check", 0);
    pthread_attr_t attr; pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, (size_t)1 << 30);
    pthread_t th;
    if (pthread_create(&th, &attr, run, NULL)) die("pthread_create");
    pthread_join(th, NULL);
    if (gcb_check) fprintf(stderr, "# gcbench %s: %lu checks failed\n", chosen_name, gcb_failures);
    return gcb_failures ? 1 : 0;
}
