#include "scalars.h"
int gen_add(int first, int second) { return first + second; }
unsigned int gen_bits(unsigned int bits) { return bits ^ 0x80000000U; }
double gen_real(double value) { return value + 0.25; }
_Bool gen_bool(_Bool value) { return !value; }
