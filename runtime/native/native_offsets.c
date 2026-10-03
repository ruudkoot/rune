/* Prints, as assembler directives, what the code runeopt makes needs to know
   of the VM's layout: the offsets of the fields it reads and writes, and the
   numbers of the tags and kinds it tests. runeopt writes these names, never
   the numbers, so what it writes does not depend on the layout, and the
   Makefile makes build/librune/rune-offsets.s with this for the program to
   include (docs/native.md, What the executable holds). */
#include "native_offsets.h"

#define SET(name, value) printf(".set %s, %lu\n", name, (unsigned long)(value));

int main(void) {
    NATIVE_OFFSETS(SET)
    return 0;
}
