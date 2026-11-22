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
uint64_t vm_intinf_validate(VM *vm, Value magnitude, int negative);
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
/* Decimal digits of an unsigned magnitude; SML supplies any sign. */
Value vm_intinf_decimal(VM *vm, Value a);

/* IntInf.int (haskell98 M31): an immediate where the number fits the word's
   63 bits, otherwise a K_TUPLE (negative, magnitude) of a bool and a
   canonical little-endian magnitude string larger than any immediate's.
   These are the slow paths of its primitives (runtime/prims.c), which pass
   the name of the primitive for a message. Arguments stay rooted by the
   primitive's caller; what is wrong with one is a bytecode error. */
enum { INTINF_ADD, INTINF_SUB, INTINF_MUL, INTINF_QUOT, INTINF_REM, INTINF_DIV, INTINF_MOD };
/* the operation on two IntInf.int values; for a division the caller has
   raised Div for a zero divisor */
Value vm_intinf_arith(VM *vm, unsigned op, Value a, Value b, const char *prim);
/* -1, 0 or 1 */
int vm_intinf_compare(VM *vm, Value a, Value b, const char *prim);
Value vm_intinf_negate(VM *vm, Value a, const char *prim);
Value vm_intinf_of_int64(VM *vm, int64_t i);
/* 1 and *out where the number fits 64 bits */
int vm_intinf_to_int64(VM *vm, Value a, int64_t *out, const char *prim);
int vm_intinf_is_zero(VM *vm, Value a, const char *prim);
/* whether a valid value is an immediate */
int vm_intinf_check_value(VM *vm, Value a, const char *prim);
/* the magnitude string of an immediate's number */
Value vm_intinf_magnitude_of_small(VM *vm, int64_t i);
/* 1 and *small where a sign and a canonical magnitude, within the
   budget, are a number an immediate holds */
int vm_intinf_fits(VM *vm, int neg, Value magnitude, int64_t *small, const char *prim);
#endif
