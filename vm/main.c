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
        "  --emulate-fork  fork as on Windows, which has none: by a second runevm that\n"
        "                  is handed this one's state (testing that path)\n"
        "  --resume TOKEN  carry on as the child of such a fork; runevm gives this itself\n"
        "  --version       print the version and exit\n");
}

/* Also for a VM that an image was read into only in part (vm_resume). */
static void vm_destroy(VM *vm) {
    for (uint32_t i = 0; vm->prog.funcs && i < vm->prog.nfuncs; i++) free(vm->prog.funcs[i].name);
    free(vm->prog.funcs);
    free(vm->prog.consts);
    free(vm->prog.code);
    free(vm->globals);
    free(vm->global_set);
    free(vm->stack);
    free(vm->frames);
    free(vm->handlers);
    free(vm->heap_from);
    for (size_t i = 3; i < vm->nfiles; i++) if (vm->files[i]) fclose(vm->files[i]);
    free(vm->files);
    free(vm->file_modes);
    if (vm->owns_args) {
        for (int i = 0; vm->argv && i < vm->argc; i++) free(vm->argv[i]);
        free(vm->argv);
        free((char *)vm->progname);
    }
    free(vm);
}

void vm_exit(VM *vm, int status) {
    fflush(stdout);
    if (vm->count)
        fprintf(stderr, "runevm: count: %llu instructions, %llu bytes, %llu objects\n",
                (unsigned long long)vm->instructions, (unsigned long long)vm->bytes_allocated,
                (unsigned long long)vm->objects_allocated);
    if (vm->stats)
        fprintf(stderr, "runevm: %zu collections, %llu bytes allocated, semispace %zu bytes, %zu live\n",
                vm->gc_count, (unsigned long long)vm->bytes_allocated, vm->heap_size, vm->heap_used);
    fflush(stderr);
    vm_destroy(vm);
    exit(status);
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
    size_t heap = 4u << 20, gc_stress = 0;
    int disasm = 0, trace = 0, stats = 0, count = 0, emulate_fork = 0;
    const char *resume = NULL;
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
        else if (strcmp(argv[i], "--resume") == 0 && i + 1 < argc) resume = argv[++i];
        else if (strcmp(argv[i], "--gc-stress") == 0 && i + 1 < argc) {
            if (!size_arg(argv[++i], &gc_stress) || gc_stress == 0) { usage(); return 2; }
        }
        else if (strcmp(argv[i], "--version") == 0) { printf("runevm %s\n", RUNE_VERSION); return 0; }
        else if (strcmp(argv[i], "--help") == 0) { usage(); return 0; }
        else if (argv[i][0] == '-' && argv[i][1] != 0) { usage(); return 2; }
        else break;
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
        vm_exit(vm, vm_loop(vm));   /* does not return */
    }
    if (i >= argc) { usage(); return 2; }

    VM *vm = calloc(1, sizeof(VM));
    vm->trace = trace;
    vm->stats = stats;
    vm->count = count;
    vm->gc_stress = gc_stress;
    vm->emulate_fork = emulate_fork;
    vm->progname = argv[i];
    vm->argc = argc - i - 1;
    vm->argv = argv + i + 1;
    vm->files_cap = 8;
    vm->files = calloc(vm->files_cap, sizeof(FILE *));
    vm->file_modes = calloc(vm->files_cap, 1);
    vm->files[0] = stdin; vm->files[1] = stdout; vm->files[2] = stderr;
    vm->file_modes[1] = vm->file_modes[2] = 1;
    vm->nfiles = 3;
    heap_init(vm, heap);

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
