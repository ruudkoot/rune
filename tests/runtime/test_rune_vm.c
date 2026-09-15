#include "../../src/runtime/rune_vm.h"

#include <assert.h>

int main(void)
{
    const uint8_t halt[] = {'R', 'U', 'N', 'E', 1u, 0u};
    const uint8_t invalid[] = {'R', 'U', 'N', 'E', 1u, 255u};
    const uint8_t arithmetic[] = {
        'R', 'U', 'N', 'E', 1u,
        1u, 0u, 0u, 0u, 2u,
        1u, 0u, 0u, 0u, 3u,
        5u, 0u
    };
    const uint8_t conditional[] = {
        'R', 'U', 'N', 'E', 1u,
        2u, 1u,
        15u, 0u, 0u, 0u, 22u,
        1u, 0u, 0u, 0u, 7u,
        16u, 0u, 0u, 0u, 27u,
        1u, 0u, 0u, 0u, 9u,
        0u
    };

    assert(rune_vm_run(halt, sizeof halt) == RUNE_VM_OK);
    assert(rune_vm_run(arithmetic, sizeof arithmetic) == RUNE_VM_OK);
    assert(rune_vm_run(conditional, sizeof conditional) == RUNE_VM_OK);
    assert(rune_vm_run(invalid, sizeof invalid) == RUNE_VM_INVALID_BYTECODE);
    assert(rune_vm_run(NULL, 0u) == RUNE_VM_INVALID_BYTECODE);
    return 0;
}
