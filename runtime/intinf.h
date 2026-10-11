#ifndef RUNE_INTINF_H
#define RUNE_INTINF_H
#include "vm.h"

enum { INTINF_AUTO, INTINF_SML, INTINF_GMP };
#define INTINF_DEFAULT_BITS ((size_t)134217728)
#define INTINF_DEFAULT_GMP_MEMORY ((size_t)268435456)
/* Even binary formatting plus a sign must fit a Rune string. This also
   leaves room for geometric scanner scratch growth below Array.maxLen. */
#define INTINF_MAX_BITS ((size_t)1073741822)

size_t vm_intinf_max_bits(const VM *vm);
size_t vm_intinf_gmp_memory(const VM *vm);
void vm_intinf_check(VM *vm, uint64_t bits);
int vm_intinf_mode(const char *text, int *mode);
int vm_intinf_available(const VM *vm);
int vm_intinf_configure(VM *vm);
void vm_intinf_version(FILE *out);
void vm_intinf_report(const VM *vm, FILE *out);
/* These return signed magnitude pairs; divmod returns two such pairs.
   Arguments remain rooted by the primitive caller until the result exists. */
Value vm_intinf_binary(VM *vm, unsigned op, int na, Value a, int nb, Value b);
Value vm_intinf_divmod(VM *vm, int floor, int na, Value a, int nb, Value b);
Value vm_intinf_shift(VM *vm, int left, int neg, Value a, uint64_t count);
Value vm_intinf_power(VM *vm, int neg, Value a, uint64_t exponent);
#endif
