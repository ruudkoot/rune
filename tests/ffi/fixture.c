#include "fixture.h"
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
# include <windows.h>
#endif

#define RF_ECHO(type, name) type name(type value) { return value; }
RF_ECHO(int8_t, rf_i8)
RF_ECHO(uint8_t, rf_u8)
RF_ECHO(int16_t, rf_i16)
RF_ECHO(uint16_t, rf_u16)
RF_ECHO(int32_t, rf_i32)
RF_ECHO(uint32_t, rf_u32)
RF_ECHO(int64_t, rf_i64)
RF_ECHO(uint64_t, rf_u64)
RF_ECHO(float, rf_float)
RF_ECHO(double, rf_double)

rf_pair rf_make_pair(int32_t integer, double fraction) {
    rf_pair value = {integer, fraction};
    return value;
}
double rf_pair_total(rf_pair value) { return value.integer + value.fraction; }
size_t rf_length(const char *text) { return strlen(text); }
static size_t allocations;
static int fail_allocation;
char *rf_copy(const char *text) {
    if (fail_allocation) { errno = ENOMEM; return NULL; }
    size_t length = strlen(text) + 1;
    char *copy = malloc(length);
    if (copy) { memcpy(copy, text, length); allocations++; }
    return copy;
}
void rf_free(void *memory) {
    if (memory) { free(memory); allocations--; }
    /* A caller must capture the foreign error before running a deallocator. */
    errno = ERANGE;
#if defined(_WIN32)
    SetLastError(ERROR_INVALID_PARAMETER);
#endif
}
size_t rf_allocations(void) { return allocations; }
void rf_fail_allocation(int fail) { fail_allocation = fail; }
int rf_alias(unsigned char *first, unsigned char *second) {
    first[0] = 17;
    second[0] = (unsigned char)(first[0] + 1);
    return first[1];
}
static rf_callback retained;
static void *retained_context;
void rf_set_callback(rf_callback callback, void *context) {
    retained = callback;
    retained_context = context;
}
int rf_invoke(int value) { return retained ? retained(retained_context, value) : -1; }
int rf_error(int error) {
    errno = error;
#if defined(_WIN32)
    SetLastError((DWORD)error);
#endif
    return -1;
}
int rf_variadic(unsigned count, ...) {
    va_list args;
    va_start(args, count);
    int total = 0;
    for (unsigned i = 0; i < count; i++) total += va_arg(args, int);
    va_end(args);
    return total;
}
double rf_variadic_real(unsigned count, ...) {
    va_list args;
    va_start(args, count);
    double total = 0;
    for (unsigned i = 0; i < count; i++) total += va_arg(args, double);
    va_end(args);
    return total;
}
int RF_STDCALL rf_stdcall_add(int left, int right) { return left + right; }
