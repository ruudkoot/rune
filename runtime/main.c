/* runevm: portable interpreter for Rune bytecode. */
#include "version.h"
#include "vm.h"
#ifdef RUNE_CENSUS
#include "register/jit.h"
#endif

#include <errno.h>

static void usage(void) {
    fprintf(stderr,
        "usage: runevm [options] file.rbc [args ...]\n"
        "  --heap-size N   initial semispace size in bytes (default 4194304)\n"
        "  --heap-limit N  maximum semispace size in bytes, at least 4096 (unlimited by default)\n"
        "  --equality-work N  maximum steps per structural comparison (default 1000000)\n"
        "  --stack-size N  the most bytes the stack may grow to (default 1073741824): a\n"
        "                  recursion without end stops here, not at the machine's memory\n"
        "  --disasm        print the bytecode and exit\n"
        "  --trace         trace every instruction to stderr\n"
        "  --stats         print heap statistics to stderr at exit\n"
        "  --count         print instructions executed and bytes and objects allocated\n"
        "                  to stderr at exit; the same for every run of a program\n"
        "  --gc-stress N   collect before every Nth allocation (testing the collector\n"
        "                  and the primitives' handling of heap pointers)\n"
        "  --heap-fill P   grow the heap until at most P percent of it is in use after\n"
        "                  a collection, 1 to 100 (default 50)\n"
        "  --gc-log FILE   write a line about every collection into FILE (docs/runtime.md)\n"
        "  --gc-verify     check the heap before and after every collection (testing the collector)\n"
        "  --checked       DECON tests the tag it is given, which a match that names\n"
        "                  every constructor leaves untested (for testing the compiler)\n"
        "  --emulate-fork  fork as on Windows, which has none: by a second runevm that\n"
        "                  is handed this one's state (testing that path)\n"
        "  --resume TOKEN  carry on as the child of such a fork; runevm gives this itself\n"
        "  --restore FILE  carry on the world Runtime.save wrote to FILE\n"
        "  --jit=MODE      register VM: off, baseline, opt or all (docs/plans/jit.md)\n"
        "  --jit-stats     register VM: what the JIT did, to stderr at exit\n"
        "  --jit-only=SPEC register VM: give code to functions LO-HI, or the odd or even ones, alone\n"
        "  --jit-calls=N, --jit-work=N  register VM: compile a function at its Nth call, or at N iterations of its loops and calls it makes (baseline)\n"
        "  --jit-stress=N  register VM: every Nth call into compiled code invalidates it (a test of invalidation)\n"
        "  --deopt-stress=N  register VM: compiled code leaves for the interpreter at every Nth instruction (a test of the frames' exactness)\n"
        "  --jit-perf-map  register VM: write /tmp/perf-PID.map, so that perf record names compiled functions\n"
        "  --jit-profile   register VM: count what compiled code calls, branches and loops on (--jit-stats shows them)\n"
        "  --jit-check     register VM: run a few bytes of code from executable memory and exit\n"
        "  --version       print the version and exit\n"
#ifdef RUNE_CENSUS
        "  --census-dir DIR     census VM: write the allocation traces of docs/census.md into DIR\n"
        "  --census-every N     census VM: a forced collection every N bytes allocated (default 262144; 0 = none)\n"
        "  --census-fields 0|1  census VM: write fields.bin (default 1)\n"
        "  --census-summary     census VM: no trace files (but pcs.bin) and no per-object arrays: census.txt alone\n"
        "  --census-ids N       census VM: the objects expected, so that the per-object arrays are allocated once\n"
        "  --census-static      census VM: print the static census of the program (docs/census.md) and exit\n"
#endif
        );
}

/* A size in bytes or a count: a decimal number that fits a size_t, which is
   32 bits on a 32-bit VM. 0 when the text is not one. */
static int size_arg(const char *text, size_t *out) {
    char *end;
    errno = 0;
    unsigned long long v = strtoull(text, &end, 10);
    if (errno != 0 || end == text || *end != 0 || text[0] < '0' || text[0] > '9' || v > SIZE_MAX) return 0;
    *out = (size_t)v;
    return 1;
}

