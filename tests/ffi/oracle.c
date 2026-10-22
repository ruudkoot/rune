/* Direct C is the semantic oracle; optional libffi calls verify the selected
   ABI engine independently of Rune's marshalling and VM transitions. */
#include "fixture.h"
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>
#if defined(RUNEFFI_TEST_LIBFFI)
# include <ffi.h>
#endif

static unsigned checks;
static int failed;
#define CHECK(label, condition) do { checks++; if (!(condition)) { \
    fprintf(stderr, "FAIL ffi/oracle/%s at %d\n", label, __LINE__); failed = 1; } } while (0)
#define RF_ALIGNMENT(type) _Alignof(type)

static int callback(void *context, int value) { return *(int *)context + value; }
static int nested(void *context, int value) {
    int base = *(int *)context;
    rf_set_callback(callback, context);
    return rf_invoke(value) + base;
}

#if defined(RUNEFFI_TEST_LIBFFI)
static void closure(ffi_cif *cif, void *result, void **args, void *context) {
    (void)cif;
    *(ffi_arg *)result = (ffi_arg)callback(context, *(int *)args[0]);
}
static void foreign(void) {
    ffi_cif cif;
    ffi_type *one[] = {&ffi_type_sint64};
    int64_t input = INT64_MIN, output = 0;
    void *args[] = {&input};
    CHECK("prepare-i64", ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_sint64, one) == FFI_OK);
    ffi_call(&cif, FFI_FN(rf_i64), &output, args);
    CHECK("ffi-i64-min", output == INT64_MIN);

    ffi_type *fields[] = {&ffi_type_sint32, &ffi_type_double, NULL};
    ffi_type pair = {0, 0, FFI_TYPE_STRUCT, fields};
    ffi_type *types[] = {&ffi_type_sint32, &ffi_type_double};
    int32_t integer = 39;
    double fraction = 3.5;
    void *pair_args[] = {&integer, &fraction};
    rf_pair result;
    CHECK("prepare-pair", ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &pair, types) == FFI_OK);
    ffi_call(&cif, FFI_FN(rf_make_pair), &result, pair_args);
    CHECK("ffi-pair-result", result.integer == 39 && result.fraction == 3.5);
    size_t offsets[2];
    CHECK("ffi-offsets", ffi_get_struct_offsets(FFI_DEFAULT_ABI, &pair, offsets) == FFI_OK);
    CHECK("ffi-pair-layout", pair.size == sizeof(rf_pair) && pair.alignment == RF_ALIGNMENT(rf_pair)
          && offsets[0] == offsetof(rf_pair, integer) && offsets[1] == offsetof(rf_pair, fraction));
    ffi_type *pair_type[] = {&pair};
    void *value_args[] = {&result};
    double total = 0;
    CHECK("prepare-pair-argument", ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_double, pair_type) == FFI_OK);
    ffi_call(&cif, FFI_FN(rf_pair_total), &total, value_args);
    CHECK("ffi-pair-argument", total == 42.5);

    ffi_type *var_types[] = {&ffi_type_uint, &ffi_type_sint, &ffi_type_sint, &ffi_type_sint};
    unsigned count = 3;
    int a = 3, b = 14, c = 25;
    void *var_args[] = {&count, &a, &b, &c};
    ffi_arg answer = 0;
    CHECK("prepare-varargs", ffi_prep_cif_var(&cif, FFI_DEFAULT_ABI, 1, 4, &ffi_type_sint, var_types) == FFI_OK);
    ffi_call(&cif, FFI_FN(rf_variadic), &answer, var_args);
    CHECK("ffi-varargs", (int)answer == 42);

    ffi_type *callback_types[] = {&ffi_type_sint};
    int base = 37;
    void *entry = NULL;
    ffi_closure *code = ffi_closure_alloc(sizeof *code, &entry);
    CHECK("closure-allocation", code != NULL);
    if (code) {
        CHECK("prepare-callback", ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_sint, callback_types) == FFI_OK);
        CHECK("closure-preparation", ffi_prep_closure_loc(code, &cif, closure, &base, entry) == FFI_OK);
        int (*invoke)(int) = NULL;
        /* ISO C does not convert data/function pointers. memcpy also makes
           this ABI assumption explicit in the independent subject. */
        CHECK("function-pointer-size", sizeof invoke == sizeof entry);
        if (sizeof invoke == sizeof entry) {
            memcpy(&invoke, &entry, sizeof invoke);
            CHECK("ffi-closure", invoke(5) == 42);
        }
        ffi_closure_free(code);
    }
}
#endif

