/* Rune M1 virtual machine: ISO C11, explicit byte encoding and checked values. */
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
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

typedef struct Blob {
    struct Blob *next;
    size_t length;
    unsigned char data[];
} Blob;
typedef enum { INVALID, INTEGER, BOOLEAN, STRING, UNIT, BUILTIN } Tag;
typedef struct {
    Tag tag;
    union { int32_t integer; uint32_t number; Blob *string; } as;
} Value;
typedef struct { uint8_t op; uint32_t arg, line, column; } Instruction;
typedef struct {
    unsigned char *file;
    size_t size, cursor, allocated;
    Blob *arena, *source;
    Value *constants, *locals, *stack;
    Instruction *code;
    int *heights;
    uint32_t *work;
    uint32_t constant_count, local_count, count, pc, sp;
    int executing;
} Machine;
static Machine vm;

static void cleanup(void) {
    Blob *p = vm.arena;
    while (p) { Blob *next = p->next; free(p); p = next; }
    free(vm.file); free(vm.constants); free(vm.locals); free(vm.stack);
    free(vm.code); free(vm.heights); free(vm.work);
}
static void fail(int status, const char *message) {
    if (vm.executing) {
        Instruction in = vm.code[vm.pc];
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
static Blob *blob(size_t length) {
    Blob *p;
    size_t bytes;
    if (length > MAX_STRING) fail(3, "string exceeds 1 MiB");
    bytes = sizeof(Blob) + length + 1;
    if (bytes > MAX_HEAP - vm.allocated) fail(3, "arena exceeds 64 MiB");
    p = checked_calloc(1, bytes);
    p->next = vm.arena; p->length = length;
    vm.arena = p; vm.allocated += bytes;
    return p;
}
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
static void edge(uint32_t target, int height, uint32_t *tail) {
    if (target >= vm.count) malformed("control flow falls off code");
    if (vm.heights[target] == -1) {
        vm.heights[target] = height;
        vm.work[(*tail)++] = target;
    } else if (vm.heights[target] != height) malformed("inconsistent stack height at branch join");
}
static void verify(void) {
    uint32_t i, head = 0, tail = 0;
    vm.heights = checked_calloc(vm.count, sizeof(*vm.heights));
    vm.work = checked_calloc(vm.count, sizeof(*vm.work));
    for (i = 0; i < vm.count; ++i) vm.heights[i] = -1;
    edge(0, 0, &tail);
    while (head < tail) {
        uint32_t at = vm.work[head++];
        Instruction in = vm.code[at];
        int height = vm.heights[at];
        if (height < op_pops[in.op]) malformed("operand stack underflow");
        height = height - op_pops[in.op] + op_pushes[in.op];
        if (height > (int)MAX_COUNT) malformed("operand stack limit exceeded");
        if (in.op == OP_HALT) {
            if (height) malformed("HALT requires an empty stack");
        } else if (in.op == OP_JUMP) edge(in.arg, height, &tail);
        else {
            if (in.op == OP_JUMP_FALSE) edge(in.arg, height, &tail);
            edge(at + 1, height, &tail);
        }
    }
}
static void load(const char *path) {
    FILE *file = fopen(path, "rb");
    uint32_t i;
    if (!file) { fprintf(stderr, "rune-vm: %s: %s\n", path, strerror(errno)); exit(1); }
    vm.file = checked_calloc(MAX_FILE + 1, 1);
    vm.size = fread(vm.file, 1, MAX_FILE + 1, file);
    if (ferror(file)) { fclose(file); fail(1, "cannot read bytecode"); }
    if (fclose(file)) fail(1, "cannot close bytecode input");
    if (vm.size > MAX_FILE) malformed("bytecode exceeds 16 MiB");
    for (i = 0; i < 8; ++i) if (read8() != (uint8_t)"RUNEBC\r\n"[i]) malformed("invalid bytecode magic");
    if (read32() != 1) malformed("unsupported bytecode version");
    vm.local_count = count32(); vm.constant_count = count32(); vm.count = count32();
    if (!vm.count) malformed("empty instruction stream");
    vm.source = read_string();
    if (memchr(vm.source->data, 0, vm.source->length)) malformed("NUL in source filename");
    vm.constants = checked_calloc(vm.constant_count, sizeof(Value));
    vm.locals = checked_calloc(vm.local_count, sizeof(Value));
    vm.stack = checked_calloc(MAX_COUNT, sizeof(Value));
    vm.code = checked_calloc(vm.count, sizeof(Instruction));
    for (i = 0; i < vm.constant_count; ++i) vm.constants[i] = string_value(read_string());
    for (i = 0; i < vm.count; ++i) {
        Instruction *in = &vm.code[i];
        in->op = read8(); in->arg = read32(); in->line = read32(); in->column = read32();
        if (in->op >= OP_COUNT) malformed("unknown opcode");
        if (!in->line || !in->column) malformed("invalid source position");
        switch (op_arg[in->op]) {
        case ARG_NONE: if (in->arg) malformed("nonzero unused operand"); break;
        case ARG_BOOL: if (in->arg > 1) malformed("invalid boolean operand"); break;
        case ARG_BUILTIN: if (in->arg > 3) malformed("invalid built-in operand"); break;
        case ARG_CONSTANT: if (in->arg >= vm.constant_count) malformed("invalid constant index"); break;
        case ARG_LOCAL: if (in->arg >= vm.local_count) malformed("invalid local index"); break;
        case ARG_TARGET: if (in->arg <= i || in->arg >= vm.count) malformed("invalid forward branch target"); break;
        case ARG_INT: break;
        default: malformed("invalid operand specification");
        }
    }
    if (vm.cursor != vm.size) malformed("trailing bytecode data");
    verify();
}
static Value pop(void) {
    if (!vm.sp) fail(3, "operand stack underflow");
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
    if (a.tag != b.tag) fail(3, "equality operands have different types");
    switch (a.tag) {
    case INTEGER: return a.as.integer == b.as.integer;
    case BOOLEAN: return a.as.number == b.as.number;
    case STRING: return a.as.string->length == b.as.string->length &&
        memcmp(a.as.string->data, b.as.string->data, a.as.string->length) == 0;
    case UNIT: return 1;
    default: fail(3, "value does not admit equality"); return 0;
    }
}
static Value call(Value function, Value arg) {
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
        require(a, STRING); require(b, STRING);
        alen = a.as.string->length; blen = b.as.string->length;
        if (blen > MAX_STRING - alen) fail(3, "string exceeds 1 MiB");
        s = blob(alen + blen); memcpy(s->data, a.as.string->data, alen);
        memcpy(s->data + alen, b.as.string->data, blen); return string_value(s);
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
static void execute(void) {
    vm.executing = 1;
    for (vm.pc = 0; vm.pc < vm.count;) {
        Instruction in = vm.code[vm.pc];
        switch (in.op) {
        case OP_HALT:
            if (vm.sp) fail(3, "HALT requires an empty stack");
            if (fflush(stdout)) fail(3, "output error");
            return;
        case OP_INT: push(integer(in.arg > INT32_MAX ? (int64_t)in.arg - INT64_C(4294967296) : (int64_t)in.arg)); break;
        case OP_BOOL: push(scalar(BOOLEAN, in.arg)); break;
        case OP_UNIT: push(scalar(UNIT, 0)); break;
        case OP_STRING: push(vm.constants[in.arg]); break;
        case OP_BUILTIN: push(scalar(BUILTIN, in.arg)); break;
        case OP_LOAD:
            if (vm.locals[in.arg].tag == INVALID) fail(3, "uninitialized local slot");
            push(vm.locals[in.arg]); break;
        case OP_STORE: vm.locals[in.arg] = pop(); break;
        case OP_POP: (void)pop(); break;
        case OP_CALL: { Value arg = pop(); Value function = pop(); push(call(function, arg)); break; }
        case OP_JUMP: vm.pc = in.arg; continue;
        case OP_JUMP_FALSE: {
            Value condition = pop(); require(condition, BOOLEAN);
            if (!condition.as.number) { vm.pc = in.arg; continue; } break;
        }
        default: { Value b = pop(); Value a = pop(); push(binary(in.op, a, b)); break; }
        }
        ++vm.pc;
    }
    fail(3, "control flow fell off code");
}
int main(int argc, char **argv) {
    if (atexit(cleanup)) { fputs("rune-vm: cannot register cleanup\n", stderr); return 1; }
    if (argc == 2 && strcmp(argv[1], "--version") == 0) { puts("Rune VM 0.0.1 (bytecode v1)"); return 0; }
    if (argc == 2 && strcmp(argv[1], "--help") == 0) { puts("Usage: rune-vm [--] PROGRAM.rbc"); return 0; }
    if (argc == 3 && strcmp(argv[1], "--") == 0) load(argv[2]);
    else if (argc == 2 && argv[1][0] != '-') load(argv[1]);
    else { fputs("Usage: rune-vm [--] PROGRAM.rbc\n", stderr); return 1; }
    execute();
    return 0;
}
