#ifndef RUNE_VM_H
#define RUNE_VM_H

#include <stddef.h>
#include <stdint.h>

enum rune_vm_status {
    RUNE_VM_OK = 0,
    RUNE_VM_INVALID_BYTECODE = 1
};

enum rune_vm_status rune_vm_run(const uint8_t *program, size_t length);

#endif
