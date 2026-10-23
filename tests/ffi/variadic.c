/* Independent subject: fixed narrow arguments, all scalar register classes,
   stack spills and callbacks while a native va_list remains live. */
#include "variadic.h"
#include <stdarg.h>
double rf_variadic_mixed(float head, int8_t small, unsigned count, ...) {
    va_list arguments;
    va_start(arguments, count);
    double total = head + small;
    for (unsigned i = 0; i < count; i++) {
        int integer = va_arg(arguments, int);
        double real = va_arg(arguments, double);
        int64_t signed_wide = va_arg(arguments, int64_t);
        uint64_t unsigned_wide = va_arg(arguments, uint64_t);
        int32_t *pointer = va_arg(arguments, int32_t *);
        rf_callback callback = va_arg(arguments, rf_callback);
        void *context = va_arg(arguments, void *);
        if (signed_wide != -INT64_C(0x123456789abcdef) || unsigned_wide != UINT64_C(0xfedcba9876543210)) {
            va_end(arguments);
            return -9999.0;
        }
        total += integer + real + *pointer + callback(context, integer);
    }
    va_end(arguments);
    return total;
}
