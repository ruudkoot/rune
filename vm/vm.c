/* Rune virtual machine: ISO C11, explicit frames and a non-moving heap. */
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "opcode.h"

_Static_assert(CHAR_BIT == 8, "Rune requires 8-bit bytes");
_Static_assert(sizeof(uint32_t) == 4 && sizeof(int64_t) == 8, "Rune requires exact integer types");
#define MAX_FILE (16u * 1024u * 1024u)
#define MAX_STRING (1024u * 1024u)
#define MAX_COUNT 65536u
#define MAX_HEAP (64u * 1024u * 1024u)
#define GC_INTERVAL (64u * 1024u)

/* The intrusive mark worklist needs no allocation, even when the heap is full.
   The alignment member keeps the following payload suitable for every C type. */
typedef struct Allocation {
    struct Allocation *next, *gray;
    size_t bytes;
    int aggregate, marked;
    max_align_t alignment;
} Allocation;
typedef struct { size_t length; unsigned char data[]; } Blob;
typedef struct Aggregate Aggregate;
typedef enum { INVALID, INTEGER, BOOLEAN, STRING, UNIT, BUILTIN, TUPLE, CLOSURE,
               DATA0, DATA1, CONSTRUCTOR } Tag;
typedef struct {
    Tag tag;
    union { int32_t integer; uint32_t number; Blob *string; Aggregate *aggregate; } as;
} Value;
struct Aggregate { uint32_t count, function; Value values[]; };
typedef struct Root { struct Root *previous; Value *values; size_t count; } Root;
typedef struct { Value a, b; } Pair;
typedef struct { uint8_t op; uint32_t arg, line, column; } Instruction;
typedef struct { uint32_t locals, environment, count; Instruction *code; } Function;
typedef struct { uint32_t function, pc, base, stack_base; Value closure; } Frame;
typedef struct {
    unsigned char *file;
    size_t size, cursor, allocated, heap_limit, next_gc;
    Allocation *heap;
    Root *roots;
    Blob *source;
    Value *constants, *locals, *stack;
    Function *functions;
    Frame *frames;
    Pair *pairs;
    int32_t *heights;
    uint32_t *work;
    uint32_t constant_count, function_count, sp, fp, local_used, local_capacity, frame_capacity;
    int executing, gc_stress;
} Machine;
static Machine vm = {.heap_limit = MAX_HEAP, .next_gc = GC_INTERVAL};

