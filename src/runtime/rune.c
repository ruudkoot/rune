#include "rune_vm.h"

#include <stdio.h>

int main(void)
{
    const uint8_t empty_program[] = {'R', 'U', 'N', 'E', 1u, 0u};
    const enum rune_vm_status status =
        rune_vm_run(empty_program, sizeof empty_program);

    if (status != RUNE_VM_OK) {
        fputs("rune: failed to execute bootstrap program\n", stderr);
        return (int)status;
    }
    return 0;
}
