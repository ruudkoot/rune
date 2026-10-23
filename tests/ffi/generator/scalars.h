#ifndef RUNEFFI_GENERATOR_SCALARS_H
#define RUNEFFI_GENERATOR_SCALARS_H
#include "transitive.h"
struct gen_record { int first; double second; };
typedef struct gen_record gen_record;
int gen_add(int first, int second);
unsigned int gen_bits(unsigned int bits);
double gen_real(double value);
_Bool gen_bool(_Bool value);
#endif
