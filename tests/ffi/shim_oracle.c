#include <stddef.h>
#include <stdio.h>
#include "shim.h"
static int callback(void *context, int value) { return *(int *)context + value; }
int main(void) {
 rf_pair pair; runeffi_pair_make(&pair,42,0.25);
 if (pair.integer!=42 || pair.fraction!=0.25 || runeffi_pair_total(&pair)!=42.25) return 1;
 if (runeffi_low(0x1234)!=0x34 || runeffi_twice(21)!=42) return 2;
 if (runeffi_variadic_sum(2,20,22)!=42 || runeffi_variadic_real(2,0.25f,0.5f)!=0.75) return 7;
 rf_bits bits={0,0}; runeffi_bits_low_set(&bits,7); runeffi_bits_high_set(&bits,31);
 if (bits.low!=7 || bits.high!=31 || runeffi_bits_low_get(&bits)!=7 || runeffi_bits_high_get(&bits)!=31) return 3;
 rf_value value; runeffi_value_real_set(&value,1.0);
 if (runeffi_value_bits_get(&value)!=UINT64_C(0x3ff0000000000000)) return 4;
 runeffi_value_bits_set(&value,UINT64_C(0x4000000000000000));
 if (runeffi_value_real_get(&value)!=2.0) return 5;
 int context=10; rf_pointer_record record={NULL,NULL};
 runeffi_pointer_value_set(&record,&context); runeffi_pointer_callback_set(&record,callback);
 if (runeffi_pointer_value_get(&record)!=&context || runeffi_pointer_callback_get(&record)(&context,32)!=42) return 6;
 rf_packed_bits packed={0,0,0,0};
 runeffi_packed_prefix_set(&packed,0xa5); runeffi_packed_tail_set(&packed,0x5a);
 runeffi_packed_low_set(&packed,7); runeffi_packed_high_set(&packed,31);
 if (packed.low!=7 || packed.high!=31 || packed.prefix!=0xa5 || packed.tail!=0x5a ||
     runeffi_packed_low_get(&packed)!=7 || runeffi_packed_high_get(&packed)!=31 ||
     runeffi_packed_prefix_get(&packed)!=0xa5 || runeffi_packed_tail_get(&packed)!=0x5a) return 8;
 printf("%zu %zu %zu %zu %zu %zu\n",sizeof(rf_pair),offsetof(rf_pair,fraction),sizeof(rf_bits),sizeof(rf_value),sizeof(rf_pointer_record),sizeof(rf_packed_bits));
 return 0;
}