int main(void) {
    const unsigned endian = 1;
    CHECK("i8", rf_i8(INT8_MIN) == INT8_MIN && rf_i8(INT8_MAX) == INT8_MAX);
    CHECK("u8", rf_u8(UINT8_MAX) == UINT8_MAX);
    CHECK("i16", rf_i16(INT16_MIN) == INT16_MIN && rf_i16(INT16_MAX) == INT16_MAX);
    CHECK("u16", rf_u16(UINT16_MAX) == UINT16_MAX);
    CHECK("i32", rf_i32(INT32_MIN) == INT32_MIN && rf_i32(INT32_MAX) == INT32_MAX);
    CHECK("u32", rf_u32(UINT32_MAX) == UINT32_MAX);
    CHECK("i64", rf_i64(INT64_MIN) == INT64_MIN && rf_i64(INT64_MAX) == INT64_MAX);
    CHECK("u64", rf_u64(UINT64_MAX) == UINT64_MAX);
    CHECK("float", rf_float(0.25f) == 0.25f);
    CHECK("double", rf_double(0.125) == 0.125);
    CHECK("pair", rf_pair_total(rf_make_pair(39, 3.5)) == 42.5);
    CHECK("constants", RF_MAGIC == 0x1234U && RF_LOW(0x1234U) == 0x34U);
    CHECK("inline", rf_inline_twice(21) == 42);
    unsigned char bytes[3] = {0, 0, 0};
    CHECK("alias", rf_alias(bytes, bytes + 1) == 18 && bytes[0] == 17 && bytes[1] == 18);
    char *copy = rf_copy("owned");
    CHECK("owned-string", copy && rf_length(copy) == 5 && strcmp(copy, "owned") == 0 && rf_allocations() == 1);
    rf_free(copy);
    CHECK("free", rf_allocations() == 0);
    rf_fail_allocation(1);
    errno = 0;
    CHECK("allocation-failure", rf_copy("no") == NULL && errno == ENOMEM && rf_allocations() == 0);
    rf_fail_allocation(0);
    int base = 20;
    rf_set_callback(callback, &base);
    CHECK("callback", rf_invoke(22) == 42);
    rf_set_callback(nested, &base);
    CHECK("nested-callback", rf_invoke(2) == 42);
    rf_set_callback(NULL, NULL);
    CHECK("callback-release", rf_invoke(0) == -1);
    CHECK("variadic", rf_variadic(3, (signed char)3, (short)14, 25) == 42);
    CHECK("variadic-float", rf_variadic_real(3, (float)0.5, 1.25, 2.0) == 3.75);
    CHECK("stdcall", rf_stdcall_add(19, 23) == 42);
    int error_result = rf_error(ENOENT), captured = errno;
    rf_free(NULL);
    CHECK("captured-error", error_result == -1 && captured == ENOENT && errno == ERANGE);
#if defined(RUNEFFI_TEST_LIBFFI)
    foreign();
#endif
    printf("{\"byteOrder\":\"%s\",\"charSigned\":%s,\"char\":%zu,\"short\":%zu,\"int\":%zu,\"long\":%zu,\"longLong\":%zu,\"pointer\":%zu,"
           "\"size\":%zu,\"wchar\":%zu,\"doubleAlign\":%zu,\"pairSize\":%zu,\"pairAlign\":%zu,\"pairFraction\":%zu}\n",
           *(const unsigned char *)&endian ? "little" : "big", CHAR_MIN < 0 ? "true" : "false",
           sizeof(char), sizeof(short), sizeof(int), sizeof(long), sizeof(long long), sizeof(void *),
           sizeof(size_t), sizeof(wchar_t), (size_t)RF_ALIGNMENT(double), sizeof(rf_pair),
           (size_t)RF_ALIGNMENT(rf_pair), offsetof(rf_pair, fraction));
    if (!failed) printf("PASS ffi/oracle: %u checks\n", checks);
    return failed;
}