int main(int argc, char **argv) {
    size_t heap = 4u << 20, gc_stress = 0, heap_fill = 50, stack = (size_t)1 << 30;
    size_t heap_limit = 0, equality_work = 0;
    int disasm = 0, trace = 0, stats = 0, count = 0, emulate_fork = 0, checked = 0, gc_verify = 0;
    int jit_check = 0, jit_given = 0;
    JitOptions jit;
    memset(&jit, 0, sizeof jit);
    const char *resume = NULL, *restore = NULL, *gc_log = NULL;
#ifdef RUNE_CENSUS
    const char *census_dir = NULL;
    size_t census_every_arg = 262144, census_fields = 1, census_ids = 0;
    int census_summary = 0, census_static_mode = 0;
#endif
    int i = 1;
    for (; i < argc; i++) {
        if (strcmp(argv[i], "--heap-size") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &heap)) { usage(); return 2; }
            if (heap < 4096) heap = 4096;
        } else if (strcmp(argv[i], "--heap-limit") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &heap_limit) || heap_limit < 4096) { usage(); return 2; }
        } else if (strcmp(argv[i], "--equality-work") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &equality_work) || equality_work == 0) { usage(); return 2; }
        } else if (strcmp(argv[i], "--stack-size") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &stack) || stack < 65536) { usage(); return 2; }
        } else if (strcmp(argv[i], "--disasm") == 0) disasm = 1;
        else if (strcmp(argv[i], "--trace") == 0) trace = 1;
        else if (strcmp(argv[i], "--stats") == 0) stats = 1;
        else if (strcmp(argv[i], "--count") == 0) count = 1;
        else if (strcmp(argv[i], "--emulate-fork") == 0) emulate_fork = 1;
        else if (strcmp(argv[i], "--checked") == 0) checked = 1;
        else if (strcmp(argv[i], "--resume") == 0 && i + 1 < argc) resume = argv[++i];
        else if (strcmp(argv[i], "--restore") == 0 && i + 1 < argc) restore = argv[++i];
        else if (strcmp(argv[i], "--gc-log") == 0 && i + 1 < argc) gc_log = argv[++i];
        else if (strcmp(argv[i], "--gc-verify") == 0) gc_verify = 1;
        else if (strcmp(argv[i], "--gc-stress") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &gc_stress) || gc_stress == 0) { usage(); return 2; }
        }
        else if (strcmp(argv[i], "--heap-fill") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &heap_fill) || heap_fill < 1 || heap_fill > 100) { usage(); return 2; }
        }
        else if (strncmp(argv[i], "--jit", 5) == 0 || strncmp(argv[i], "--deopt-stress=", 15) == 0) {
            if (!vm_jit_arg(argv[i], &jit, &jit_check)) { usage(); return 2; }
            if (strncmp(argv[i], "--jit=", 6) == 0) jit_given = 1;
        }
#ifdef RUNE_CENSUS
        else if (strcmp(argv[i], "--census-dir") == 0 && i + 1 < argc) census_dir = argv[++i];
        else if (strcmp(argv[i], "--census-every") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &census_every_arg)) { usage(); return 2; }
        }
        else if (strcmp(argv[i], "--census-fields") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &census_fields) || census_fields > 1) { usage(); return 2; }
        }
        else if (strcmp(argv[i], "--census-summary") == 0) census_summary = 1;
        else if (strcmp(argv[i], "--census-static") == 0) census_static_mode = 1;
        else if (strcmp(argv[i], "--census-ids") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &census_ids)) { usage(); return 2; }
        }
