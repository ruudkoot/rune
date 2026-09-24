/* Prints, as assembler directives, what the code runeopt makes needs to know
   of the VM's layout: the offsets of the fields it reads and writes, and the
   numbers of the tags and kinds it tests. runeopt writes these names, never
   the numbers, so what it writes does not depend on the layout, and the
   Makefile makes build/librune/rune-offsets.s with this for the program to
   include (docs/plans/codegen.md, D2). */
#include "vm.h"

#define SET(name, value) printf(".set %s, %lu\n", name, (unsigned long)(value))

int main(void) {
    SET("VM_STACK", offsetof(VM, stack));
    SET("VM_SP", offsetof(VM, sp));
    SET("VM_STACK_CAP", offsetof(VM, stack_cap));
    SET("VM_FRAMES", offsetof(VM, frames));
    SET("VM_FP", offsetof(VM, fp));
    SET("VM_FRAMES_CAP", offsetof(VM, frames_cap));
    SET("VM_HP", offsetof(VM, hp));
    SET("VM_CONSTS", offsetof(VM, prog.consts));
    SET("VM_GLOBALS", offsetof(VM, globals));
    SET("VM_GLOBAL_SET", offsetof(VM, global_set));
    SET("VM_BUILTIN_EXNS", offsetof(VM, builtin_exns));
    SET("VM_INSTRUCTIONS", offsetof(VM, instructions));
    SET("VM_PC", offsetof(VM, pc));
    SET("FRAME_SIZE", sizeof(Frame));
    SET("FRAME_FUNC", offsetof(Frame, func));
    SET("FRAME_RET_PC", offsetof(Frame, ret_pc));
    SET("FRAME_BASE", offsetof(Frame, base));
    SET("FRAME_CLOSURE", offsetof(Frame, closure));
    SET("FRAME_NATIVE_RET", offsetof(Frame, native_ret));
    SET("OBJ_KIND", offsetof(Obj, kind));
    SET("OBJ_CONTAG", offsetof(Obj, contag));
    SET("OBJ_LEN", offsetof(Obj, len));
    SET("OBJ_FIELDS", sizeof(Obj));
    SET("VALUE_SIZE", sizeof(Value));
    SET("VALUE_TAG", offsetof(Value, tag));
    SET("VALUE_PAYLOAD", offsetof(Value, u));
    SET("T_UNIT", T_UNIT);
    SET("T_INT", T_INT);
    SET("T_WORD", T_WORD);
    SET("T_REAL", T_REAL);
    SET("T_CHAR", T_CHAR);
    SET("T_CON0", T_CON0);
    SET("T_PTR", T_PTR);
    SET("K_TUPLE", K_TUPLE);
    SET("K_CON", K_CON);
    SET("K_CLOSURE", K_CLOSURE);
    SET("K_STRING", K_STRING);
    SET("K_REF", K_REF);
    SET("K_ARRAY", K_ARRAY);
    SET("K_EXN", K_EXN);
    return 0;
}
