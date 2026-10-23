#include "foreign.h"
#include <errno.h>
uint64_t foreign_target(void) {
    const uint16_t marker = 1;
    uint64_t value = sizeof(void *) | ((uint64_t)*(const unsigned char *)&marker << 8);
#if defined(_WIN32) && defined(__i386__)
    value |= UINT64_C(1) << 9;
#endif
    return value;
}
#if RUNE_FFI
#include <ffi.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#include <stdatomic.h>
#endif
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
static _Atomic uint64_t next_identity = 1;
#define ID_LOAD(p) atomic_load(p)
#define ID_EXCHANGE(p, old, next) atomic_compare_exchange_weak(p, old, next)
#elif defined(__GNUC__) || defined(__clang__)
/* GCC/Clang retain thread-safe identities in the supported C99 build. */
static uint64_t next_identity = 1;
#define ID_LOAD(p) __atomic_load_n(p, __ATOMIC_SEQ_CST)
#define ID_EXCHANGE(p, old, next) __atomic_compare_exchange_n(p, old, next, 1, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)
#else
#error "Enabled Runeffi requires C11 atomics or GCC-compatible atomic builtins"
#endif

typedef enum { FREE, LIBRARY, SYMBOL, MEMORY, VIEW, POINTER, CALL } Kind;
typedef struct {
    ffi_cif cif;
    ffi_type **types;
    ForeignType *arguments;
    ForeignType result;
    size_t count;
    void *address;
    unsigned active;
} Prepared;
typedef struct {
    ForeignId id, parent;
    Kind kind;
    void *address;
    size_t length;
    Prepared *call;
} Resource;
struct Foreign {
    ForeignSystem system;
    ForeignError error;
    Resource *resources;
    size_t count, capacity, live;
};
static ForeignId identity(void) {
    uint64_t value = ID_LOAD(&next_identity);
    while (value != UINT64_MAX) {
        if (ID_EXCHANGE(&next_identity, &value, value + 1)) return value;
    }
    return 0;
}
static void fail(Foreign *f, int number, const char *message) {
    memset(&f->error, 0, sizeof f->error);
    f->error.error_number = number;
    size_t n = strlen(message);
    if (n >= sizeof f->error.message) n = sizeof f->error.message - 1;
    memcpy(f->error.message, message, n);
}
static void native_error(Foreign *f) {
    memset(&f->error, 0, sizeof f->error);
    f->system.error(&f->error.error_number, &f->error.native_error, f->error.message, sizeof f->error.message);
}
static Resource *find(Foreign *f, ForeignId id) {
    for (size_t i = 0; i < f->count; i++)
        if (f->resources[i].kind != FREE && f->resources[i].id == id) return &f->resources[i];
    fail(f, EINVAL, "stale or foreign resource identity");
    return NULL;
}
static Resource *reserve(Foreign *f) {
    ForeignId id = identity();
    if (!id) { fail(f, ENOSPC, "foreign identity space exhausted"); return NULL; }
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind == FREE) {
        memset(&f->resources[i], 0, sizeof f->resources[i]);
        f->resources[i].id = id;
        return &f->resources[i];
    }
    if (f->count == f->capacity) {
        size_t capacity = f->capacity ? f->capacity * 2 : 16;
        if (capacity < f->capacity || capacity > SIZE_MAX / sizeof(Resource)) {
            fail(f, ENOMEM, "foreign registry is too large"); return NULL;
        }
        Resource *resources = realloc(f->resources, capacity * sizeof *resources);
        if (!resources) { fail(f, ENOMEM, "foreign registry allocation failed"); return NULL; }
        f->resources = resources;
        f->capacity = capacity;
    }
    Resource *r = &f->resources[f->count++];
    memset(r, 0, sizeof *r);
    r->id = id;
    return r;
}
static int string_ok(Foreign *f, const char *s, size_t n) {
    if (!s || memchr(s, 0, n)) { fail(f, EINVAL, "embedded NUL in native name"); return 0; }
    return 1;
}
Foreign *foreign_create(const ForeignSystem *system) {
    if (!system || !system->open || !system->symbol || !system->close || !system->error || !system->capture) return NULL;
    Foreign *f = calloc(1, sizeof *f);
    if (f) f->system = *system;
    return f;
}
int foreign_available(void) { return 1; }
const ForeignError *foreign_error(const Foreign *f) { return &f->error; }
size_t foreign_live(const Foreign *f) { return f ? f->live : 0; }
ForeignId foreign_library(Foreign *f, const char *path, size_t length) {
    if (!string_ok(f, path, length)) return 0;
    Resource *r = reserve(f);
    if (!r) return 0;
    void *library = f->system.open(path, length);
    if (!library) { native_error(f); return 0; }
    r->kind = LIBRARY; r->address = library; f->live++;
    return r->id;
}
ForeignId foreign_symbol(Foreign *f, ForeignId library, const char *name, size_t length) {
    Resource *owner = find(f, library);
    if (!owner || owner->kind != LIBRARY) { fail(f, EINVAL, "symbol owner is not a library"); return 0; }
    if (!string_ok(f, name, length)) return 0;
    void *handle = owner->address;
    Resource *r = reserve(f);
    if (!r) return 0;
    void *address = f->system.symbol(handle, name, length);
    if (!address) { native_error(f); return 0; }
    r->kind = SYMBOL; r->parent = library; r->address = address; f->live++;
    return r->id;
}
ForeignId foreign_memory(Foreign *f, size_t length) {
    Resource *r = reserve(f);
    if (!r) return 0;
    void *memory = calloc(length ? length : 1, 1);
    if (!memory) { fail(f, ENOMEM, "foreign memory allocation failed"); return 0; }
    r->kind = MEMORY; r->address = memory; r->length = length; f->live++;
    return r->id;
}
static int region(Foreign *f, ForeignId id, size_t offset, size_t length, void **address) {
    Resource *r = find(f, id);
    if (!r || (r->kind != MEMORY && r->kind != VIEW && r->kind != POINTER)) {
        fail(f, EINVAL, "resource is not foreign memory"); return 0;
    }
    if (offset > r->length || length > r->length - offset) {
        fail(f, ERANGE, "foreign memory range is out of bounds"); return 0;
    }
    *address = (unsigned char *)r->address + offset;
    return 1;
}
int foreign_read(Foreign *f, ForeignId id, size_t offset, void *data, size_t length) {
    void *address;
    if (!region(f, id, offset, length, &address)) return -1;
    if (length) memcpy(data, address, length);
    return 0;
}
int foreign_write(Foreign *f, ForeignId id, size_t offset, const void *data, size_t length) {
    void *address;
    if (!region(f, id, offset, length, &address)) return -1;
    if (length) memcpy(address, data, length);
    return 0;
}
ForeignId foreign_view(Foreign *f, ForeignId id, size_t offset, size_t length) {
    void *address;
    if (!region(f, id, offset, length, &address)) return 0;
    Resource *r = reserve(f);
    if (!r) return 0;
    r->kind = VIEW; r->address = address; r->length = length; r->parent = id; f->live++;
    return r->id;
}
static ffi_type *type(ForeignType t) {
    switch (t) {
    case FOREIGN_VOID: return &ffi_type_void;
    case FOREIGN_I8: return &ffi_type_sint8; case FOREIGN_U8: return &ffi_type_uint8;
    case FOREIGN_I16: return &ffi_type_sint16; case FOREIGN_U16: return &ffi_type_uint16;
    case FOREIGN_I32: return &ffi_type_sint32; case FOREIGN_U32: return &ffi_type_uint32;
    case FOREIGN_I64: return &ffi_type_sint64; case FOREIGN_U64: return &ffi_type_uint64;
    case FOREIGN_F32: return &ffi_type_float; case FOREIGN_F64: return &ffi_type_double;
    case FOREIGN_POINTER: return &ffi_type_pointer;
    default: return NULL;
    }
}
ForeignId foreign_prepare(Foreign *f, ForeignId symbol, int abi, ForeignType result, const ForeignType *arguments, size_t count) {
    Resource *s = find(f, symbol);
    if (!s || s->kind != SYMBOL || !type(result) || count > 1024) {
        fail(f, EINVAL, "invalid foreign call specification"); return 0;
    }
    ffi_abi convention = FFI_DEFAULT_ABI;
    if (abi) {
#if defined(_WIN32) && defined(__i386__)
        if (abi == 1) convention = FFI_STDCALL; else
#endif
        { fail(f, ENOTSUP, "calling convention unavailable on this target"); return 0; }
    }
    void *address = s->address;
    Prepared *p = calloc(1, sizeof *p);
    if (!p) { fail(f, ENOMEM, "prepared call allocation failed"); return 0; }
    p->types = calloc(count ? count : 1, sizeof *p->types);
    p->arguments = calloc(count ? count : 1, sizeof *p->arguments);
    if (!p->types || !p->arguments) { free(p->types); free(p->arguments); free(p); fail(f, ENOMEM, "call type allocation failed"); return 0; }
    for (size_t i = 0; i < count; i++) {
        if (arguments[i] == FOREIGN_VOID || !(p->types[i] = type(arguments[i]))) {
            free(p->types); free(p->arguments); free(p); fail(f, EINVAL, "invalid argument type"); return 0;
        }
        p->arguments[i] = arguments[i];
    }
    if (ffi_prep_cif(&p->cif, convention, (unsigned)count, type(result), p->types) != FFI_OK) {
        free(p->types); free(p->arguments); free(p); fail(f, ENOTSUP, "libffi rejected call interface"); return 0;
    }
    Resource *r = reserve(f);
    if (!r) { free(p->types); free(p->arguments); free(p); return 0; }
    p->address = address; p->count = count; p->result = result;
    r->kind = CALL; r->parent = symbol; r->call = p; f->live++;
    return r->id;
}