#endif
        else if (strcmp(argv[i], "--version") == 0) { printf("runevm %s\n", RUNE_VERSION); return 0; }
        else if (strcmp(argv[i], "--help") == 0) { usage(); return 0; }
        else if (argv[i][0] == '-' && argv[i][1] != 0) { usage(); return 2; }
        else break;
    }
    /* RUNEVM_JIT names the mode where no --jit= does: for the test runners,
       which start a VM they cannot give options (runtime/register; docs/bytecode.md) */
    if (!jit_given && getenv("RUNEVM_JIT") && !vm_jit_env(getenv("RUNEVM_JIT"), &jit.mode)) return 2;
    /* and RUNEVM_JIT_TIER the tier, where no --jit-tier= does (M9) */
    if (!jit.tier && getenv("RUNEVM_JIT_TIER")) {
        const char *t = getenv("RUNEVM_JIT_TIER");
        if (strcmp(t, "1") == 0) jit.tier = 1;
        else if (strcmp(t, "2") == 0) jit.tier = 2;
        else { fprintf(stderr, "runevm: RUNEVM_JIT_TIER=%s: 1 or 2\n", t); return 2; }
    }
    if (jit_check) return vm_jit_check();
    if (restore) {
        /* a world Runtime.save wrote: it carries on from that call, which
           gives it `Restored` */
        VM *vm = calloc(1, sizeof(VM));
        char err[256];
        if (vm) vm->stack_limit = stack;   /* before the image's stack is made */
        if (vm) { vm->heap_limit = heap_limit; vm->equality_work = equality_work; }
        if (!vm || !vm_restore(vm, restore, err, sizeof err)) {
            fprintf(stderr, "runevm: --restore: %s\n", vm ? err : "out of memory");
            if (vm) vm_destroy(vm);
            return 2;
        }
        vm->checked = checked;
        vm->jit = jit;
        vm->gc_verify = gc_verify;
        if (gc_log) heap_log_open(vm, gc_log);
        vm_exit(vm, vm_loop(vm));   /* does not return */
    }
    if (resume) {
        /* the child of a fork by a second VM: its state, flags included, is
           the parent's, and it carries on where the parent forked */
        VM *vm = calloc(1, sizeof(VM));
        char err[256];
        if (vm) vm->stack_limit = stack;
        if (vm) { vm->heap_limit = heap_limit; vm->equality_work = equality_work; }
        if (!vm || !vm_resume(vm, resume, err, sizeof err)) {
            fprintf(stderr, "runevm: --resume: %s\n", vm ? err : "out of memory");
            if (vm) vm_destroy(vm);
            return 2;
        }
        vm->jit = jit;
        vm_exit(vm, vm_loop(vm));   /* does not return */
    }
    if (i >= argc) { usage(); return 2; }

    VM *vm = calloc(1, sizeof(VM));
    vm->trace = trace;
    vm->stats = stats;
    vm->count = count;
    vm->gc_stress = gc_stress;
    vm->gc_verify = gc_verify;
    vm->emulate_fork = emulate_fork;
    vm->checked = checked;
    vm->jit = jit;
    vm->progname = argv[i];
    vm->argc = argc - i - 1;
    vm->argv = argv + i + 1;
    vm->stack_limit = stack;
    vm->heap_limit = heap_limit;
    vm->equality_work = equality_work;
    vm_init(vm, heap);
    vm->heap_fill = (unsigned)heap_fill;
    if (gc_log) heap_log_open(vm, gc_log);
#ifdef RUNE_CENSUS
    /* the census VM interprets everything: the JIT allocates in line
       (runtime/register/jit/masm.c) with its own idea of the header */
    if (jit.mode != JIT_OFF) fprintf(stderr, "runevm-census: --jit ignored: the interpreter alone runs\n");
    vm->jit.mode = JIT_OFF;
    if (census_dir) census_init(vm, census_dir, (uint64_t)census_every_arg, (int)census_fields, census_summary, (uint64_t)census_ids);
#endif

    char err[256];
    if (!load_program(vm, argv[i], err, sizeof err)) {
        fprintf(stderr, "runevm: %s: %s\n", argv[i], err);
        vm_destroy(vm);
        return 2;
    }
    if (disasm) { disassemble(&vm->prog, stdout); vm_destroy(vm); return 0; }
#ifdef RUNE_CENSUS
    if (census_static_mode) { census_static(&vm->prog, argv[i], stdout); vm_destroy(vm); return 0; }
#endif

    vm_exit(vm, vm_run(vm));   /* does not return */
    return 0;
}