static void cleanup(void) {
    Allocation *p = vm.heap;
    uint32_t i;
    while (p) { Allocation *next = p->next; free(p); p = next; }
    if (vm.functions) for (i = 0; i < vm.function_count; ++i) free(vm.functions[i].code);
    free(vm.file); free(vm.constants); free(vm.locals); free(vm.stack); free(vm.functions);
    free(vm.frames); free(vm.pairs); free(vm.heights); free(vm.work);
}
static void fail(int status, const char *message) {
    if (vm.executing) {
        Frame *frame = &vm.frames[vm.fp - 1];
        Function *function = &vm.functions[frame->function];
        uint32_t pc = frame->pc < function->count ? frame->pc : function->count - 1;
        Instruction in = function->code[pc];
        fprintf(stderr, "%s:%" PRIu32 ":%" PRIu32 ": runtime: %s\n",
                (const char *)vm.source->data, in.line, in.column, message);
    } else fprintf(stderr, "rune-vm: %s\n", message);
    exit(status);
}
static void malformed(const char *message) { fail(2, message); }
static void *checked_calloc(size_t count, size_t size) {
    void *p;
    if (size && count > SIZE_MAX / size) fail(3, "allocation size overflow");
    p = calloc(count ? count : 1, size);
    if (!p) fail(3, "out of memory");
    return p;
}
static void *grow(void *old, uint32_t *capacity, uint32_t needed, size_t size) {
    uint32_t n = *capacity ? *capacity : 16;
    void *p;
    if (needed > MAX_COUNT) fail(3, "frame or local stack exceeds 65536");
    if (needed <= *capacity) return old;
    while (n < needed) n *= 2;
    if (n > SIZE_MAX / size) fail(3, "allocation size overflow");
    p = realloc(old, n * size);
    if (!p) fail(3, "out of memory");
    *capacity = n;
    return p;
}
static void mark_object(void *object, Allocation **gray) {
    Allocation *p;
    if (!object) return;
    p = (Allocation *)object - 1;
    if (p->marked) return;
    p->marked = 1;
    p->gray = *gray; *gray = p;
}
static void mark_value(Value value, Allocation **gray) {
    if (value.tag == STRING) mark_object(value.as.string, gray);
    else if (value.tag == TUPLE || value.tag == CLOSURE || value.tag == DATA1)
        mark_object(value.as.aggregate, gray);
}
static void collect(void) {
    Allocation *gray = NULL, **link;
    Root *root;
    uint32_t i;
    mark_object(vm.source, &gray);
    /* Loading may collect before the constants array has been allocated. Its
       not-yet-filled entries have INVALID tags from calloc. */
    if (vm.constants) for (i = 0; i < vm.constant_count; ++i) mark_value(vm.constants[i], &gray);
    for (i = 0; i < vm.sp; ++i) mark_value(vm.stack[i], &gray);
    for (i = 0; i < vm.local_used; ++i) mark_value(vm.locals[i], &gray);
    for (i = 0; i < vm.fp; ++i) mark_value(vm.frames[i].closure, &gray);
    for (root = vm.roots; root; root = root->previous) {
        size_t n;
        for (n = 0; n < root->count; ++n) mark_value(root->values[n], &gray);
    }
    while (gray) {
        Allocation *p = gray;
        gray = p->gray;
        if (p->aggregate) {
            Aggregate *a = (Aggregate *)(p + 1);
            for (i = 0; i < a->count; ++i) mark_value(a->values[i], &gray);
        }
    }
    link = &vm.heap;
    while (*link) {
        Allocation *p = *link;
        if (p->marked) { p->marked = 0; link = &p->next; }
        else { *link = p->next; vm.allocated -= p->bytes; free(p); }
    }
    /* Give the live set room to double, with a floor for small programs. */
    vm.next_gc = vm.allocated > vm.heap_limit / 2 ? vm.heap_limit : vm.allocated * 2;
    if (vm.next_gc < GC_INTERVAL) vm.next_gc = GC_INTERVAL;
    if (vm.next_gc > vm.heap_limit) vm.next_gc = vm.heap_limit;
}
static void *allocate(size_t size, int is_aggregate) {
    Allocation *p;
    size_t bytes;
    if (size > SIZE_MAX - sizeof(Allocation)) fail(3, "allocation size overflow");
    bytes = sizeof(Allocation) + size;
    if (vm.gc_stress || vm.allocated >= vm.next_gc || bytes > vm.next_gc - vm.allocated)
        collect();
    if (bytes > vm.heap_limit - vm.allocated) fail(3, "heap limit exceeded");
    p = calloc(1, bytes);
    if (!p) { collect(); p = calloc(1, bytes); }
    if (!p) fail(3, "out of memory");
    p->bytes = bytes; p->aggregate = is_aggregate; p->next = vm.heap;
    vm.heap = p; vm.allocated += bytes;
    return p + 1;
}
static Blob *blob(size_t length) {
    Blob *p;
    if (length > MAX_STRING) fail(3, "string exceeds 1 MiB");
    p = allocate(sizeof(Blob) + length + 1, 0); p->length = length;
    return p;
}
static Aggregate *aggregate(uint32_t count, uint32_t function) {
    Aggregate *p;
    if (count > MAX_COUNT || (count && sizeof(Value) > (SIZE_MAX - sizeof(Aggregate)) / count))
        fail(3, "aggregate size overflow");
    p = allocate(sizeof(Aggregate) + count * sizeof(Value), 1);
    p->count = count; p->function = function;
    return p;
}
/* Only allocate() can collect. Newly returned objects must be published to a
   root before the next managed allocation. grow(), equality, enter(), and
   return_value() do not collect; their temporary C values need no extra roots. */