typedef union { int8_t i8; uint8_t u8; int16_t i16; uint16_t u16; int32_t i32; uint32_t u32;
    int64_t i64; uint64_t u64; float f32; double f64; void *pointer; ffi_arg word; } Storage;
static int argument(Foreign *f, ForeignType expected, const ForeignValue *value, Storage *storage, void **address) {
    if (value->type != expected) { fail(f, EINVAL, "foreign argument type mismatch"); return 0; }
#define SIGNED(kind, member, lo, hi) case kind: if (value->value.integer < (lo) || value->value.integer > (hi)) goto range; storage->member = value->value.integer; *address = &storage->member; break
#define UNSIGNED(kind, member, hi) case kind: if (value->value.word > (hi)) goto range; storage->member = value->value.word; *address = &storage->member; break
    switch (expected) {
    SIGNED(FOREIGN_I8, i8, INT8_MIN, INT8_MAX); UNSIGNED(FOREIGN_U8, u8, UINT8_MAX);
    SIGNED(FOREIGN_I16, i16, INT16_MIN, INT16_MAX); UNSIGNED(FOREIGN_U16, u16, UINT16_MAX);
    SIGNED(FOREIGN_I32, i32, INT32_MIN, INT32_MAX); UNSIGNED(FOREIGN_U32, u32, UINT32_MAX);
    case FOREIGN_I64: storage->i64 = value->value.integer; *address = &storage->i64; break;
    case FOREIGN_U64: storage->u64 = value->value.word; *address = &storage->u64; break;
    case FOREIGN_F32: storage->f32 = (float)value->value.real; *address = &storage->f32; break;
    case FOREIGN_F64: storage->f64 = value->value.real; *address = &storage->f64; break;
    case FOREIGN_POINTER:
        storage->pointer = NULL;
        if (value->value.pointer) {
            Resource *r = find(f, value->value.pointer);
            if (!r || (r->kind != MEMORY && r->kind != VIEW && r->kind != POINTER && r->kind != SYMBOL)) {
                fail(f, EINVAL, "pointer argument is not a pointer resource"); return 0;
            }
            storage->pointer = r->address;
        }
        *address = &storage->pointer; break;
    default: fail(f, EINVAL, "invalid argument kind"); return 0;
    }
    return 1;
range: fail(f, ERANGE, "foreign scalar argument is out of range"); return 0;
#undef SIGNED
#undef UNSIGNED
}
int foreign_call(Foreign *f, ForeignId call, const ForeignValue *arguments, size_t count, ForeignValue *result, ForeignError *captured) {
    Resource *r = find(f, call);
    if (!r || r->kind != CALL || count != r->call->count) { fail(f, EINVAL, "invalid prepared call"); return -1; }
    Prepared *p = r->call;
    Storage *storage = calloc(count ? count : 1, sizeof *storage);
    void **addresses = calloc(count ? count : 1, sizeof *addresses);
    if (!storage || !addresses) { free(storage); free(addresses); fail(f, ENOMEM, "call arena allocation failed"); return -1; }
    for (size_t i = 0; i < count; i++) if (!argument(f, p->arguments[i], &arguments[i], &storage[i], &addresses[i])) {
        free(storage); free(addresses); return -1;
    }
    ForeignId library = r->parent;
    Resource *parent;
    while ((parent = find(f, library)) && parent->kind != LIBRARY) library = parent->parent;
    if (!parent) { free(storage); free(addresses); return -1; }
    Resource *pointer = p->result == FOREIGN_POINTER ? reserve(f) : NULL;
    if (p->result == FOREIGN_POINTER && !pointer) { free(storage); free(addresses); return -1; }
    ForeignId pointer_id = pointer ? pointer->id : 0;
    Storage output;
    memset(&output, 0, sizeof output);
    void (*entry)(void) = NULL;
    if (sizeof entry != sizeof p->address) { free(storage); free(addresses); fail(f, ENOTSUP, "function address representation unsupported"); return -1; }
    memcpy(&entry, &p->address, sizeof entry);
    p->active++;
    ffi_call(&p->cif, entry, &output, addresses);
    /* Capture before arena cleanup, conversions or another native operation. */
    int saved_errno;
    uint32_t saved_native;
    f->system.capture(&saved_errno, &saved_native);
    memset(captured, 0, sizeof *captured);
    captured->error_number = saved_errno;
    captured->native_error = saved_native;
    p->active--;
    result->type = p->result;
    switch (p->result) {
    case FOREIGN_VOID: break;
    case FOREIGN_I8: result->value.integer = (int8_t)output.word; break;
    case FOREIGN_U8: result->value.word = (uint8_t)output.word; break;
    case FOREIGN_I16: result->value.integer = (int16_t)output.word; break;
    case FOREIGN_U16: result->value.word = (uint16_t)output.word; break;
    case FOREIGN_I32: result->value.integer = sizeof(ffi_arg) > sizeof(int32_t) ? (int32_t)output.word : output.i32; break;
    case FOREIGN_U32: result->value.word = sizeof(ffi_arg) > sizeof(uint32_t) ? (uint32_t)output.word : output.u32; break;
    case FOREIGN_I64: result->value.integer = output.i64; break;
    case FOREIGN_U64: result->value.word = output.u64; break;
    case FOREIGN_F32: result->value.real = output.f32; break;
    case FOREIGN_F64: result->value.real = output.f64; break;
    case FOREIGN_POINTER:
        result->value.pointer = 0;
        if (output.pointer) {
            pointer->kind = POINTER; pointer->parent = library; pointer->address = output.pointer; pointer->length = SIZE_MAX;
            /* A native pointer into storage we own retains that backing
               allocation and its remaining bounds, including one-past-end. */
            uintptr_t address = (uintptr_t)output.pointer;
            for (size_t i = 0; i < f->count; i++) {
                Resource *owner = &f->resources[i];
                if (owner->kind != MEMORY && owner->kind != VIEW) continue;
                uintptr_t start = (uintptr_t)owner->address;
                if (address >= start && address - start <= owner->length) {
                    pointer->parent = owner->id;
                    pointer->length = owner->length - (size_t)(address - start);
                    break;
                }
            }
            result->value.pointer = pointer_id; f->live++;
        }
        break;
    }
    free(storage); free(addresses);
    return 0;
}
int foreign_release(Foreign *f, ForeignId id) {
    Resource *r = find(f, id);
    if (!r) return -1;
    if (r->kind == CALL && r->call->active) { fail(f, EBUSY, "foreign call is active"); return -1; }
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind != FREE && f->resources[i].parent == id) {
        fail(f, EBUSY, "foreign resource has live dependents"); return -1;
    }
    if (r->kind == LIBRARY && f->system.close(r->address) != 0) { native_error(f); return -1; }
    if (r->kind == MEMORY) free(r->address);
    if (r->kind == CALL) { free(r->call->types); free(r->call->arguments); free(r->call); }
    r->kind = FREE; f->live--;
    return 0;
}
void foreign_destroy(Foreign *f) {
    if (!f) return;
    while (f->live) {
        size_t before = f->live;
        for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind != FREE)
            (void)foreign_release(f, f->resources[i].id);
        if (f->live == before) break;
    }
    free(f->resources); free(f);
}
#else
#include <stdlib.h>
#include <string.h>
struct Foreign { ForeignError error; };
static int unavailable(Foreign *f) {
    f->error.error_number = ENOSYS;
    f->error.native_error = 0;
    strcpy(f->error.message, "runtime built without libffi support");
    return -1;
}
int foreign_available(void) { return 0; }
Foreign *foreign_create(const ForeignSystem *system) { (void)system; return calloc(1, sizeof(Foreign)); }
void foreign_destroy(Foreign *f) { free(f); }
const ForeignError *foreign_error(const Foreign *f) { return &f->error; }
size_t foreign_live(const Foreign *f) { (void)f; return 0; }
ForeignId foreign_library(Foreign *f,const char *p,size_t n) { (void)p;(void)n;unavailable(f);return 0; }
ForeignId foreign_symbol(Foreign *f,ForeignId l,const char *p,size_t n) { (void)l;(void)p;(void)n;unavailable(f);return 0; }
ForeignId foreign_memory(Foreign *f,size_t n) { (void)n;unavailable(f);return 0; }
int foreign_read(Foreign *f,ForeignId r,size_t o,void *p,size_t n) { (void)r;(void)o;(void)p;(void)n;return unavailable(f); }
int foreign_write(Foreign *f,ForeignId r,size_t o,const void *p,size_t n) { (void)r;(void)o;(void)p;(void)n;return unavailable(f); }
ForeignId foreign_view(Foreign *f,ForeignId r,size_t o,size_t n) { (void)r;(void)o;(void)n;unavailable(f);return 0; }
ForeignId foreign_prepare(Foreign *f,ForeignId r,int a,ForeignType t,const ForeignType *p,size_t n) { (void)r;(void)a;(void)t;(void)p;(void)n;unavailable(f);return 0; }
int foreign_call(Foreign *f,ForeignId r,const ForeignValue *p,size_t n,ForeignValue *v,ForeignError *e) { (void)r;(void)p;(void)n;(void)v;(void)e;return unavailable(f); }
int foreign_release(Foreign *f,ForeignId r) { (void)r;return unavailable(f); }
#endif
