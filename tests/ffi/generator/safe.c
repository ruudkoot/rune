#include "safe.h"
#include <errno.h>
#include <stdlib.h>
#include <string.h>
static unsigned long allocations;
unsigned long safe_length(const char *text) { return text ? (unsigned long)strlen(text) : 0; }
void *safe_allocate(unsigned long length) {
    void *memory=calloc(1,length);
    if (memory) allocations++;
    return memory;
}
char *safe_copy(const char *text) {
    size_t length=strlen(text)+1;
    char *copy=safe_allocate((unsigned long)length);
    if (copy) memcpy(copy,text,length);
    return copy;
}
const char *safe_optional(int empty) { return empty ? NULL : "borrowed"; }
void safe_free(void *memory) { if (memory) { free(memory); allocations--; } errno=ERANGE; }
unsigned long safe_allocations(void) { return allocations; }
void *safe_identity(void *memory) { return memory; }
void safe_numbers(int *integer, unsigned int *bits, float *fraction) { *integer=-17; *bits=0xf0000000U; *fraction=1.25f; }
void safe_accumulate(int *value) { *value+=9; }
int safe_alias(unsigned char *first, unsigned char *second) { first[0]=17; second[0]=(unsigned char)(first[0]+1); return first[1]; }
void safe_fill(unsigned char *buffer, unsigned long length) { for (unsigned long i=0;i<length;i++) buffer[i]=(unsigned char)(i+1); }
int safe_fail(int code) { errno=code; return -1; }
const char *safe_error_text(void) { return "fixture error"; }
char *safe_callback_owned(safe_callback callback) { (void)callback(7); return safe_copy("callback"); }
void safe_callback_buffer(safe_callback callback, unsigned char *buffer) { buffer[0]=91; (void)callback(1); buffer[1]=92; }
static int preflight_calls;
char *safe_preflight(void) { preflight_calls++; return safe_copy("preflight"); }
int safe_preflight_calls(void) { return preflight_calls; }
void safe_fill_ints(int *buffer) { for (int i=0;i<3;i++) buffer[i]=i+1; }
int safe_sum_ints(const int *buffer, unsigned long length) { int result=0; for (unsigned long i=0;i<length;i++) result+=buffer[i]; return result; }
_Bool safe_call_bool(safe_bool_callback callback) { return callback(1); }
double safe_float_fail(void) { errno=13; return -1.25; }
char *safe_bad_utf8(void) { return safe_copy("\xff"); }

const unsigned short *safe_utf16(void) { static const unsigned short value[]={0x41,0xd83d,0xde00,0}; return value; }
int safe_utf16_input(const unsigned short *text) { return text[0]+text[3]; }

safe_packet safe_transform(safe_packet value, int delta) {
    value.origin.x+=delta; value.origin.y+=0.5f; value.codes[1]+=(unsigned int)delta; value.scale*=2;
    return value;
}
void safe_packet_out(safe_packet *value) { *value=(safe_packet){{8,1.5f},{7,8,9},2.5}; }
void safe_packet_inout(safe_packet *value) { *value=safe_transform(*value,3); }
#if defined(__x86_64__)
__attribute__((ms_abi)) int safe_other_abi(int value) { return value+19; }
#endif

struct safe_registration { safe_registered_callback callback; void *context; };
safe_registration *safe_register(safe_registered_callback callback, void *context) {
    safe_registration *registration=safe_allocate(sizeof *registration);
    if (registration) { registration->callback=callback; registration->context=context; (void)callback(3,context); }
    return registration;
}
safe_registration *safe_register_none(safe_registered_callback callback, void *context) { (void)callback(3,context); return NULL; }
int safe_dispatch(safe_registration *registration, int value) { return registration->callback(value,registration->context); }
void safe_unregister(safe_registration *registration) {
    if (registration) { (void)registration->callback(91,registration->context); safe_free(registration); }
}