static uint8_t read8(void) {
    if (vm.cursor >= vm.size) malformed("truncated bytecode");
    return vm.file[vm.cursor++];
}
static uint32_t read32(void) {
    uint32_t result = 0;
    unsigned shift;
    for (shift = 0; shift < 32; shift += 8) result |= (uint32_t)read8() << shift;
    return result;
}
static uint32_t count32(void) {
    uint32_t n = read32();
    if (n > MAX_COUNT) malformed("bytecode count exceeds 65536");
    return n;
}
static Blob *read_string(void) {
    uint32_t n = read32();
    Blob *s;
    if (n > MAX_STRING) malformed("bytecode string exceeds 1 MiB");
    if ((size_t)n > vm.size - vm.cursor) malformed("truncated string");
    s = blob(n); memcpy(s->data, vm.file + vm.cursor, n); vm.cursor += n;
    return s;
}
static Value scalar(Tag tag, uint32_t number) {
    Value v; v.tag = tag; v.as.number = number; return v;
}
static Value integer(int64_t number) {
    Value v;
    if (number < INT32_MIN || number > INT32_MAX) fail(3, "uncaught exception Overflow");
    v.tag = INTEGER; v.as.integer = (int32_t)number; return v;
}
static Value string_value(Blob *s) {
    Value v; v.tag = STRING; v.as.string = s; return v;
}
static Value aggregate_value(Tag tag, Aggregate *a) {
    Value v; v.tag = tag; v.as.aggregate = a; return v;
}
static void edge(Function *f, uint32_t target, int32_t height, uint32_t *tail) {
    if (target >= f->count) malformed("control flow falls off code");
    if (vm.heights[target] == -1) {
        vm.heights[target] = height; vm.work[(*tail)++] = target;
    } else if (vm.heights[target] != height) malformed("inconsistent stack height at branch join");
}
static void verify(Function *f) {
    uint32_t i, head = 0, tail = 0;
    for (i = 0; i < f->count; ++i) vm.heights[i] = -1;
    edge(f, 0, 0, &tail);
    while (head < tail) {
        uint32_t at = vm.work[head++];
        Instruction in = f->code[at];
        int32_t height = vm.heights[at];
        int32_t pops = op_pops[in.op];
        if (in.op == OP_CLOSURE) pops = (int32_t)vm.functions[in.arg].environment;
        if (in.op == OP_TUPLE) pops = (int32_t)in.arg;
        if (height < pops) malformed("operand stack underflow");
        height = height - pops + op_pushes[in.op];
        if (height > (int32_t)MAX_COUNT) malformed("operand stack limit exceeded");
        if (in.op == OP_FAIL) {
            /* Uncaught match failure discards the entire machine state. */
        } else if (in.op == OP_HALT || in.op == OP_RETURN || in.op == OP_TAILCALL) {
            if (height) malformed("terminal instruction has leftover operands");
        } else if (in.op == OP_JUMP) edge(f, in.arg, height, &tail);
        else {
            if (in.op == OP_JUMP_FALSE) edge(f, in.arg, height, &tail);
            edge(f, at + 1, height, &tail);
        }
    }
}
static void load(const char *path) {
    FILE *file = fopen(path, "rb");
    uint32_t i, fid, total = 0;
    if (!file) { fprintf(stderr, "rune-vm: %s: %s\n", path, strerror(errno)); exit(1); }
    vm.file = checked_calloc(MAX_FILE + 1, 1);
    vm.size = fread(vm.file, 1, MAX_FILE + 1, file);
    if (ferror(file)) { fclose(file); fail(1, "cannot read bytecode"); }
    if (fclose(file)) fail(1, "cannot close bytecode input");
    if (vm.size > MAX_FILE) malformed("bytecode exceeds 16 MiB");
    for (i = 0; i < 8; ++i) if (read8() != (uint8_t)"RUNEBC\r\n"[i]) malformed("invalid bytecode magic");
    if (read32() != 3) malformed("unsupported bytecode version");
    if (read32() != 0) malformed("entry function must be zero");
    vm.function_count = count32(); vm.constant_count = count32();
    if (!vm.function_count) malformed("no entry function");
    vm.source = read_string();
    if (memchr(vm.source->data, 0, vm.source->length)) malformed("NUL in source filename");
    vm.constants = checked_calloc(vm.constant_count, sizeof(Value));
    vm.functions = checked_calloc(vm.function_count, sizeof(Function));
    vm.stack = checked_calloc(MAX_COUNT, sizeof(Value));
    vm.heights = checked_calloc(MAX_COUNT, sizeof(*vm.heights));
    vm.work = checked_calloc(MAX_COUNT, sizeof(*vm.work));
    for (i = 0; i < vm.constant_count; ++i) vm.constants[i] = string_value(read_string());
    for (fid = 0; fid < vm.function_count; ++fid) {
        Function *f = &vm.functions[fid];
        f->locals = count32(); f->environment = count32(); f->count = count32();
        total += f->count;
        if (!f->count || total > MAX_COUNT) malformed("invalid instruction count");
        if (!fid && f->environment) malformed("entry function has captures");
        if (fid && !f->locals) malformed("function has no argument slot");
        f->code = checked_calloc(f->count, sizeof(Instruction));
        for (i = 0; i < f->count; ++i) {
            Instruction *in = &f->code[i];
            in->op = read8(); in->arg = read32(); in->line = read32(); in->column = read32();
            if (in->op >= OP_COUNT) malformed("unknown opcode");
            if (!in->line || !in->column) malformed("invalid source position");
            if ((in->op == OP_HALT && fid) ||
                (!fid && (in->op == OP_RETURN || in->op == OP_TAILCALL || in->op == OP_SELF)))
                malformed("instruction is invalid in this function");
            switch (op_arg[in->op]) {
            case ARG_NONE: if (in->arg) malformed("nonzero unused operand"); break;
            case ARG_BOOL: if (in->arg > 1) malformed("invalid boolean operand"); break;
            case ARG_BUILTIN: if (in->arg > 3) malformed("invalid built-in operand"); break;
            case ARG_CONSTANT: if (in->arg >= vm.constant_count) malformed("invalid constant index"); break;
            case ARG_LOCAL: if (in->arg >= f->locals) malformed("invalid local index"); break;
            case ARG_ENVIRONMENT: if (in->arg >= f->environment) malformed("invalid environment index"); break;
            case ARG_FUNCTION: if (!in->arg || in->arg >= vm.function_count) malformed("invalid closure function"); break;
            case ARG_ARITY: if (in->arg < 2 || in->arg > MAX_COUNT) malformed("invalid tuple arity"); break;
            case ARG_INDEX: if (in->arg >= MAX_COUNT) malformed("invalid tuple index"); break;
            case ARG_TARGET: if (in->arg <= i || in->arg >= f->count) malformed("invalid forward branch target"); break;
            case ARG_INT: break;
            case ARG_CONSTRUCTOR:
                if (in->arg >= 2 * MAX_COUNT) malformed("invalid constructor descriptor");
                if (in->op == OP_PAYLOAD && !(in->arg & 1)) malformed("payload requires unary constructor");
                break;
            case ARG_FAILURE: if (in->arg > 1) malformed("invalid match failure operand"); break;
            default: malformed("invalid operand specification");
            }
        }
    }
    if (vm.cursor != vm.size) malformed("trailing bytecode data");
    for (fid = 0; fid < vm.function_count; ++fid) verify(&vm.functions[fid]);
}
static Value pop(void) {
    if (vm.sp <= vm.frames[vm.fp - 1].stack_base) fail(3, "operand stack underflow");
    return vm.stack[--vm.sp];
}
static void push(Value value) {
    if (vm.sp >= MAX_COUNT) fail(3, "operand stack limit exceeded");
    vm.stack[vm.sp++] = value;
}
static void require(Value value, Tag tag) {
    if (value.tag != tag) fail(3, "invalid value type in bytecode");
}
static int equal(Value a, Value b) {
    uint32_t pending = 0, steps = 0;
    if (!vm.pairs) vm.pairs = checked_calloc(MAX_COUNT, sizeof(Pair));
    vm.pairs[pending++] = (Pair){a,b};
    while (pending) {
        Pair pair = vm.pairs[--pending];
        a = pair.a; b = pair.b;
        if (++steps > 1000000u) fail(3, "equality exceeds 1000000 steps");
        if (a.tag != b.tag) {
            if ((a.tag == DATA0 && b.tag == DATA1) || (a.tag == DATA1 && b.tag == DATA0)) return 0;
            fail(3, "equality operands have different types");
        }
        switch (a.tag) {
        case INTEGER: if (a.as.integer != b.as.integer) return 0; break;
        case BOOLEAN: if (a.as.number != b.as.number) return 0; break;
        case STRING:
            if (a.as.string->length != b.as.string->length ||
                memcmp(a.as.string->data, b.as.string->data, a.as.string->length)) return 0;
            break;
        case UNIT: break;
        case DATA0: if (a.as.number != b.as.number) return 0; break;
        case DATA1: {
            Aggregate *x = a.as.aggregate, *y = b.as.aggregate;
            if (x->function != y->function) return 0;
            if (pending == MAX_COUNT) fail(3, "equality stack exceeds 65536");
            vm.pairs[pending++] = (Pair){x->values[0],y->values[0]};
            break;
        }
        case TUPLE: {
            Aggregate *x = a.as.aggregate, *y = b.as.aggregate;
            uint32_t i;
            if (x->count != y->count) fail(3, "equality tuple arities differ");
            if (x->count > MAX_COUNT - pending) fail(3, "equality stack exceeds 65536");
            for (i = x->count; i; --i) vm.pairs[pending++] = (Pair){x->values[i-1],y->values[i-1]};
            break;
        }
        default: fail(3, "value does not admit equality");
        }
    }
    return 1;
}
static Value call(Value function, Value arg) {
    if (function.tag == CONSTRUCTOR) {
        Root root = {vm.roots, &arg, 1};
        Aggregate *object;
        vm.roots = &root;
        object = aggregate(1, function.as.number);
        object->values[0] = arg;
        vm.roots = root.previous;
        return aggregate_value(DATA1, object);
    }
    require(function, BUILTIN);
    switch (function.as.number) {
    case 0:
        require(arg, STRING);
        if (fwrite(arg.as.string->data, 1, arg.as.string->length, stdout) != arg.as.string->length)
            fail(3, "output error");
        return scalar(UNIT, 0);
    case 1: {
        char buffer[32]; int n; Blob *s;
        require(arg, INTEGER);
        n = snprintf(buffer, sizeof(buffer), "%" PRId32, arg.as.integer);
        if (n < 0 || (size_t)n >= sizeof(buffer)) fail(3, "integer formatting failed");
        if (buffer[0] == '-') buffer[0] = '~';
        s = blob((size_t)n); memcpy(s->data, buffer, (size_t)n);
        return string_value(s);
    }
    case 2: require(arg, BOOLEAN); return scalar(BOOLEAN, !arg.as.number);
    case 3: require(arg, INTEGER); return integer(-(int64_t)arg.as.integer);
    default: fail(3, "invalid built-in function"); return scalar(UNIT, 0);
    }
}
static Value binary(uint8_t op, Value a, Value b) {
    int64_t left, right, quotient, remainder;
    if (op == OP_EQ || op == OP_NE) return scalar(BOOLEAN, (uint32_t)(equal(a,b) ^ (op == OP_NE)));
    if (op == OP_CONCAT) {
        Blob *s; size_t alen, blen;
        Value operands[] = {a, b};
        Root root = {vm.roots, operands, 2};
        require(a, STRING); require(b, STRING);
        alen = a.as.string->length; blen = b.as.string->length;
        if (blen > MAX_STRING - alen) fail(3, "string exceeds 1 MiB");
        vm.roots = &root;
        s = blob(alen + blen); memcpy(s->data, a.as.string->data, alen);
        memcpy(s->data + alen, b.as.string->data, blen);
        vm.roots = root.previous;
        return string_value(s);
    }
    require(a, INTEGER); require(b, INTEGER);
    left = a.as.integer; right = b.as.integer;
    switch (op) {
    case OP_ADD: return integer(left + right);
    case OP_SUB: return integer(left - right);
    case OP_MUL: return integer(left * right);
    case OP_DIV: case OP_MOD:
        if (!right) fail(3, "uncaught exception Div");
        quotient = left / right; remainder = left % right;
        if (remainder && ((remainder < 0) != (right < 0))) { --quotient; remainder += right; }
        return integer(op == OP_DIV ? quotient : remainder);
    case OP_LT: return scalar(BOOLEAN, left < right);
    case OP_LE: return scalar(BOOLEAN, left <= right);
    case OP_GT: return scalar(BOOLEAN, left > right);
    case OP_GE: return scalar(BOOLEAN, left >= right);
    default: fail(3, "invalid binary operation"); return scalar(UNIT, 0);
    }
}
/* A return restores saved VM state; no Rune call uses the C call stack. */
static void return_value(Value result) {
    Frame *frame = &vm.frames[vm.fp - 1];
    if (vm.fp <= 1 || vm.sp != frame->stack_base) fail(3, "invalid return stack");
    vm.local_used = frame->base; --vm.fp; push(result);
}
static void enter(Value closure, Value argument, int tail) {
    Aggregate *object;
    Function *function;
    uint32_t base, stack_base;
    Frame *frame;
    require(closure, CLOSURE); object = closure.as.aggregate;
    if (!object->function || object->function >= vm.function_count) fail(3, "invalid closure function");
    function = &vm.functions[object->function];
    if (object->count != function->environment) fail(3, "invalid closure environment");
    frame = &vm.frames[vm.fp - 1];
    base = tail ? frame->base : vm.local_used;
    stack_base = tail ? frame->stack_base : vm.sp;
    if (tail && vm.sp != stack_base) fail(3, "invalid tail call stack");
    if (function->locals > MAX_COUNT - base) fail(3, "local stack exceeds 65536");
    vm.locals = grow(vm.locals, &vm.local_capacity, base + function->locals, sizeof(Value));
    memset(vm.locals + base, 0, function->locals * sizeof(Value));
    vm.locals[base] = argument; vm.local_used = base + function->locals;
    if (!tail) {
        if (vm.fp >= MAX_COUNT) fail(3, "frame stack exceeds 65536");
        vm.frames = grow(vm.frames, &vm.frame_capacity, vm.fp + 1, sizeof(Frame));
        ++vm.frames[vm.fp - 1].pc;
        ++vm.fp;
    }
    vm.frames[vm.fp - 1] = (Frame){object->function,0,base,stack_base,closure};
}
static void execute(void) {
    vm.frames = grow(vm.frames, &vm.frame_capacity, 1, sizeof(Frame));
    vm.frames[0] = (Frame){0,0,0,0,{INVALID,{0}}}; vm.fp = 1;
    vm.locals = grow(vm.locals, &vm.local_capacity, vm.functions[0].locals, sizeof(Value));
    vm.local_used = vm.functions[0].locals;
    if (vm.local_used) memset(vm.locals, 0, vm.local_used * sizeof(Value));
    vm.executing = 1;
    for (;;) {
        Frame *frame = &vm.frames[vm.fp - 1];
        Function *function = &vm.functions[frame->function];
        Instruction in;
        if (frame->pc >= function->count) fail(3, "control flow fell off code");
        in = function->code[frame->pc];
        switch (in.op) {
        case OP_HALT:
            if (vm.sp || vm.fp != 1) fail(3, "invalid HALT stack");
            if (fflush(stdout)) fail(3, "output error");
            return;
        case OP_INT: push(integer(in.arg > INT32_MAX ? (int64_t)in.arg - INT64_C(4294967296) : (int64_t)in.arg)); break;
        case OP_BOOL: push(scalar(BOOLEAN, in.arg)); break;
        case OP_UNIT: push(scalar(UNIT, 0)); break;
        case OP_STRING: push(vm.constants[in.arg]); break;
        case OP_BUILTIN: push(scalar(BUILTIN, in.arg)); break;
        case OP_CONSTRUCTOR: push(scalar((in.arg & 1) ? CONSTRUCTOR : DATA0, in.arg)); break;
        case OP_IS_CON: {
            Value value = pop(); uint32_t descriptor;
            if (value.tag == DATA0) descriptor = value.as.number;
            else { require(value, DATA1); descriptor = value.as.aggregate->function; }
            push(scalar(BOOLEAN, descriptor == in.arg)); break;
        }
        case OP_PAYLOAD: {
            Value value = pop(); require(value, DATA1);
            if (value.as.aggregate->function != in.arg) fail(3, "constructor payload mismatch");
            push(value.as.aggregate->values[0]); break;
        }
        case OP_FAIL: fail(3, in.arg ? "uncaught exception Bind" : "uncaught exception Match"); break;
        case OP_LOAD:
            if (vm.locals[frame->base + in.arg].tag == INVALID) fail(3, "uninitialized local slot");
            push(vm.locals[frame->base + in.arg]); break;
        case OP_STORE: vm.locals[frame->base + in.arg] = pop(); break;
        case OP_POP: (void)pop(); break;
        case OP_DUP: { Value v = pop(); push(v); push(v); break; }
        case OP_ENV: push(frame->closure.as.aggregate->values[in.arg]); break;
        case OP_SELF: push(frame->closure); break;
        case OP_CLOSURE: case OP_TUPLE: {
            uint32_t count = in.op == OP_TUPLE ? in.arg : vm.functions[in.arg].environment;
            Aggregate *object = aggregate(count, in.op == OP_TUPLE ? 0 : in.arg);
            uint32_t i;
            for (i = count; i; --i) object->values[i-1] = pop();
            push(aggregate_value(in.op == OP_TUPLE ? TUPLE : CLOSURE, object)); break;
        }
        case OP_GET: {
            Value tuple = pop(); require(tuple, TUPLE);
            if (in.arg >= tuple.as.aggregate->count) fail(3, "tuple index out of bounds");
            push(tuple.as.aggregate->values[in.arg]); break;
        }
        case OP_CHECK_UNIT: require(pop(), UNIT); break;
        case OP_CHECK_TUPLE: {
            Value tuple = pop(); require(tuple, TUPLE);
            if (tuple.as.aggregate->count != in.arg) fail(3, "tuple pattern arity mismatch");
            push(tuple); break;
        }
        case OP_RETURN: { Value result = pop(); return_value(result); continue; }
        case OP_CALL: case OP_TAILCALL: {
            Value arg = pop(); Value callable = pop();
            if (callable.tag == BUILTIN || callable.tag == CONSTRUCTOR) {
                Value result = call(callable, arg);
                if (in.op == OP_TAILCALL) { return_value(result); continue; }
                push(result);
            } else { enter(callable, arg, in.op == OP_TAILCALL); continue; }
            break;
        }
        case OP_JUMP: frame->pc = in.arg; continue;
        case OP_JUMP_FALSE: {
            Value condition = pop(); require(condition, BOOLEAN);
            if (!condition.as.number) { frame->pc = in.arg; continue; } break;
        }
        default: { Value b = pop(); Value a = pop(); push(binary(in.op, a, b)); break; }
        }
        ++frame->pc;
    }
}
static void usage(FILE *out) {
    fputs("Usage: rune-vm [--heap-limit BYTES] [--gc-stress] [--] PROGRAM.rbc\n"
          "  --heap-limit BYTES  Managed heap ceiling, 1 through 67108864 (default).\n"
          "  --gc-stress         Collect before every managed allocation.\n", out);
}
static size_t heap_limit(const char *text) {
    size_t n = 0;
    const unsigned char *s = (const unsigned char *)text;
    if (!*s) fail(1, "invalid heap limit (expected 1 through 67108864 bytes)");
    for (; *s; ++s) {
        if (*s < '0' || *s > '9' || n > (MAX_HEAP - (size_t)(*s - '0')) / 10)
            fail(1, "invalid heap limit (expected 1 through 67108864 bytes)");
        n = n * 10 + (size_t)(*s - '0');
    }
    if (!n) fail(1, "invalid heap limit (expected 1 through 67108864 bytes)");
    return n;
}
int main(int argc, char **argv) {
    int i;
    if (atexit(cleanup)) { fputs("rune-vm: cannot register cleanup\n", stderr); return 1; }
    if (argc == 2 && strcmp(argv[1], "--version") == 0) { puts("Rune VM 0.2.0 (bytecode v3)"); return 0; }
    if (argc == 2 && strcmp(argv[1], "--help") == 0) { usage(stdout); return 0; }
    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--") == 0) { ++i; break; }
        if (strcmp(argv[i], "--gc-stress") == 0) vm.gc_stress = 1;
        else if (strcmp(argv[i], "--heap-limit") == 0 && i + 1 < argc)
            vm.heap_limit = heap_limit(argv[++i]);
        else if (argv[i][0] == '-') { usage(stderr); return 1; }
        else break;
    }
    if (i != argc - 1) { usage(stderr); return 1; }
    if (vm.next_gc > vm.heap_limit) vm.next_gc = vm.heap_limit;
    load(argv[i]);
    execute(); return 0;
}
