/* runevm: portable interpreter for Rune bytecode. */
#include "version.h"
#include "vm.h"

#include <errno.h>

static void usage(void) {
    fprintf(stderr,
        "usage: runevm [options] file.rbc [args ...]\n"
        "  --heap-size N   initial semispace size in bytes (default 4194304)\n"
        "  --disasm        print the bytecode and exit\n"
        "  --trace         trace every instruction to stderr\n"
        "  --stats         print heap statistics to stderr at exit\n"
        "  --count         print instructions executed and bytes and objects allocated\n"
        "                  to stderr at exit; the same for every run of a program\n"
        "  --gc-stress N   collect before every Nth allocation (testing the collector\n"
        "                  and the primitives' handling of heap pointers)\n"
        "  --heap-fill P   grow the heap until at most P percent of it is in use after\n"
        "                  a collection, 1 to 100 (default 50)\n"
        "  --checked       DECON tests the tag it is given, which a match that names\n"
        "                  every constructor leaves untested (for testing the compiler)\n"
        "  --emulate-fork  fork as on Windows, which has none: by a second runevm that\n"
        "                  is handed this one's state (testing that path)\n"
        "  --resume TOKEN  carry on as the child of such a fork; runevm gives this itself\n"
        "  --restore FILE  carry on the world Runtime.save wrote to FILE\n"
        "  --jit=MODE      vm/new: off, baseline, opt or all (docs/plans/jit.md)\n"
        "  --jit-stats     vm/new: what the JIT did, to stderr at exit\n"
        "  --jit-check     vm/new: run a few bytes of code from executable memory and exit\n"
        "  --version       print the version and exit\n");
}

/* A size in bytes or a count: a decimal number that fits a size_t, which is
   32 bits on a 32-bit VM. 0 when the text is not one. */
static int size_arg(const char *text, size_t *out) {
    char *end;
    errno = 0;
    unsigned long long v = strtoull(text, &end, 10);
    if (errno != 0 || end == text || *end != 0 || text[0] == '-' || v > SIZE_MAX) return 0;
    *out = (size_t)v;
    return 1;
}

int main(int argc, char **argv) {
    size_t heap = 4u << 20, gc_stress = 0, heap_fill = 50;
    int disasm = 0, trace = 0, stats = 0, count = 0, emulate_fork = 0, checked = 0;
    int jit_mode = 0, jit_stats = 0, jit_check = 0, jit_given = 0;
    const char *resume = NULL, *restore = NULL;
    int i = 1;
    for (; i < argc; i++) {
        if (strcmp(argv[i], "--heap-size") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &heap)) { usage(); return 2; }
            if (heap < 4096) heap = 4096;
        } else if (strcmp(argv[i], "--disasm") == 0) disasm = 1;
        else if (strcmp(argv[i], "--trace") == 0) trace = 1;
        else if (strcmp(argv[i], "--stats") == 0) stats = 1;
        else if (strcmp(argv[i], "--count") == 0) count = 1;
        else if (strcmp(argv[i], "--emulate-fork") == 0) emulate_fork = 1;
        else if (strcmp(argv[i], "--checked") == 0) checked = 1;
        else if (strcmp(argv[i], "--resume") == 0 && i + 1 < argc) resume = argv[++i];
        else if (strcmp(argv[i], "--restore") == 0 && i + 1 < argc) restore = argv[++i];
        else if (strcmp(argv[i], "--gc-stress") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &gc_stress) || gc_stress == 0) { usage(); return 2; }
        }
        else if (strcmp(argv[i], "--heap-fill") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &heap_fill) || heap_fill < 1 || heap_fill > 100) { usage(); return 2; }
        }
        else if (strncmp(argv[i], "--jit", 5) == 0) {
            if (!vm_jit_arg(argv[i], &jit_mode, &jit_stats, &jit_check)) { usage(); return 2; }
            if (strncmp(argv[i], "--jit=", 6) == 0) jit_given = 1;
        }
        else if (strcmp(argv[i], "--version") == 0) { printf("runevm %s\n", RUNE_VERSION); return 0; }
        else if (strcmp(argv[i], "--help") == 0) { usage(); return 0; }
        else if (argv[i][0] == '-' && argv[i][1] != 0) { usage(); return 2; }
        else break;
    }
    /* RUNEVM_JIT names the mode where no --jit= does: for the test runners,
       which start a VM they cannot give options (vm/new; docs/bytecode.md) */
    if (!jit_given && getenv("RUNEVM_JIT") && !vm_jit_env(getenv("RUNEVM_JIT"), &jit_mode)) return 2;
    if (jit_check) return vm_jit_check();
    if (restore) {
        /* a world Runtime.save wrote: it carries on from that call, which
           gives it `Restored` */
        VM *vm = calloc(1, sizeof(VM));
        char err[256];
        if (!vm || !vm_restore(vm, restore, err, sizeof err)) {
            fprintf(stderr, "runevm: --restore: %s\n", vm ? err : "out of memory");
            if (vm) vm_destroy(vm);
            return 2;
        }
        vm->checked = checked;
        vm->jit_mode = jit_mode;
        vm->jit_stats = jit_stats;
        vm_exit(vm, vm_loop(vm));   /* does not return */
    }
    if (resume) {
        /* the child of a fork by a second VM: its state, flags included, is
           the parent's, and it carries on where the parent forked */
        VM *vm = calloc(1, sizeof(VM));
        char err[256];
        if (!vm || !vm_resume(vm, resume, err, sizeof err)) {
            fprintf(stderr, "runevm: --resume: %s\n", vm ? err : "out of memory");
            if (vm) vm_destroy(vm);
            return 2;
        }
        vm->jit_mode = jit_mode;
        vm->jit_stats = jit_stats;
        vm_exit(vm, vm_loop(vm));   /* does not return */
    }
    if (i >= argc) { usage(); return 2; }

    VM *vm = calloc(1, sizeof(VM));
    vm->trace = trace;
    vm->stats = stats;
    vm->count = count;
    vm->gc_stress = gc_stress;
    vm->emulate_fork = emulate_fork;
    vm->checked = checked;
    vm->jit_mode = jit_mode;
    vm->jit_stats = jit_stats;
    vm->progname = argv[i];
    vm->argc = argc - i - 1;
    vm->argv = argv + i + 1;
    vm_init(vm, heap);
    vm->heap_fill = (unsigned)heap_fill;

    char err[256];
    if (!load_program(vm, argv[i], err, sizeof err)) {
        fprintf(stderr, "runevm: %s: %s\n", argv[i], err);
        vm_destroy(vm);
        return 2;
    }
    if (disasm) { disassemble(&vm->prog, stdout); vm_destroy(vm); return 0; }

    vm_exit(vm, vm_run(vm));   /* does not return */
    return 0;
}
