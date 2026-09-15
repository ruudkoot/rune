#include "rune_vm.h"

#include <stdbool.h>
#include <limits.h>

enum { RUNE_HEADER_SIZE = 5u, RUNE_STACK_SIZE = 256u, RUNE_LOCALS_SIZE = 256u };

struct rune_value {
    int32_t value;
    bool is_bool;
};

static uint32_t read_u32(const uint8_t *program, size_t offset)
{
    return ((uint32_t)program[offset] << 24u) |
           ((uint32_t)program[offset + 1u] << 16u) |
           ((uint32_t)program[offset + 2u] << 8u) |
           (uint32_t)program[offset + 3u];
}

enum rune_vm_status rune_vm_run(const uint8_t *program, size_t length)
{
    struct rune_value stack[RUNE_STACK_SIZE];
    struct rune_value locals[RUNE_LOCALS_SIZE];
    size_t stack_size = 0u;
    size_t ip = RUNE_HEADER_SIZE;

    if (program == NULL || length < RUNE_HEADER_SIZE + 1u ||
        program[0] != 'R' || program[1] != 'U' || program[2] != 'N' ||
        program[3] != 'E' || program[4] != 1u) {
        return RUNE_VM_INVALID_BYTECODE;
    }

    while (ip < length) {
        const uint8_t opcode = program[ip++];
        struct rune_value left;
        struct rune_value right;
        uint32_t operand;
        if (opcode == 0u) {
            return RUNE_VM_OK;
        }
        if (opcode == 1u) {
            if (ip + 4u > length || stack_size == RUNE_STACK_SIZE) return RUNE_VM_INVALID_BYTECODE;
            stack[stack_size++] = (struct rune_value){(int32_t)read_u32(program, ip), false};
            ip += 4u;
        } else if (opcode == 2u) {
            if (ip >= length || stack_size == RUNE_STACK_SIZE || program[ip] > 1u) return RUNE_VM_INVALID_BYTECODE;
            stack[stack_size++] = (struct rune_value){(int32_t)program[ip++], true};
        } else if (opcode == 3u) {
            if (ip + 4u > length || stack_size == RUNE_STACK_SIZE) return RUNE_VM_INVALID_BYTECODE;
            operand = read_u32(program, ip); ip += 4u;
            if (operand >= RUNE_LOCALS_SIZE) return RUNE_VM_INVALID_BYTECODE;
            stack[stack_size++] = locals[operand];
        } else if (opcode == 4u) {
            if (ip + 4u > length || stack_size == 0u) return RUNE_VM_INVALID_BYTECODE;
            operand = read_u32(program, ip); ip += 4u;
            if (operand >= RUNE_LOCALS_SIZE) return RUNE_VM_INVALID_BYTECODE;
            locals[operand] = stack[--stack_size];
        } else if (opcode >= 5u && opcode <= 14u) {
            if (stack_size < 2u) return RUNE_VM_INVALID_BYTECODE;
            right = stack[--stack_size]; left = stack[--stack_size];
            if (left.is_bool != right.is_bool && opcode >= 9u) return RUNE_VM_INVALID_BYTECODE;
            if (opcode <= 8u && (left.is_bool || right.is_bool)) return RUNE_VM_INVALID_BYTECODE;
            if (opcode == 8u && right.value == 0) return RUNE_VM_INVALID_BYTECODE;
            switch (opcode) {
                case 5u: {
                    const int64_t result = (int64_t)left.value + right.value;
                    if (result > INT32_MAX || result < INT32_MIN) return RUNE_VM_INVALID_BYTECODE;
                    left.value = (int32_t)result;
                    break;
                }
                case 6u: {
                    const int64_t result = (int64_t)left.value - right.value;
                    if (result > INT32_MAX || result < INT32_MIN) return RUNE_VM_INVALID_BYTECODE;
                    left.value = (int32_t)result;
                    break;
                }
                case 7u: {
                    const int64_t result = (int64_t)left.value * right.value;
                    if (result > INT32_MAX || result < INT32_MIN) return RUNE_VM_INVALID_BYTECODE;
                    left.value = (int32_t)result;
                    break;
                }
                case 8u: {
                    const int64_t result = (int64_t)left.value / right.value;
                    if (result > INT32_MAX || result < INT32_MIN) return RUNE_VM_INVALID_BYTECODE;
                    left.value = (int32_t)result;
                    break;
                }
                case 9u: left.value = left.value == right.value; left.is_bool = true; break;
                case 10u: left.value = left.value != right.value; left.is_bool = true; break;
                case 11u: left.value = left.value < right.value; left.is_bool = true; break;
                case 12u: left.value = left.value <= right.value; left.is_bool = true; break;
                case 13u: left.value = left.value > right.value; left.is_bool = true; break;
                case 14u: left.value = left.value >= right.value; left.is_bool = true; break;
                default: return RUNE_VM_INVALID_BYTECODE;
            }
            stack[stack_size++] = left;
        } else if (opcode == 15u || opcode == 16u) {
            if (ip + 4u > length) return RUNE_VM_INVALID_BYTECODE;
            operand = read_u32(program, ip); ip += 4u;
            if (operand >= length) return RUNE_VM_INVALID_BYTECODE;
            if (opcode == 15u) {
                if (stack_size == 0u || !stack[stack_size - 1u].is_bool) return RUNE_VM_INVALID_BYTECODE;
                if (!stack[--stack_size].value) ip = operand;
            } else {
                ip = operand;
            }
        } else if (opcode == 17u) {
            if (stack_size == 0u) return RUNE_VM_INVALID_BYTECODE;
            --stack_size;
        } else {
            return RUNE_VM_INVALID_BYTECODE;
        }
    }
    return RUNE_VM_INVALID_BYTECODE;
}
