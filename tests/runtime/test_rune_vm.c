#include "../../src/runtime/rune_vm.h"

#include <assert.h>

int main(void)
{
    const uint8_t halt[] = {0u};
    const uint8_t invalid[] = {255u};

    assert(rune_vm_run(halt, sizeof halt) == RUNE_VM_OK);
    assert(rune_vm_run(invalid, sizeof invalid) == RUNE_VM_INVALID_BYTECODE);
    assert(rune_vm_run(NULL, 0u) == RUNE_VM_INVALID_BYTECODE);
    return 0;
}
