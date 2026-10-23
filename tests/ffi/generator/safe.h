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
typedef int (*safe_selector_callback)(unsigned int code);
typedef int (*safe_bool_selector_callback)(_Bool code);
void safe_selected(safe_selector_callback callback);
void safe_selected_bool(safe_bool_selector_callback callback);
int safe_failure_value(void);
typedef struct safe_registration safe_registration;
typedef int (*safe_registered_callback)(int value, void *context);
safe_registration *safe_register(safe_registered_callback callback, void *context);
safe_registration *safe_register_none(safe_registered_callback callback, void *context);
int safe_dispatch(safe_registration *registration, int value);
void safe_unregister(safe_registration *registration);
typedef struct safe_point { int x; float y; } safe_point;
typedef struct safe_packet { safe_point origin; unsigned int codes[3]; double scale; } safe_packet;
safe_packet safe_transform(safe_packet value, int delta);
void safe_packet_out(safe_packet *value);
void safe_packet_inout(safe_packet *value);
#define SAFE_MACRO_ADD(first,second) ((first)+(second))
#define SAFE_MACRO_PACKET(value) safe_transform((value),2)
int safe_variadic_sum(int count, ...);
double safe_variadic_real(int count, ...);
static inline int safe_inline(int value) { return value*3; }
#if defined(__x86_64__)
__attribute__((ms_abi)) int safe_other_abi(int value);
#endif
#endif
