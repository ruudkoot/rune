/* Owned adapter oracle declarations. Including these before generated
   definitions makes the C compiler check every emitted prototype. */
#ifndef RUNEFFI_SHIM_FIXTURE_H
#define RUNEFFI_SHIM_FIXTURE_H
#include "fixture.h"
typedef struct rf_pointer_record { void *value; rf_callback callback; } rf_pointer_record;
#pragma pack(push,1)
typedef struct rf_packed_bits { unsigned char prefix; unsigned low:3; unsigned high:5; unsigned char tail; } rf_packed_bits;
#pragma pack(pop)
RF_EXPORT void runeffi_pair_make(rf_pair *, int32_t, double);
RF_EXPORT double runeffi_pair_total(rf_pair *);
RF_EXPORT unsigned runeffi_low(unsigned);
RF_EXPORT int runeffi_twice(int);
RF_EXPORT int runeffi_variadic_sum(unsigned, short, signed char);
RF_EXPORT double runeffi_variadic_real(unsigned, float, float);
RF_EXPORT unsigned runeffi_bits_low_get(const rf_bits *);
RF_EXPORT void runeffi_bits_low_set(rf_bits *, unsigned);
RF_EXPORT unsigned runeffi_bits_high_get(const rf_bits *);
RF_EXPORT void runeffi_bits_high_set(rf_bits *, unsigned);
RF_EXPORT uint64_t runeffi_value_bits_get(const rf_value *);
RF_EXPORT void runeffi_value_bits_set(rf_value *, uint64_t);
RF_EXPORT double runeffi_value_real_get(const rf_value *);
RF_EXPORT void runeffi_value_real_set(rf_value *, double);
RF_EXPORT void *runeffi_pointer_value_get(const rf_pointer_record *);
RF_EXPORT void runeffi_pointer_value_set(rf_pointer_record *, void *);
RF_EXPORT rf_callback runeffi_pointer_callback_get(const rf_pointer_record *);
RF_EXPORT void runeffi_pointer_callback_set(rf_pointer_record *, rf_callback);
RF_EXPORT unsigned runeffi_packed_low_get(const rf_packed_bits *);
RF_EXPORT void runeffi_packed_low_set(rf_packed_bits *, unsigned);
RF_EXPORT unsigned runeffi_packed_high_get(const rf_packed_bits *);
RF_EXPORT void runeffi_packed_high_set(rf_packed_bits *, unsigned);
RF_EXPORT unsigned char runeffi_packed_prefix_get(const rf_packed_bits *);
RF_EXPORT void runeffi_packed_prefix_set(rf_packed_bits *, unsigned char);
RF_EXPORT unsigned char runeffi_packed_tail_get(const rf_packed_bits *);
RF_EXPORT void runeffi_packed_tail_set(rf_packed_bits *, unsigned char);
#endif
