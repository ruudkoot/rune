/* Independent retained-prefix fixture: uses a real static libffi call. */
#include <ffi.h>
#include <stdio.h>
static int answer(void) { return 42; }
int main(int argc, char **argv) {
    ffi_cif cif;
    ffi_arg result = 0;
    (void)argv;
    if (argc > 1) { puts("Rune FFI relink fixture"); return 0; }
    if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 0, &ffi_type_sint, NULL) != FFI_OK) return 2;
    ffi_call(&cif, FFI_FN(answer), &result, NULL);
    if (result != 42) return 3;
    puts("PASS retained libffi static call");
    return 0;
}
