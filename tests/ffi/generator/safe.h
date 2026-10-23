#ifndef RUNEFFI_GENERATOR_SAFE_H
#define RUNEFFI_GENERATOR_SAFE_H
unsigned long safe_length(const char *text);
char *safe_copy(const char *text);
const char *safe_optional(int empty);
void *safe_allocate(unsigned long length);
void *safe_identity(void *memory);
void safe_free(void *memory);
unsigned long safe_allocations(void);
void safe_numbers(int *integer, unsigned int *bits, float *fraction);
void safe_accumulate(int *value);
int safe_alias(unsigned char *first, unsigned char *second);
void safe_fill(unsigned char *buffer, unsigned long length);
int safe_fail(int code);
const char *safe_error_text(void);
typedef int (*safe_callback)(int value);
char *safe_callback_owned(safe_callback callback);
void safe_callback_buffer(safe_callback callback, unsigned char *buffer);
void safe_missing_free(void *memory);
char *safe_preflight(void);
int safe_preflight_calls(void);
void safe_fill_ints(int *buffer);
int safe_sum_ints(const int *buffer, unsigned long length);
typedef _Bool (*safe_bool_callback)(_Bool value);
_Bool safe_call_bool(safe_bool_callback callback);
double safe_float_fail(void);
char *safe_bad_utf8(void);
const unsigned short *safe_utf16(void);
int safe_utf16_input(const unsigned short *text);
#endif
