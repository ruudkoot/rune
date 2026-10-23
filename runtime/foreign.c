#include "foreign.h"
#include <errno.h>
#include <limits.h>
uint64_t foreign_target(void) {
    const uint16_t marker = 1;
    uint64_t value = sizeof(void *) | ((uint64_t)*(const unsigned char *)&marker << 8);
#if defined(_WIN32) && defined(__i386__)
    value |= UINT64_C(1) << 9;
#endif
    return value;
}
void foreign_facts(unsigned char facts[FOREIGN_FACTS_BYTES]) {
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define RF_ALIGN(type) _Alignof(type)
#else
#define RF_ALIGN(type) offsetof(struct { char prefix; type member; }, member)
#endif
#if defined(__x86_64__) || defined(_M_X64)
    const unsigned architecture = 1;
#elif defined(__i386__) || defined(_M_IX86)
    const unsigned architecture = 2;
#elif defined(__aarch64__) || defined(_M_ARM64)
    const unsigned architecture = 3;
#elif defined(__powerpc64__) || defined(__PPC64__) || defined(_ARCH_PPC64)
    const unsigned architecture = 4;
#else
    const unsigned architecture = 0;
#endif
    const unsigned char measured[FOREIGN_FACTS_BYTES] = {
        1, architecture, CHAR_BIT, (char)-1 < 0,
        sizeof(char), RF_ALIGN(char), sizeof(short), RF_ALIGN(short),
        sizeof(int), RF_ALIGN(int), sizeof(long), RF_ALIGN(long),
        sizeof(long long), RF_ALIGN(long long), sizeof(void *), RF_ALIGN(void *),
        sizeof(wchar_t), RF_ALIGN(wchar_t), sizeof(float), RF_ALIGN(float),
        sizeof(double), RF_ALIGN(double), sizeof(_Bool), RF_ALIGN(_Bool)
    };
    for (size_t i = 0; i < FOREIGN_FACTS_BYTES; i++) facts[i] = measured[i];
#undef RF_ALIGN
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
typedef _Atomic uint64_t AtomicWord;
static AtomicWord next_identity = 1;
#define ID_LOAD(p) atomic_load(p)
#define ID_INIT(p, value) atomic_init(p, value)
#define ID_EXCHANGE(p, old, next) atomic_compare_exchange_weak(p, old, next)
#elif defined(__GNUC__) || defined(__clang__)
/* GCC/Clang retain thread-safe identities in the supported C99 build. */
typedef uint64_t AtomicWord;
static AtomicWord next_identity = 1;
#define ID_LOAD(p) __atomic_load_n(p, __ATOMIC_SEQ_CST)
#define ID_INIT(p, value) (*(p) = (value))
#define ID_EXCHANGE(p, old, next) __atomic_compare_exchange_n(p, old, next, 1, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)
#else
#error "Enabled Runeffi requires C11 atomics or GCC-compatible atomic builtins"
#endif

typedef enum { FREE, RESERVED, LIBRARY, SYMBOL, MEMORY, VIEW, POINTER, CALL, CALLBACK, HANDLE, RETIRED } Kind;
typedef struct {
    ffi_cif cif;
    ffi_type **types;
    ForeignType *arguments;
    ForeignType result;
    size_t count;
    void *address;
    unsigned active;
} Prepared;
typedef struct Callback Callback;
struct Callback {
    /* Bit zero enables entry; the remaining bits count entries already
       using the context. Disabled thunks use immutable data and own atomics. */
    AtomicWord gate;
    /* One atomic snapshot combines a saturating count and first fault. */
    AtomicWord faults;
    Callback *quarantined_next;
    Prepared signature;
    Foreign *foreign;
    ForeignId id;
    ffi_closure *closure;
    ForeignCallback enter;
    ForeignCallbackFree release;
    void *state;
    ForeignValue failure;
    ForeignCallbackFailure *failures;
    size_t nfailures;
};
static AtomicWord quarantine_lock, quarantine_count;
static Callback *quarantine;
static void word_add(AtomicWord *word, uint64_t delta) {
    uint64_t old = ID_LOAD(word);
    while (!ID_EXCHANGE(word, &old, old + delta)) {}
}
static void callback_fault(Callback *c, ForeignCallbackFault fault) {
    uint64_t old = ID_LOAD(&c->faults);
    for (;;) {
        uint64_t count = old >> 8;
        if (count != (UINT64_MAX >> 8)) count++;
        uint64_t next = (count << 8) | ((old & 255) ? old & 255 : (unsigned)fault);
        if (ID_EXCHANGE(&c->faults, &old, next)) return;
    }
}
static int callback_acquire(Callback *c) {
    uint64_t old = ID_LOAD(&c->gate);
    while (old & 1) {
        if (old > UINT64_MAX - 2) return 0;
        if (ID_EXCHANGE(&c->gate, &old, old + 2)) return 1;
    }
    return 0;
}
static uint64_t callback_disable(Callback *c) {
    uint64_t old = ID_LOAD(&c->gate);
    while (!ID_EXCHANGE(&c->gate, &old, old & ~UINT64_C(1))) {}
    return old;
}
static void callback_enable(Callback *c) {
    uint64_t old = ID_LOAD(&c->gate);
    while (!ID_EXCHANGE(&c->gate, &old, old | UINT64_C(1))) {}
}
static void callback_quarantine(Callback *c) {
    /* Keep the thunk, failure metadata and atomic fault status, never
       a VM, closure handle or resource registry. Registration provenance
       cannot in general prove that dlclose unregistered an OS callback. */
    if (c->release) c->release(c->state);
    c->state = NULL; c->release = NULL; c->enter = NULL; c->foreign = NULL;
    uint64_t unlocked = 0;
    while (!ID_EXCHANGE(&quarantine_lock, &unlocked, 1)) unlocked = 0;
    c->quarantined_next = quarantine; quarantine = c;
    word_add(&quarantine_count, 1);
    word_add(&quarantine_lock, UINT64_MAX);
}
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
static _Thread_local unsigned char thread_marker;
#elif defined(__GNUC__) || defined(__clang__)
static __thread unsigned char thread_marker;
#else
#error "Enabled callbacks require thread-local storage"
#endif
typedef struct {
    ForeignId id, parent;
    Kind kind;
    void *address;
    size_t length;
    Prepared *call;
    Callback *callback;
    unsigned active, retiring;
} Resource;
typedef struct Activation { struct Activation *parent; int failed; } Activation;
struct Foreign {
    ForeignSystem system;
    ForeignError error;
    Resource *resources;
    size_t count, capacity, live;
    const void *owner_thread;
    unsigned call_depth;
    ForeignId active_library;
    Activation *activation;
    int closing;
};
static ForeignId identity(void) {
    uint64_t value = ID_LOAD(&next_identity);
    while (value != UINT64_MAX) {
        if (ID_EXCHANGE(&next_identity, &value, value + 1)) return value;
    }
    return 0;
}
uint64_t foreign_identity_floor(void) { return ID_LOAD(&next_identity); }
int foreign_restore_identity_floor(uint64_t floor) {
    if (!floor) { errno = EINVAL; return -1; }
    uint64_t old = ID_LOAD(&next_identity);
    while (old < floor) if (ID_EXCHANGE(&next_identity, &old, floor)) break;
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
    if (f->closing) { fail(f, EBUSY, "foreign context is closing"); return NULL; }
    for (size_t i = 0; i < f->count; i++)
        if (f->resources[i].kind != FREE && f->resources[i].kind != RESERVED && f->resources[i].kind != RETIRED && f->resources[i].id == id) return &f->resources[i];
    fail(f, EINVAL, "stale or foreign resource identity");
    return NULL;
}
static Resource *leased_resource(Foreign *f, ForeignId id) {
    for (size_t i = 0; i < f->count; i++)
        if (f->resources[i].kind != FREE && f->resources[i].id == id) return &f->resources[i];
    return NULL;
}
static void unlease(Foreign *f, ForeignId id) {
    Resource *r = leased_resource(f, id);
    if (r && r->active) { r->active--; if (!r->active && r->kind == RETIRED) r->kind = FREE; }
}
static Resource *reserve(Foreign *f) {
    if (f->closing) { fail(f, EBUSY, "foreign context is closing"); return NULL; }
    ForeignId id = identity();
    if (!id) { fail(f, ENOSPC, "foreign identity space exhausted"); return NULL; }
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind == FREE) {
        memset(&f->resources[i], 0, sizeof f->resources[i]);
        f->resources[i].id = id;
        f->resources[i].kind = RESERVED;
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
    r->kind = RESERVED;
    return r;
}
static Resource *reservation(Foreign *f, ForeignId id) {
    for (size_t i = 0; i < f->count; i++)
        if (f->resources[i].id == id && f->resources[i].kind == RESERVED) return &f->resources[i];
    return NULL;
}
static void cancel(Foreign *f, ForeignId id) {
    Resource *r = reservation(f, id);
    if (r) r->kind = FREE;
}
static int string_ok(Foreign *f, const char *s, size_t n) {
    if (!s || memchr(s, 0, n)) { fail(f, EINVAL, "embedded NUL in native name"); return 0; }
    return 1;
}
Foreign *foreign_create(const ForeignSystem *system) {
    if (!system || !system->open || !system->symbol || !system->close || !system->error || !system->capture) return NULL;
    Foreign *f = calloc(1, sizeof *f);
    if (f) { f->system = *system; f->owner_thread = &thread_marker; }
    return f;
}
int foreign_available(void) { return 1; }
const ForeignError *foreign_error(const Foreign *f) { return &f->error; }
size_t foreign_live(const Foreign *f) { return f ? f->live : 0; }
int foreign_alive(const Foreign *f, ForeignId id) {
    for (size_t i = 0; f && i < f->count; i++)
        if (f->resources[i].kind != FREE && f->resources[i].kind != RESERVED && f->resources[i].kind != RETIRED && f->resources[i].id == id) return 1;
    return 0;
}
static int pointer_kind(Kind kind) { return kind == MEMORY || kind == VIEW || kind == POINTER || kind == SYMBOL || kind == CALLBACK || kind == HANDLE; }
int foreign_same(Foreign *f, ForeignId left, ForeignId right) {
    Resource *a = find(f, left), *b = find(f, right);
    if (!a || !b || !pointer_kind(a->kind) || !pointer_kind(b->kind)) {
        fail(f, EINVAL, "address equality requires two pointer resources"); return -1;
    }
    return a->address == b->address;
}
ForeignId foreign_library(Foreign *f, const char *path, size_t length) {
    if (!string_ok(f, path, length)) return 0;
    Resource *r = reserve(f);
    if (!r) return 0;
    void *library = f->system.open(path, length);
    if (!library) { r->kind = FREE; native_error(f); return 0; }
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
    if (!address) { r->kind = FREE; native_error(f); return 0; }
    r->kind = SYMBOL; r->parent = library; r->address = address; f->live++;
    return r->id;
}
ForeignId foreign_memory(Foreign *f, size_t length) {
    Resource *r = reserve(f);
    if (!r) return 0;
    void *memory = calloc(length ? length : 1, 1);
    if (!memory) { r->kind = FREE; fail(f, ENOMEM, "foreign memory allocation failed"); return 0; }
    r->kind = MEMORY; r->address = memory; r->length = length; f->live++;
    return r->id;
}
static int opaque_address(Foreign *f, const void *address) {
    for (size_t i = 0; i < f->count; i++) if ((f->resources[i].kind == HANDLE || f->resources[i].kind == RETIRED) && f->resources[i].address == address) return 1;
    return 0;
}
static int region(Foreign *f, ForeignId id, size_t offset, size_t length, void **address) {
    Resource *r = find(f, id);
    if (!r || (r->kind != MEMORY && r->kind != VIEW && r->kind != POINTER)) {
        fail(f, EINVAL, "resource is not foreign memory"); return 0;
    }
    if (r->retiring) { fail(f, EBUSY, "foreign resource is being destroyed"); return 0; }
    if (r->kind == POINTER && opaque_address(f, r->address)) { fail(f, EINVAL, "opaque handle aliases are not foreign memory"); return 0; }
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
static ForeignId prepare(Foreign *f, ForeignId symbol, int abi, ForeignType result,
                         const ForeignType *arguments, size_t count, size_t fixed_count, int variadic) {
    Resource *s = find(f, symbol);
    if (!s || s->kind != SYMBOL || !type(result) || count > 1024 || (count && !arguments) ||
        (variadic && (!fixed_count || fixed_count > count))) {
        fail(f, EINVAL, "invalid foreign call specification"); return 0;
    }
    if (variadic && abi) { fail(f, ENOTSUP, "variadic calls require the target default ABI"); return 0; }
    if (variadic) for (size_t i = fixed_count; i < count; i++) {
        ffi_type *t = type(arguments[i]);
        if (!t || arguments[i] == FOREIGN_VOID || arguments[i] == FOREIGN_F32 ||
            (arguments[i] >= FOREIGN_I8 && arguments[i] <= FOREIGN_U64 && t->size < sizeof(int))) {
            fail(f, EINVAL, "variadic arguments require C default promotions"); return 0;
        }
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
    ffi_status status = variadic ?
        ffi_prep_cif_var(&p->cif, convention, (unsigned)fixed_count, (unsigned)count, type(result), p->types) :
        ffi_prep_cif(&p->cif, convention, (unsigned)count, type(result), p->types);
    if (status != FFI_OK) {
        free(p->types); free(p->arguments); free(p); fail(f, ENOTSUP, "libffi rejected call interface"); return 0;
    }
    Resource *r = reserve(f);
    if (!r) { free(p->types); free(p->arguments); free(p); return 0; }
    p->address = address; p->count = count; p->result = result;
    r->kind = CALL; r->parent = symbol; r->call = p; f->live++;
    return r->id;
}
ForeignId foreign_prepare(Foreign *f, ForeignId symbol, int abi, ForeignType result, const ForeignType *arguments, size_t count) {
    return prepare(f, symbol, abi, result, arguments, count, 0, 0);
}
ForeignId foreign_prepare_variadic(Foreign *f, ForeignId symbol, int abi, ForeignType result,
                                  const ForeignType *arguments, size_t count, size_t fixed_count) {
    return prepare(f, symbol, abi, result, arguments, count, fixed_count, 1);
}

typedef union { int8_t i8; uint8_t u8; int16_t i16; uint16_t u16; int32_t i32; uint32_t u32;
    int64_t i64; uint64_t u64; float f32; double f64; void *pointer; ffi_arg word; } Storage;
static int argument(Foreign *f, ForeignType expected, const ForeignValue *value, Storage *storage, void **address, ForeignId permit_retiring) {
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
            if (!r || (r->kind != MEMORY && r->kind != VIEW && r->kind != POINTER && r->kind != SYMBOL && r->kind != CALLBACK && r->kind != HANDLE)) {
                fail(f, EINVAL, "pointer argument is not a pointer resource"); return 0;
            }
            if (r->retiring && r->kind != HANDLE && r->id != permit_retiring) { fail(f, EBUSY, "foreign resource is being destroyed"); return 0; }
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
/* A closure owns its descriptor separately from the registry: nested SML
   calls can grow the latter. Foreign-thread entry touches neither VM nor
   mutable registry state, and deterministically returns the default. */
int foreign_callback_status(Foreign *f, ForeignId id, int reset, uint64_t *rejected, ForeignCallbackFault *first) {
    if (!f || f->owner_thread != &thread_marker) { errno = EPERM; return -1; }
    /* A failed unload leaves disabled callbacks observable until retry. */
    Resource *r = leased_resource(f, id);
    if (!r || r->kind != CALLBACK || (reset != 0 && reset != 1) || !rejected || !first) {
        fail(f, EINVAL, "invalid callback status query"); return -1;
    }
    uint64_t value = ID_LOAD(&r->callback->faults);
    if (reset) while (!ID_EXCHANGE(&r->callback->faults, &value, 0)) {}
    *rejected = value >> 8; *first = (ForeignCallbackFault)(value & 255);
    return 0;
}
static ForeignValue native_value(ForeignType t, const void *p) {
    ForeignValue v; memset(&v, 0, sizeof v); v.type = t;
    switch (t) {
#define READ(k, member, native) case k: v.value.member = *(const native *)p; break
    READ(FOREIGN_I8, integer, int8_t); READ(FOREIGN_U8, word, uint8_t);
    READ(FOREIGN_I16, integer, int16_t); READ(FOREIGN_U16, word, uint16_t);
    READ(FOREIGN_I32, integer, int32_t); READ(FOREIGN_U32, word, uint32_t);
    READ(FOREIGN_I64, integer, int64_t); READ(FOREIGN_U64, word, uint64_t);
    READ(FOREIGN_F32, real, float); READ(FOREIGN_F64, real, double);
#undef READ
    default: break;
    }
    return v;
}
static void callback_result(Foreign *f, ForeignType t, ForeignValue v, void *out) {
    Storage storage; void *address = NULL;
    if (t == FOREIGN_VOID) return;
    if (!argument(f, t, &v, &storage, &address, 0)) memset(&storage, 0, sizeof storage);
    /* libffi closures require ffi_arg-sized writes for narrow integers. */
    switch (t) {
    case FOREIGN_I8: *(ffi_sarg *)out = storage.i8; break;
    case FOREIGN_U8: *(ffi_arg *)out = storage.u8; break;
    case FOREIGN_I16: *(ffi_sarg *)out = storage.i16; break;
    case FOREIGN_U16: *(ffi_arg *)out = storage.u16; break;
    case FOREIGN_I32: *(ffi_sarg *)out = storage.i32; break;
    case FOREIGN_U32: *(ffi_arg *)out = storage.u32; break;
    case FOREIGN_I64: *(int64_t *)out = storage.i64; break;
    case FOREIGN_U64: *(uint64_t *)out = storage.u64; break;
    case FOREIGN_F32: *(float *)out = storage.f32; break;
    case FOREIGN_F64: *(double *)out = storage.f64; break;
    case FOREIGN_POINTER: *(void **)out = storage.pointer; break;
    default: break;
    }
}
static void callback_entry(ffi_cif *cif, void *out, void **input, void *opaque) {
    (void)cif;
    Callback *c = opaque;
    ForeignValue failure = c->failure;
    for (size_t i = 0; i < c->nfailures; i++) {
        const ForeignCallbackFailure *rule = &c->failures[i];
        ForeignValue key = native_value(c->signature.arguments[rule->index], input[rule->index]);
        if (key.value.word == rule->key) { failure = rule->value; break; }
    }
    /* Failure defaults are restricted to scalar/null values at creation;
       the rejected thread therefore never dereferences a resource. */
    if (!callback_acquire(c)) {
        callback_fault(c, FOREIGN_CALLBACK_DISABLED);
        Foreign local; memset(&local, 0, sizeof local);
        callback_result(&local, c->signature.result, failure, out);
        return;
    }
    Foreign *f = c->foreign;
    if (f->owner_thread != &thread_marker || !f->call_depth) {
        callback_fault(c, f->owner_thread != &thread_marker ?
                       FOREIGN_CALLBACK_WRONG_THREAD : FOREIGN_CALLBACK_NO_ACTIVATION);
        Foreign local; memset(&local, 0, sizeof local);
        callback_result(&local, c->signature.result, failure, out);
        word_add(&c->gate, UINT64_MAX - 1); return;
    }
    if (f->activation && f->activation->failed) { callback_result(f, c->signature.result, failure, out); word_add(&c->gate, UINT64_MAX - 1); return; }
    Resource *self = find(f, c->id);
    if (!self || self->active == UINT_MAX) { callback_fault(c, FOREIGN_CALLBACK_ENTRY_FAILURE); callback_result(f, c->signature.result, failure, out); word_add(&c->gate, UINT64_MAX - 1); return; }
    self->active++;
    size_t count = c->signature.count;
    ForeignValue *values = calloc(count ? count : 1, sizeof *values), result = failure;
    ForeignId *borrowed = calloc(count ? count : 1, sizeof *borrowed); size_t nborrowed = 0;
    if (!values || !borrowed) {
        callback_fault(c, FOREIGN_CALLBACK_ENTRY_FAILURE);
        free(values); free(borrowed);
        find(f, c->id)->active--;
        callback_result(f, c->signature.result, failure, out);
        word_add(&c->gate, UINT64_MAX - 1);
        return;
    }
    int valid = 1;
    for (size_t i = 0; i < count; i++) {
        ForeignType t = c->signature.arguments[i];
        values[i] = native_value(t, input[i]);
        if (t == FOREIGN_POINTER && *(void **)input[i]) {
            Resource *r = reserve(f);
            if (!r) { valid = 0; break; }
            r->kind = POINTER; r->parent = c->id; r->address = *(void **)input[i]; r->length = SIZE_MAX; r->active = 1;
            values[i].value.pointer = r->id; borrowed[nborrowed++] = r->id; f->live++;
        }
    }
    if (valid) {
        int status = c->enter(c->state, values, count, &result);
        if (status < 0) { callback_fault(c, FOREIGN_CALLBACK_ENTRY_FAILURE); result = failure; }
        else if (status > 0 && f->activation) f->activation->failed = 1;
    } else callback_fault(c, FOREIGN_CALLBACK_ENTRY_FAILURE);
    callback_result(f, c->signature.result, result, out);
    for (size_t i = 0; i < nborrowed; i++) {
        /* Views and returned pointer aliases cannot outlive this borrowed
           identity either. Mark the dependency tree before freeing slots. */
        int changed;
        do {
            changed = 0;
            for (size_t k = 0; k < f->count; k++) {
                Resource *r = &f->resources[k];
                Resource *parent = leased_resource(f, r->parent);
                if (r->kind != FREE && r->kind != RESERVED && r->kind != RETIRED &&
                    (r->parent == borrowed[i] || (parent && parent->kind == RETIRED))) {
                    r->kind = RETIRED; f->live--; changed = 1;
                }
            }
        } while (changed);
        for (size_t k = 0; k < f->count; k++) if (f->resources[k].kind == RETIRED && !f->resources[k].active) f->resources[k].kind = FREE;
        Resource *r = leased_resource(f, borrowed[i]);
        if (r) { if (r->kind != RETIRED) f->live--; r->kind = FREE; }
    }
    find(f, c->id)->active--;
    free(values); free(borrowed);
    word_add(&c->gate, UINT64_MAX - 1);
}
ForeignId foreign_callback(Foreign *f, int abi, ForeignType result, const ForeignType *arguments, size_t count,
                          ForeignValue failure, const ForeignCallbackFailure *cases, size_t ncases, ForeignCallback enter, ForeignCallbackFree release, void *state) {
    if (!type(result) || !enter || count > 1024 || ncases > 1024 || failure.type != result ||
        (result == FOREIGN_POINTER && failure.value.pointer)) {
        fail(f, EINVAL, "invalid callback specification or non-null failure pointer"); return 0;
    }
    ffi_abi convention = FFI_DEFAULT_ABI;
    if (abi) {
#if defined(_WIN32) && defined(__i386__)
        if (abi == 1) convention = FFI_STDCALL; else
#endif
        { fail(f, ENOTSUP, "callback calling convention unavailable"); return 0; }
    }
    for (size_t i = 0; i < ncases; i++) {
        ForeignType t = cases[i].index < count ? arguments[cases[i].index] : FOREIGN_VOID;
        if (t < FOREIGN_I8 || t > FOREIGN_U64 || cases[i].value.type != result ||
            (result == FOREIGN_POINTER && cases[i].value.value.pointer)) {
            fail(f, EINVAL, "invalid callback failure selection"); return 0;
        }
    }
    if (result != FOREIGN_VOID) {
        Storage checked; void *at;
        if (!argument(f, result, &failure, &checked, &at, 0)) return 0;
        for (size_t i = 0; i < ncases; i++) if (!argument(f, result, &cases[i].value, &checked, &at, 0)) return 0;
    }
    Callback *c = calloc(1, sizeof *c);
    if (!c) { fail(f, ENOMEM, "callback allocation failed"); return 0; }
    c->failures = calloc(ncases ? ncases : 1, sizeof *c->failures);
    c->signature.types = calloc(count ? count : 1, sizeof *c->signature.types);
    c->signature.arguments = calloc(count ? count : 1, sizeof *arguments);
    if (!c->failures || !c->signature.types || !c->signature.arguments) goto allocation;
    if (ncases) memcpy(c->failures, cases, ncases * sizeof *cases);
    c->nfailures = ncases;
    for (size_t i = 0; i < count; i++) {
        if (arguments[i] == FOREIGN_VOID || !(c->signature.types[i] = type(arguments[i]))) {
            fail(f, EINVAL, "invalid callback argument type"); goto bad;
        }
        c->signature.arguments[i] = arguments[i];
    }
    if (ffi_prep_cif(&c->signature.cif, convention, (unsigned)count, type(result), c->signature.types) != FFI_OK) {
        fail(f, ENOTSUP, "libffi rejected callback interface"); goto bad;
    }
    void *address;
    c->closure = ffi_closure_alloc(sizeof *c->closure, &address);
    if (!c->closure) goto allocation;
    c->signature.count = count; c->signature.result = result;
    ID_INIT(&c->gate, 1);
    ID_INIT(&c->faults, 0);
    c->foreign = f; c->enter = enter; c->release = release; c->state = state; c->failure = failure;
    if (ffi_prep_closure_loc(c->closure, &c->signature.cif, callback_entry, c, address) != FFI_OK) {
        fail(f, ENOTSUP, "libffi rejected executable callback"); goto bad;
    }
    Resource *r = reserve(f);
    if (!r) goto bad;
    r->kind = CALLBACK; r->callback = c; r->address = address;
    c->id = r->id; f->live++;
    return r->id;
allocation: fail(f, ENOMEM, "callback allocation failed");
bad:
    if (c->closure) ffi_closure_free(c->closure);
    free(c->failures); free(c->signature.types); free(c->signature.arguments); free(c);
    return 0;
}
static int call_checked(Foreign *f, ForeignId call, const ForeignValue *arguments, size_t count, ForeignValue *result, ForeignError *captured, ForeignId permit_retiring) {
    Resource *r = find(f, call);
    if (!r || r->kind != CALL || count != r->call->count) { fail(f, EINVAL, "invalid prepared call"); return -1; }
    Prepared *p = r->call;
    if (p->active == UINT_MAX) { fail(f, EBUSY, "foreign call nesting limit exceeded"); return -1; }
    Storage *storage = calloc(count ? count : 1, sizeof *storage);
    void **addresses = calloc(count ? count : 1, sizeof *addresses);
    if (!storage || !addresses) { free(storage); free(addresses); fail(f, ENOMEM, "call arena allocation failed"); return -1; }
    for (size_t i = 0; i < count; i++) if (!argument(f, p->arguments[i], &arguments[i], &storage[i], &addresses[i], permit_retiring)) {
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
    if (sizeof entry != sizeof p->address) { cancel(f, pointer_id); free(storage); free(addresses); fail(f, ENOTSUP, "function address representation unsupported"); return -1; }
    memcpy(&entry, &p->address, sizeof entry);
    size_t leased = 0;
    for (; leased < count; leased++) if (arguments[leased].type == FOREIGN_POINTER && arguments[leased].value.pointer) {
        Resource *resource = find(f, arguments[leased].value.pointer);
        if (resource->active == UINT_MAX) break;
        resource->active++;
    }
    if (leased != count) {
        for (size_t i = 0; i < leased; i++) if (arguments[i].type == FOREIGN_POINTER && arguments[i].value.pointer)
            unlease(f, arguments[i].value.pointer);
        cancel(f, pointer_id); free(storage); free(addresses); fail(f, EBUSY, "foreign argument nesting limit exceeded"); return -1;
    }
    Activation activation = {f->activation, 0};
    f->activation = &activation;
    ForeignId old_library = f->active_library;
    f->active_library = library;
    p->active++; f->call_depth++;
    ffi_call(&p->cif, entry, &output, addresses);
    /* Capture before arena cleanup, conversions or another native operation. */
    int saved_errno;
    uint32_t saved_native;
    f->system.capture(&saved_errno, &saved_native);
    memset(captured, 0, sizeof *captured);
    captured->error_number = saved_errno;
    captured->native_error = saved_native;
    p->active--; f->call_depth--; f->active_library = old_library; f->activation = activation.parent;
    for (size_t i = 0; i < count; i++) if (arguments[i].type == FOREIGN_POINTER && arguments[i].value.pointer)
        unlease(f, arguments[i].value.pointer);
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
            /* Reentry may have grown/moved the registry. The reservation is
               an identity, never a Resource pointer parked across ffi_call. */
            pointer = reservation(f, pointer_id);
            pointer->kind = POINTER; pointer->parent = library; pointer->address = output.pointer; pointer->length = SIZE_MAX;
            /* A native pointer into storage we own retains that backing
               allocation and its remaining bounds, including one-past-end. */
            uintptr_t address = (uintptr_t)output.pointer;
            for (size_t i = 0; i < f->count; i++) {
                Resource *owner = &f->resources[i];
                if (owner->kind == POINTER && owner->active && owner->address == output.pointer) {
                    pointer->parent = owner->id; pointer->length = owner->length; break;
                }
                if (owner->kind != MEMORY && owner->kind != VIEW) continue;
                uintptr_t start = (uintptr_t)owner->address;
                if (address >= start && address - start <= owner->length) {
                    pointer->parent = owner->id;
                    pointer->length = owner->length - (size_t)(address - start);
                    break;
                }
            }
            result->value.pointer = pointer_id; f->live++;
        } else cancel(f, pointer_id);
        break;
    }
    free(storage); free(addresses);
    return 0;
}
int foreign_call(Foreign *f, ForeignId call, const ForeignValue *arguments, size_t count, ForeignValue *result, ForeignError *captured) {
    return call_checked(f, call, arguments, count, result, captured, 0);
}
int foreign_dispose(Foreign *f, ForeignId id, ForeignId call, const ForeignValue *arguments, size_t count,
                    ForeignFailure failure, ForeignValue *result, ForeignError *captured, int *disposed) {
    *disposed = 0;
    Resource *r = find(f, id), *destructor = find(f, call);
    if (!r || !destructor || r->kind != POINTER || destructor->kind != CALL) {
        fail(f, EINVAL, "native disposal requires a pointer and prepared destructor"); return -1;
    }
    if (opaque_address(f, r->address)) { fail(f, EINVAL, "opaque handle aliases require handle destruction"); return -1; }
    Resource *parent = find(f, r->parent);
    if (!parent || parent->kind != LIBRARY) { fail(f, EINVAL, "native disposal cannot free Rune-owned storage or views"); return -1; }
    if (r->retiring || r->active) { fail(f, EBUSY, "foreign resource is active or being destroyed"); return -1; }
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind != FREE && f->resources[i].parent == id) {
        fail(f, EBUSY, "foreign resource has live dependents"); return -1;
    }
    ForeignType type = destructor->call->result;
    int signed_type = type == FOREIGN_I8 || type == FOREIGN_I16 || type == FOREIGN_I32 || type == FOREIGN_I64;
    if (type > FOREIGN_U64 || (unsigned)failure > FOREIGN_FAIL_NEGATIVE ||
        (type == FOREIGN_VOID && failure != FOREIGN_FAIL_NEVER) || (failure == FOREIGN_FAIL_NEGATIVE && !signed_type)) {
        fail(f, EINVAL, "unsupported native destructor result or failure predicate"); return -1;
    }
    r->retiring = 1;
    int status = call_checked(f, call, arguments, count, result, captured, id);
    r = find(f, id);
    r->retiring = 0;
    if (status != 0) return status;
    int failed = failure == FOREIGN_FAIL_ZERO ? result->value.word == 0 :
                 failure == FOREIGN_FAIL_NONZERO ? result->value.word != 0 :
                 failure == FOREIGN_FAIL_NEGATIVE ? result->value.integer < 0 : 0;
    if (!failed) { r->kind = FREE; f->live--; *disposed = 1; }
    return 0;
}
ForeignId foreign_alias_handle(Foreign *f, ForeignId id) {
    Resource *r = find(f, id);
    if (!r || (r->kind != POINTER && r->kind != HANDLE) || r->retiring) {
        fail(f, EINVAL, "opaque adoption requires a native pointer"); return 0;
    }
    if (r->kind == HANDLE) return id;
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind != FREE && f->resources[i].parent == id) {
        fail(f, EBUSY, "opaque adoption requires no memory views"); return 0;
    }
    Resource *owner = find(f, r->parent);
    ForeignId library = owner && owner->kind == LIBRARY ? owner->id :
        owner && owner->kind == CALLBACK ? f->active_library : 0;
    if (!library) { fail(f, EINVAL, "opaque adoption cannot alias Rune storage"); return 0; }
    void *address = r->address;
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind == HANDLE && f->resources[i].address == address)
        return f->resources[i].id;
    Resource *alias = reserve(f);
    if (!alias) return 0;
    alias->kind = HANDLE; alias->parent = library; alias->address = address; f->live++;
    return alias->id;
}
int foreign_consume_handle(Foreign *f, ForeignId id, ForeignId call, const ForeignValue *arguments, size_t count,
                           ForeignFailure failure, ForeignValue *result, ForeignError *captured, int *disposed) {
    *disposed = 0;
    Resource *r = find(f, id), *destructor = find(f, call);
    if (!r || !destructor || r->kind != HANDLE || destructor->kind != CALL) {
        fail(f, EINVAL, "opaque destruction requires an adopted handle"); return -1;
    }
    if (r->retiring) { fail(f, EBUSY, "opaque handle destruction is already active"); return -1; }
    ForeignType t = destructor->call->result;
    int signed_type = t == FOREIGN_I8 || t == FOREIGN_I16 || t == FOREIGN_I32 || t == FOREIGN_I64;
    if (t > FOREIGN_U64 || (unsigned)failure > FOREIGN_FAIL_NEGATIVE ||
        (t == FOREIGN_VOID && failure != FOREIGN_FAIL_NEVER) || (failure == FOREIGN_FAIL_NEGATIVE && !signed_type)) {
        fail(f, EINVAL, "unsupported opaque destructor result"); return -1;
    }
    void *address = r->address;
    r->retiring = 1;
    int status = call_checked(f, call, arguments, count, result, captured, id);
    r = find(f, id); r->retiring = 0;
    if (status) return status;
    int failed = failure == FOREIGN_FAIL_ZERO ? result->value.word == 0 :
                 failure == FOREIGN_FAIL_NONZERO ? result->value.word != 0 :
                 failure == FOREIGN_FAIL_NEGATIVE ? result->value.integer < 0 : 0;
    if (!failed) {
        /* All aliases are tombstoned together. Suspended native callers
           retain bookkeeping slots until their leases are surrendered. */
        for (size_t i = 0; i < f->count; i++) {
            Resource *a = &f->resources[i];
            if ((a->kind == HANDLE || a->kind == POINTER) && a->address == address) {
                a->kind = a->active ? RETIRED : FREE; f->live--;
            }
        }
        *disposed = 1;
    }
    return 0;
}
int foreign_release(Foreign *f, ForeignId id) {
    Resource *r = find(f, id);
    if (!r) return -1;
    if (r->active || r->retiring) { fail(f, EBUSY, "foreign resource is active or being destroyed"); return -1; }
    if (r->kind == CALL && r->call->active) { fail(f, EBUSY, "foreign call is active"); return -1; }
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind != FREE && f->resources[i].parent == id) {
        fail(f, EBUSY, "foreign resource has live dependents"); return -1;
    }
    if (r->kind == LIBRARY && f->system.close(r->address) != 0) { native_error(f); return -1; }
    if (r->kind == MEMORY) free(r->address);
    if (r->kind == CALL) { free(r->call->types); free(r->call->arguments); free(r->call); }
    if (r->kind == CALLBACK) {
        Callback *c = r->callback;
        if (callback_disable(c) & ~UINT64_C(1)) {
            callback_enable(c);
            fail(f, EBUSY, "foreign callback entry is active"); return -1;
        }
        ffi_closure_free(c->closure);
        if (c->release) c->release(c->state);
        free(c->failures); free(c->signature.types); free(c->signature.arguments); free(c);
    }
    r->kind = FREE; f->live--;
    return 0;
}
int foreign_destroy(Foreign *f) {
    if (!f) return 0;
    if (f->owner_thread != &thread_marker || f->call_depth) {
        fail(f, EBUSY, "foreign context has an active call or another owner thread"); return -1;
    }
    for (size_t i = 0; i < f->count; i++) {
        Resource *r = &f->resources[i];
        if (r->kind != FREE && (r->active || r->retiring || (r->kind == CALL && r->call->active))) {
            fail(f, EBUSY, "foreign context has active resources"); return -1;
        }
    }
    if (!f->closing) {
        int active = 0;
        for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind == CALLBACK)
            if (callback_disable(f->resources[i].callback) & ~UINT64_C(1)) active = 1;
        if (active) {
            for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind == CALLBACK)
                callback_enable(f->resources[i].callback);
            fail(f, EBUSY, "foreign context has an active callback entry"); return -1;
        }
        f->closing = 1;
    }
    /* Provider destructors may invoke registered callbacks and read retained
       memory. Disable SML first, keeping both alive through every unload. */
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind == LIBRARY) {
        Resource *r = &f->resources[i];
        if (f->system.close(r->address) != 0) { native_error(f); return -1; }
        r->kind = FREE; f->live--;
    }
    for (size_t i = 0; i < f->count; i++) {
        Resource *r = &f->resources[i];
        if (r->kind == CALLBACK) callback_quarantine(r->callback);
        if (r->kind == MEMORY) free(r->address);
        if (r->kind == CALL) { free(r->call->types); free(r->call->arguments); free(r->call); }
    }
    free(f->resources); free(f); return 0;
}
void foreign_abandon(Foreign *f) {
    /* Terminal process exit only: native callers still own their VM roots
       and arenas. Leave them alive, but make all subsequent entries fail. */
    if (!f) return;
    for (size_t i = 0; i < f->count; i++) if (f->resources[i].kind == CALLBACK)
        (void)callback_disable(f->resources[i].callback);
}
size_t foreign_quarantined(void) { return (size_t)ID_LOAD(&quarantine_count); }
#else
#include <stdlib.h>
#include <string.h>
struct Foreign { ForeignError error; };
static uint64_t identity_floor = 1;
uint64_t foreign_identity_floor(void) { return identity_floor; }
int foreign_restore_identity_floor(uint64_t floor) {
    if (!floor) { errno = EINVAL; return -1; }
    if (floor > identity_floor) identity_floor = floor;
    return 0;
}
static int unavailable(Foreign *f) {
    f->error.error_number = ENOSYS;
    f->error.native_error = 0;
    strcpy(f->error.message, "runtime built without libffi support");
    return -1;
}
int foreign_available(void) { return 0; }
Foreign *foreign_create(const ForeignSystem *system) { (void)system; return calloc(1, sizeof(Foreign)); }
int foreign_destroy(Foreign *f) { free(f); return 0; }
void foreign_abandon(Foreign *f) { (void)f; }
size_t foreign_quarantined(void) { return 0; }
const ForeignError *foreign_error(const Foreign *f) { return &f->error; }
size_t foreign_live(const Foreign *f) { (void)f; return 0; }
int foreign_alive(const Foreign *f,ForeignId r) { (void)f;(void)r;return 0; }
int foreign_same(Foreign *f,ForeignId l,ForeignId r) { (void)l;(void)r;return unavailable(f); }
ForeignId foreign_library(Foreign *f,const char *p,size_t n) { (void)p;(void)n;unavailable(f);return 0; }
ForeignId foreign_symbol(Foreign *f,ForeignId l,const char *p,size_t n) { (void)l;(void)p;(void)n;unavailable(f);return 0; }
ForeignId foreign_memory(Foreign *f,size_t n) { (void)n;unavailable(f);return 0; }
int foreign_read(Foreign *f,ForeignId r,size_t o,void *p,size_t n) { (void)r;(void)o;(void)p;(void)n;return unavailable(f); }
int foreign_write(Foreign *f,ForeignId r,size_t o,const void *p,size_t n) { (void)r;(void)o;(void)p;(void)n;return unavailable(f); }
ForeignId foreign_view(Foreign *f,ForeignId r,size_t o,size_t n) { (void)r;(void)o;(void)n;unavailable(f);return 0; }
ForeignId foreign_prepare(Foreign *f,ForeignId r,int a,ForeignType t,const ForeignType *p,size_t n) { (void)r;(void)a;(void)t;(void)p;(void)n;unavailable(f);return 0; }
ForeignId foreign_prepare_variadic(Foreign *f,ForeignId r,int a,ForeignType t,const ForeignType *p,size_t n,size_t fixed) { (void)r;(void)a;(void)t;(void)p;(void)n;(void)fixed;unavailable(f);return 0; }
ForeignId foreign_callback(Foreign *f,int a,ForeignType t,const ForeignType *p,size_t n,ForeignValue v,const ForeignCallbackFailure *r,size_t z,ForeignCallback c,ForeignCallbackFree d,void *s) { (void)a;(void)t;(void)p;(void)n;(void)v;(void)r;(void)z;(void)c;(void)d;(void)s;unavailable(f);return 0; }
int foreign_callback_status(Foreign *f,ForeignId r,int z,uint64_t *n,ForeignCallbackFault *e) { (void)r;(void)z;(void)n;(void)e;return unavailable(f); }
int foreign_call(Foreign *f,ForeignId r,const ForeignValue *p,size_t n,ForeignValue *v,ForeignError *e) { (void)r;(void)p;(void)n;(void)v;(void)e;return unavailable(f); }
int foreign_dispose(Foreign *f,ForeignId r,ForeignId c,const ForeignValue *p,size_t n,ForeignFailure q,ForeignValue *v,ForeignError *e,int *d) { (void)r;(void)c;(void)p;(void)n;(void)q;(void)v;(void)e;*d=0;return unavailable(f); }
ForeignId foreign_alias_handle(Foreign *f,ForeignId r) { (void)r;unavailable(f);return 0; }
int foreign_consume_handle(Foreign *f,ForeignId r,ForeignId c,const ForeignValue *p,size_t n,ForeignFailure q,ForeignValue *v,ForeignError *e,int *d) { (void)r;(void)c;(void)p;(void)n;(void)q;(void)v;(void)e;*d=0;return unavailable(f); }
int foreign_release(Foreign *f,ForeignId r) { (void)r;return unavailable(f); }
#endif
