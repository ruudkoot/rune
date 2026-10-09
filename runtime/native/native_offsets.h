/* runtime/native/native_offsets.h -- what code outside the VM's C needs to know of its
   layout, by name: the offsets of the fields runeopt's code and the JIT's
   templates read and write, the sizes, and the numbers of the tags and
   kinds. One list (an X-macro), so that runtime/native/native_offsets.c, which prints
   it as assembler directives for runeopt's programs, and the text backend
   of the JIT's assembler (runtime/register/jit/asm_text.c), which prints the names
   in the templates it renders, cannot disagree. NATIVE_OFFSETS(X) applies
   X(name, value) to every entry. */
#ifndef RUNE_NATIVE_OFFSETS_H
#define RUNE_NATIVE_OFFSETS_H
#include "vm.h"
#include <stddef.h>

#define NATIVE_OFFSETS(X) \
    X("VM_STACK", offsetof(VM, stack)) \
    X("VM_CHECKED", offsetof(VM, checked)) \
    X("VM_SP", offsetof(VM, sp)) \
    X("VM_STACK_CAP", offsetof(VM, stack_cap)) \
    X("VM_FRAMES", offsetof(VM, frames)) \
    X("VM_FP", offsetof(VM, fp)) \
    X("VM_FRAMES_CAP", offsetof(VM, frames_cap)) \
    X("VM_FP_LOW", offsetof(VM, fp_low)) \
    X("VM_HP", offsetof(VM, hp)) \
    X("VM_CONSTS", offsetof(VM, prog.consts)) \
    X("VM_GLOBALS", offsetof(VM, globals)) \
    X("VM_GLOBAL_SET", offsetof(VM, global_set)) \
    X("VM_BUILTIN_EXNS", offsetof(VM, builtin_exns)) \
    X("VM_INSTRUCTIONS", offsetof(VM, instructions)) \
    X("VM_PC", offsetof(VM, pc)) \
    X("VM_HEAP_FROM", offsetof(VM, alloc.from)) \
    X("VM_HEAP_SIZE", offsetof(VM, alloc.size)) \
    X("VM_HEAP_USED", offsetof(VM, alloc.used)) \
    X("VM_GC_NURSERY", offsetof(VM, gc.nursery)) \
    X("VM_GC_MARKING", offsetof(VM, gc.marking)) \
    X("VM_BYTES_ALLOCATED", offsetof(VM, bytes_allocated)) \
    X("VM_OBJECTS_ALLOCATED", offsetof(VM, objects_allocated)) \
    X("VM_GC_STRESS", offsetof(VM, gc_stress)) \
    X("VM_REAL_ZERO", offsetof(VM, real_boxes)) \
    X("FRAME_SIZE", sizeof(Frame)) \
    X("FRAME_FUNC", offsetof(Frame, func)) \
    X("FRAME_RET_PC", offsetof(Frame, ret_pc)) \
    X("FRAME_BASE", offsetof(Frame, base)) \
    X("FRAME_CLOSURE", offsetof(Frame, closure)) \
    X("FRAME_NATIVE_RET", offsetof(Frame, native_ret)) \
    X("OBJ_KIND", offsetof(Obj, kind)) \
    X("OBJ_CONTAG", offsetof(Obj, contag)) \
    X("OBJ_LEN", offsetof(Obj, len)) \
    X("OBJ_FIELDS", sizeof(Obj)) \
    X("VALUE_SIZE", sizeof(Value)) \
    X("T_UNIT", T_UNIT) \
    X("T_INT", T_INT) \
    X("T_WORD", T_WORD) \
    X("T_REAL", T_REAL) \
    X("T_CHAR", T_CHAR) \
    X("T_CON0", T_CON0) \
    X("T_PTR", T_PTR) \
    X("K_TUPLE", K_TUPLE) \
    X("K_CON", K_CON) \
    X("K_CLOSURE", K_CLOSURE) \
    X("K_STRING", K_STRING) \
    X("K_REF", K_REF) \
    X("K_ARRAY", K_ARRAY) \
    X("K_EXN", K_EXN) \
    X("K_EXNCON", K_EXNCON) \
    X("K_REAL", K_REAL) \
    X("K_BOX", K_BOX) \
    X("K_BYTES", K_BYTES) \
    X("K_REALS", K_REALS)

#endif
