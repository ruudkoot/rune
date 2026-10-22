/* Independent C ABI subject for Runeffi. The generator consumes this header
   unchanged; ownership and projections belong to fixture.ffi. */
#ifndef RUNEFFI_FIXTURE_H
#define RUNEFFI_FIXTURE_H
#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
# define RF_EXPORT __declspec(dllexport)
# define RF_STDCALL __stdcall
#else
# define RF_EXPORT __attribute__((visibility("default")))
# define RF_STDCALL
#endif

typedef struct rf_pair { int32_t integer; double fraction; } rf_pair;
typedef union rf_value { uint64_t bits; double real; } rf_value;
typedef struct rf_bits { unsigned low : 3; unsigned high : 5; } rf_bits;
typedef int (*rf_callback)(void *context, int value);

RF_EXPORT int8_t rf_i8(int8_t value);
RF_EXPORT uint8_t rf_u8(uint8_t value);
RF_EXPORT int16_t rf_i16(int16_t value);
RF_EXPORT uint16_t rf_u16(uint16_t value);
RF_EXPORT int32_t rf_i32(int32_t value);
RF_EXPORT uint32_t rf_u32(uint32_t value);
RF_EXPORT int64_t rf_i64(int64_t value);
RF_EXPORT uint64_t rf_u64(uint64_t value);
RF_EXPORT float rf_float(float value);
RF_EXPORT double rf_double(double value);
RF_EXPORT rf_pair rf_make_pair(int32_t integer, double fraction);
RF_EXPORT double rf_pair_total(rf_pair value);
RF_EXPORT size_t rf_length(const char *text);
RF_EXPORT char *rf_copy(const char *text);
RF_EXPORT void rf_free(void *memory);
RF_EXPORT size_t rf_allocations(void);
RF_EXPORT void rf_fail_allocation(int fail);
RF_EXPORT int rf_alias(unsigned char *first, unsigned char *second);
RF_EXPORT void rf_set_callback(rf_callback callback, void *context);
RF_EXPORT int rf_invoke(int value);
RF_EXPORT int rf_error(int error);
RF_EXPORT int rf_variadic(unsigned count, ...);
RF_EXPORT double rf_variadic_real(unsigned count, ...);
RF_EXPORT int RF_STDCALL rf_stdcall_add(int left, int right);

#define RF_MAGIC (0x1200U | 0x34U)
#define RF_LOW(value) ((unsigned)(value) & 0xffU)
static inline int rf_inline_twice(int value) { return value * 2; }
#endif
