/* Admission probe for the pinned static libffi. Run by the configured target
   runner before publishing the prefix; no Rune runtime is involved. */
#include <ffi.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#ifndef RUNE_FFI_EXPECT_POINTER
#define RUNE_FFI_EXPECT_POINTER 0
#endif
#ifndef RUNE_FFI_EXPECT_BIG_ENDIAN
#define RUNE_FFI_EXPECT_BIG_ENDIAN -1
#endif
struct pair { int32_t integer; double fraction; };
static int sum(int a, int b) { return a+b; }
static struct pair aggregate(int32_t integer, double fraction) {
    struct pair result; result.integer=integer; result.fraction=fraction; return result;
}
static void closure(ffi_cif *cif, void *result, void **arguments, void *context) {
    (void)cif; *(ffi_arg *)result=(ffi_arg)(*(int *)context+*(int *)arguments[0]);
}
int main(void) {
    ffi_cif cif; ffi_type *types[]={&ffi_type_sint,&ffi_type_sint};
    int a=20,b=22; void *values[]={&a,&b}; ffi_arg result=0;
    const unsigned endian=1;
    if (RUNE_FFI_EXPECT_POINTER && sizeof(void *)!=RUNE_FFI_EXPECT_POINTER) return 1;
    if (RUNE_FFI_EXPECT_BIG_ENDIAN>=0 && ((const unsigned char *)&endian)[0]!=(RUNE_FFI_EXPECT_BIG_ENDIAN?0:1)) return 2;
    if (ffi_prep_cif(&cif,FFI_DEFAULT_ABI,2,&ffi_type_sint,types)!=FFI_OK) return 3;
    ffi_call(&cif,FFI_FN(sum),&result,values); if ((int)result!=42) return 4;
    {
        ffi_type *fields[]={&ffi_type_sint32,&ffi_type_double,NULL};
        ffi_type pair={0,0,FFI_TYPE_STRUCT,fields};
        ffi_type *arguments[]={&ffi_type_sint32,&ffi_type_double};
        int32_t integer=-37; double fraction=0.5; void *input[]={&integer,&fraction}; struct pair output;
        size_t offsets[2];
        if (ffi_prep_cif(&cif,FFI_DEFAULT_ABI,2,&pair,arguments)!=FFI_OK) return 5;
        if (ffi_get_struct_offsets(FFI_DEFAULT_ABI,&pair,offsets)!=FFI_OK || pair.size!=sizeof output || offsets[1]!=offsetof(struct pair,fraction)) return 6;
        ffi_call(&cif,FFI_FN(aggregate),&output,input);
        if (output.integer!=-37 || output.fraction!=0.5) return 7;
    }
    {
        ffi_type *arguments[]={&ffi_type_sint}; void *entry=NULL; int base=37;
        ffi_closure *code=ffi_closure_alloc(sizeof *code,&entry); int (*function)(int)=NULL;
        if (!code || sizeof function!=sizeof entry) return 8;
        if (ffi_prep_cif(&cif,FFI_DEFAULT_ABI,1,&ffi_type_sint,arguments)!=FFI_OK ||
            ffi_prep_closure_loc(code,&cif,closure,&base,entry)!=FFI_OK) return 9;
        /* Also tests descriptor-based function pointers on big-endian ELFv1. */
        memcpy(&function,&entry,sizeof function); if (function(5)!=42) return 10;
        ffi_closure_free(code);
    }
    puts("PASS pinned libffi admission: widths, endian, scalar, aggregate, closure and function pointer");
    return 0;
}
