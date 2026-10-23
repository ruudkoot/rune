#include "foreign.h"
#include <errno.h>
#include <stdio.h>
int main(void) {
    Foreign *f = foreign_create(NULL);
    if (!f || foreign_available() || foreign_live(f) != 0) return 1;
    if (foreign_library(f, "missing", 7) != 0 || foreign_error(f)->error_number != ENOSYS) return 1;
    if (foreign_memory(f, 1) != 0 || foreign_error(f)->error_number != ENOSYS) return 1;
    foreign_destroy(f);
    puts("PASS foreign disabled C: no libffi dependency");
    return 0;
}
