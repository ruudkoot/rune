/* Exercise the real hooks, with failure confined to this translation unit.
   The VM heap continues to use the ordinary allocator. */
#include "vm.h"
static int fail_malloc, fail_realloc;
static void *test_malloc(size_t n) { return fail_malloc ? NULL : malloc(n); }
static void *test_realloc(void *p, size_t n) { return fail_realloc ? NULL : realloc(p, n); }
#define malloc test_malloc
#define realloc test_realloc
#include "../../runtime/intinf.c"
#undef malloc
#undef realloc

int main(int argc, char **argv) {
#if defined(RUNE_HAVE_GMP) && RUNE_HAVE_GMP
    VM vm = {0};
    vm.intinf_mode = INTINF_GMP;
    vm.intinf_gmp_memory = 32;
    fail_malloc = argc > 1 && strcmp(argv[1], "malloc") == 0;
    fail_realloc = argc > 1 && strcmp(argv[1], "realloc") == 0;
    enter(&vm);
    void *p = allocate(8);
    p = resize(p, 8, 16);
    p = resize(p, 16, 4);
    release(p, 4);
    p = allocate(0);
    p = resize(p, 0, 0);
    release(p, 0);
    leave(&vm);
    if (vm.intinf_gmp_live != 0 || vm.intinf_gmp_peak != 16 || vm.intinf_gmp_allocations != 5) return 1;
    puts("GMP allocation hooks pass");
    return 0;
#else
    (void)argc; (void)argv;
    puts("GMP allocation hooks unavailable");
    return 77;
#endif
}
