#ifndef RUNE_FOREIGN_H
#define RUNE_FOREIGN_H
#include <stddef.h>
#include <stdint.h>
#ifndef RUNE_FFI
#define RUNE_FFI 0
#endif

typedef uint64_t ForeignId;
typedef struct Foreign Foreign;
typedef struct {
    void *(*open)(const char *path, size_t length);
    void *(*symbol)(void *library, const char *name, size_t length);
    int (*close)(void *library);
    void (*error)(int *error_number, uint32_t *native_error, char *message, size_t capacity);
    void (*capture)(int *error_number, uint32_t *native_error);
} ForeignSystem;
typedef enum {
    FOREIGN_VOID, FOREIGN_I8, FOREIGN_U8, FOREIGN_I16, FOREIGN_U16,
    FOREIGN_I32, FOREIGN_U32, FOREIGN_I64, FOREIGN_U64,
    FOREIGN_F32, FOREIGN_F64, FOREIGN_POINTER
} ForeignType;
typedef struct {
    ForeignType type;
    union { int64_t integer; uint64_t word; double real; ForeignId pointer; } value;
} ForeignValue;
typedef struct { int error_number; uint32_t native_error; char message[256]; } ForeignError;
typedef enum { FOREIGN_FAIL_NEVER, FOREIGN_FAIL_ZERO, FOREIGN_FAIL_NONZERO, FOREIGN_FAIL_NEGATIVE } ForeignFailure;
/* Hooks are called only on the context's creating thread, within a native
   call. The opaque state is owned until the closure's explicit release.
   Return 0 on success, negative to use the native fallback, or positive for
   a contained exception: later callbacks in this activation bypass SML. */
typedef int (*ForeignCallback)(void *state, const ForeignValue *, size_t, ForeignValue *);
typedef void (*ForeignCallbackFree)(void *state);
typedef struct { size_t index; uint64_t key; ForeignValue value; } ForeignCallbackFailure;

Foreign *foreign_create(const ForeignSystem *system);
int foreign_available(void);
/* Pointer bytes, little-endian flag (bit 8), stdcall availability (bit 9). */
uint64_t foreign_target(void);
/* Version, compiler architecture, CHAR_BIT, char signedness, followed by
   char/short/int/long/longLong/pointer/wchar/float/double/bool size/alignment. */
#define FOREIGN_FACTS_BYTES 24
void foreign_facts(unsigned char facts[FOREIGN_FACTS_BYTES]);
/* Disable entry, unload providers while retained memory/thunks live, then
   release VM roots. Returns -1 before teardown on active use; an unload
   failure leaves a closing context which permits only a destroy retry. */
int foreign_destroy(Foreign *foreign);
/* Terminal process exit only: disable entry without freeing active roots. */
void foreign_abandon(Foreign *foreign);
/* Disabled unproven registrations retained until process termination. */
size_t foreign_quarantined(void);
const ForeignError *foreign_error(const Foreign *foreign);
size_t foreign_live(const Foreign *foreign);
int foreign_alive(const Foreign *foreign, ForeignId resource);
/* -1 on invalid/non-pointer resources; otherwise native address equality. */
int foreign_same(Foreign *foreign, ForeignId left, ForeignId right);
ForeignId foreign_library(Foreign *foreign, const char *path, size_t length);
ForeignId foreign_symbol(Foreign *foreign, ForeignId library, const char *name, size_t length);
ForeignId foreign_memory(Foreign *foreign, size_t length);
int foreign_read(Foreign *foreign, ForeignId memory, size_t offset, void *data, size_t length);
int foreign_write(Foreign *foreign, ForeignId memory, size_t offset, const void *data, size_t length);
ForeignId foreign_view(Foreign *foreign, ForeignId memory, size_t offset, size_t length);
ForeignId foreign_prepare(Foreign *foreign, ForeignId symbol, int abi, ForeignType result, const ForeignType *arguments, size_t count);
ForeignId foreign_callback(Foreign *foreign, int abi, ForeignType result, const ForeignType *arguments, size_t count,
                          ForeignValue failure, const ForeignCallbackFailure *cases, size_t ncases, ForeignCallback callback, ForeignCallbackFree release, void *state);
int foreign_call(Foreign *foreign, ForeignId call, const ForeignValue *arguments, size_t count, ForeignValue *result, ForeignError *captured);
/* Atomically guard a native-owned pointer through its annotated destructor.
   A native failure preserves ownership; success also retires the identity. */
int foreign_dispose(Foreign *foreign, ForeignId resource, ForeignId call, const ForeignValue *arguments,
                    size_t count, ForeignFailure failure, ForeignValue *result, ForeignError *captured, int *disposed);
/* Canonical opaque identities cannot be dereferenced as memory. */
ForeignId foreign_alias_handle(Foreign *foreign, ForeignId pointer);
int foreign_consume_handle(Foreign *foreign, ForeignId resource, ForeignId call, const ForeignValue *arguments,
                           size_t count, ForeignFailure failure, ForeignValue *result, ForeignError *captured, int *disposed);
int foreign_release(Foreign *foreign, ForeignId resource);
#endif
