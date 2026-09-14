#include "rune_vm.h"

enum rune_vm_status rune_vm_run(const uint8_t *program, size_t length)
{
    const uint8_t halt = 0u;

    if (program == NULL || length == 0u) {
        return RUNE_VM_INVALID_BYTECODE;
    }
    return program[0] == halt ? RUNE_VM_OK : RUNE_VM_INVALID_BYTECODE;
}
