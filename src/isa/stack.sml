(* The stack bytecode of vm/portable (runevm) and of the programs runeopt
   makes, in the language of src/isa/isa.sml. An opcode's number is its
   place in this list, from 0. docs/bytecode.md says what each does; the
   loader of the VM checks the operands by their kinds; the body of each is
   its case of the interpreter's loop (vm/interp_cases.h, which runeisa
   writes). *)
structure StackIsa =
struct
  open Isa

  (* The version of the layout of an .rbc (docs/bytecode.md), which changes
     when the layout does; what the instructions are is the fingerprint
     IsaGen works out from them, which the file carries beside it. *)
  val rbcVersion = 3

  (* A body that is not shared is written in the words of the loop
     (vm/interp.c), which keeps the stack pointer, the frame's base, the pc
     and the count of instructions in its own variables:
     * PUSH(v), POP(), TOP(k) (the k-th from the top, which can be written)
       and LOCALV(l) (local l of the frame, which can be written) use the
       stack; the loader has made room for the deepest the function goes
       (Function.maxstack), so PUSH does not check;
     * FRAME is the frame, PC the pc of the next instruction and JUMP_TO(o)
       goes to o;
     * SYNC() gives the VM what the loop keeps, before what reads it -- the
       collector, a raise, a primitive, a frame pushed -- and RELOAD() takes
       it back after what may have changed it;
     * FATAL(...) and EXPECT(v, kind, what) stop the program where it is.
     A shared body (sharedBody) is a function of vm/ops.h, which runeopt's
     code calls too, and is written against the VM itself (vm_push, vm_pop,
     vm_top); the loop gives it the VM's state first and takes it back
     after. *)

  (* What CALL and TAILCALL share: the closure and its function checked. *)
  val callee =
    ["Value arg = POP();",
     "Value cv = POP();",
     "Obj *c = EXPECT(cv, K_CLOSURE, \"closure in call\");",
     "int64_t fidx = OBJ_FIELDS(c)[0].u.i;",
     "if (fidx < 0 || (uint64_t)fidx >= p->nfuncs) FATAL(\"bad function index\");",
     "Function *fn = &p->funcs[fidx];"]
  (* and the callee's frame at `at`: room for its locals and its deepest
     stack, local 0 the argument, the others unit, and its code entered *)
  val enter =
    ["size_t need = at + fn->nlocals + fn->maxstack;",
     "if (need > vm->stack_cap) vm_grow_stack(vm, need);",
     "Value *slot = vm->stack + at;",
     "slot[0] = arg;",
     "for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();",
     "ENTER(slot, fn);"]

  val instructions : instruction list =
    [inst ("HALT", [], (Fixed 0, 0), Halt, "Stop execution.")
       ["SYNC();",
        "return 0;"],
     inst ("CONST", [("k", Constant)], (Fixed 0, 1), Next, "Push constant pool entry k.")
       ["PUSH(p->consts[a]);"],
     inst ("INT", [("i", Immediate)], (Fixed 0, 1), Next, "Push the small integer i.")
       ["PUSH(mk_int(a));"],
     inst ("UNIT", [], (Fixed 0, 1), Next, "Push unit.")
       ["PUSH(mk_unit());"],
     inst ("CON0", [("t", Tag)], (Fixed 0, 1), Next, "Push the nullary constructor with tag t.")
       ["PUSH(mk_con0(a));"],
     inst ("LOCAL", [("l", Local)], (Fixed 0, 1), Next, "Push local slot l of the current frame.")
       ["PUSH(LOCALV(a));"],
     inst ("SETLOCAL", [("l", Local)], (Fixed 1, 0), Next, "Pop the top of stack into local slot l.")
       ["LOCALV(a) = POP();"],
     inst ("ENV", [("e", EnvSlot)], (Fixed 0, 1), Next, "Push slot e of the current closure's environment.")
       ["Obj *c = FRAME->closure;",
        "if (!c || (uint32_t)a + 1 >= c->len) FATAL(\"environment slot %d out of range\", a);",
        "PUSH(OBJ_FIELDS(c)[a + 1]);"],
     inst ("SELF", [], (Fixed 0, 1), Next, "Push the currently executing closure.")
       ["if (!FRAME->closure) FATAL(\"SELF outside a closure\");",
        "PUSH(mk_ptr(FRAME->closure));"],
     inst ("GLOBAL", [("g", Global)], (Fixed 0, 1), Next, "Push global g.")
       ["if (!vm->global_set[a]) FATAL(\"global %d read before initialization\", a);",
        "PUSH(vm->globals[a]);"],
     inst ("SETGLOBAL", [("g", Global)], (Fixed 1, 0), Next, "Pop the top of stack into global g.")
       ["vm->globals[a] = POP();",
        "vm->global_set[a] = 1;"],
     inst ("POP", [], (Fixed 1, 0), Next, "Discard the top of stack.")
       ["(void)POP();"],
     sharedBody
       (inst ("TUPLE", [("n", Count)], (OperandValue 0, 1), Next, "Pop n values (first pushed is field 0) and push a tuple.")
          ["if (a == 0) { vm_push(vm, mk_unit()); return; }",
           "if ((size_t)a > vm->sp) vm_fatal(vm, \"stack underflow\");",
           "Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, (uint32_t)a);",
           "Value *f = OBJ_FIELDS(t);",
           "for (int32_t i = 0; i < a; i++) f[i] = vm->stack[vm->sp - (size_t)a + (size_t)i];",
           "vm->sp -= (size_t)a;",
           "vm_push(vm, mk_ptr(t));"]),
     inst ("SELECT", [("i", Field)], (Fixed 1, 1), Next, "Pop a tuple and push its field i.")
       ["Value v = POP();",
        "Obj *t = EXPECT(v, K_TUPLE, \"tuple\");",
        "if ((uint32_t)a >= t->len) FATAL(\"tuple index %d out of range\", a);",
        "PUSH(OBJ_FIELDS(t)[a]);"],
     sharedBody
       (inst ("CON", [("t", Tag)], (Fixed 1, 1), Next, "Pop a value and push constructor t applied to it.")
          ["Obj *c = vm_alloc_fields(vm, K_CON, (uint16_t)a, 1);",
           "OBJ_FIELDS(c)[0] = *vm_top(vm, 0);",
           "*vm_top(vm, 0) = mk_ptr(c);"]),
     inst ("DECON", [], (Fixed 1, 1), Next, "Pop a constructor value and push its argument.")
       ["Value v = POP();",
        "Obj *c = EXPECT(v, K_CON, \"constructor with argument\");",
        "PUSH(OBJ_FIELDS(c)[0]);"],
     inst ("CONTAG", [], (Fixed 1, 1), Next, "Pop a constructor value and push its tag as an int.")
       ["Value v = POP();",
        "if (v.tag == T_CON0) PUSH(mk_int(v.u.i));",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) PUSH(mk_int(v.u.p->contag));",
        "else FATAL(\"CONTAG on non-constructor\");"],
     sharedBody
       (inst ("CLOSURE", [("f", Function), ("n", Count)], (OperandValue 1, 1), Next,
              "Pop n values (first pushed is env slot 0) into a new closure of function f.")
          ["if ((size_t)b > vm->sp) vm_fatal(vm, \"stack underflow\");",
           "Obj *c = vm_alloc_fields(vm, K_CLOSURE, 0, (uint32_t)b + 1);",
           "Value *f = OBJ_FIELDS(c);",
           "f[0] = mk_int(a);",
           "for (int32_t i = 0; i < b; i++) f[i + 1] = vm->stack[vm->sp - (size_t)b + (size_t)i];",
           "vm->sp -= (size_t)b;",
           "vm_push(vm, mk_ptr(c));"]),
     sharedBody
       (inst ("SETENV", [("e", EnvSlot)], (Fixed 2, 0), Next, "Pop value v, pop closure c, and set c.env[e] := v.")
          ["Value v = vm_pop(vm);",
           "Value cv = vm_pop(vm);",
           "Obj *c = vm_expect_obj(vm, cv, K_CLOSURE, \"closure\");",
           "if ((uint32_t)a + 1 >= c->len) vm_fatal(vm, \"environment slot %d out of range\", a);",
           "OBJ_FIELDS(c)[a + 1] = v;"]),
     inst ("CALL", [], (Fixed 2, 1), Call, "Pop argument, pop closure, and call it.")
       (callee
        @ ["size_t at = (size_t)(sp - vm->stack);",
           "vm_push_frame(vm, (uint32_t)fidx, c, PC, at);"]
        @ enter),
     inst ("TAILCALL", [], (Fixed 2, 0), TailCall, "Like CALL but the current frame is replaced.")
       (callee
        @ ["size_t at = FRAME->base;",
           "FRAME->func = (uint32_t)fidx;",
           "FRAME->closure = c;"]
        @ enter),
     inst ("RET", [], (Fixed 1, 0), Return, "Return the top of stack to the caller.")
       ["Value v = POP();",
        "size_t at = FRAME->base;",
        "uint32_t back = FRAME->ret_pc;",
        "if (vm->fp == 0) { sp = vm->stack + at; PUSH(v); JUMP_TO(back); SYNC(); return 0; }",
        "vm->fp--;",
        "sp = vm->stack + at;",
        "PUSH(v);",
        "RETURN_TO(back);"],
     inst ("JUMP", [("o", Label)], (Fixed 0, 0), Jump, "Jump to absolute code offset o.")
       ["JUMP_TO(a);"],
     inst ("JUMPIFNOT", [("o", Label)], (Fixed 1, 0), Branch, "Pop a bool; jump to o if it is false.")
       ["Value v = POP();",
        "if (v.tag != T_CON0) FATAL(\"JUMPIFNOT on non-bool\");",
        "if (v.u.i == 0) JUMP_TO(a);"],
     inst ("JUMPIF", [("o", Label)], (Fixed 1, 0), Branch, "Pop a bool; jump to o if it is true.")
       ["Value v = POP();",
        "if (v.tag != T_CON0) FATAL(\"JUMPIF on non-bool\");",
        "if (v.u.i != 0) JUMP_TO(a);"],
     withHandlers Installs
       (inst ("PUSHHANDLER", [("o", HandlerLabel)], (Fixed 0, 0), Next,
              "Install an exception handler whose code starts at o.")
          ["SYNC();",
           "vm_push_handler(vm, (uint32_t)a);"]),
     withHandlers Removes
       (inst ("POPHANDLER", [], (Fixed 0, 0), Next, "Remove the innermost exception handler.")
          ["if (vm->hp == 0) FATAL(\"POPHANDLER with no handler\");",
           "vm->hp--;"]),
     raising
       (inst ("RAISE", [], (Fixed 1, 0), Raise, "Pop an exception value and raise it.")
          ["Value v = POP();",
           "if (v.tag != T_PTR || v.u.p->kind != K_EXN) FATAL(\"RAISE of non-exception\");",
           "SYNC();",
           "vm_raise(vm, v);",
           "RELOAD();"]),
     sharedBody
       (inst ("NEWEXN", [("k", StringConstant)], (Fixed 0, 1), Next,
              "Create a fresh exception constructor named by string constant k.")
          ["Obj *c = vm_alloc_fields(vm, K_EXNCON, 0, 1);",
           "OBJ_FIELDS(c)[0] = p->consts[a];",
           "vm_push(vm, mk_ptr(c));"]),
     inst ("BUILTINEXN", [("i", BuiltinExn)], (Fixed 0, 1), Next,
           "Push builtin exception constructor i (see docs/bytecode.md).")
       ["PUSH(mk_ptr(vm->builtin_exns[a]));"],
     sharedBody
       (inst ("MKEXN", [], (Fixed 2, 1), Next, "Pop payload, pop exception constructor, push the exception value.")
          ["if (vm->sp < 2) vm_fatal(vm, \"stack underflow\");",
           "Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);",
           "Value con = vm->stack[vm->sp - 2];",
           "if (con.tag != T_PTR || con.u.p->kind != K_EXNCON) vm_fatal(vm, \"MKEXN on non-constructor\");",
           "OBJ_FIELDS(e)[0] = con;",
           "OBJ_FIELDS(e)[1] = vm->stack[vm->sp - 1];",
           "vm->sp -= 2;",
           "vm_push(vm, mk_ptr(e));"]),
     inst ("EXNCON", [], (Fixed 1, 1), Next, "Pop an exception value and push its constructor.")
       ["Value v = POP();",
        "Obj *e = EXPECT(v, K_EXN, \"exception\");",
        "PUSH(OBJ_FIELDS(e)[0]);"],
     inst ("EXNARG", [], (Fixed 1, 1), Next, "Pop an exception value and push its payload.")
       ["Value v = POP();",
        "Obj *e = EXPECT(v, K_EXN, \"exception\");",
        "PUSH(OBJ_FIELDS(e)[1]);"],
     raising
       (inst ("PRIM", [("p", Primitive)], (ArityOf 0, 1), Next,
              "Invoke primitive p; pops its arguments and pushes the result.")
          ["SYNC();",
           "/* A primitive that says PRIM_NEW_WORLD has put another program",
           "   here (Runtime.restore); RELOAD takes its code again, and the",
           "   pc with it. */",
           "(void)prim_table[a](vm);",
           "RELOAD();"]),
     inst ("JUMPIFNOTTAG", [("o", Label), ("t", Tag)], (Fixed 1, 0), Branch,
           "Pop a constructor value; jump to o unless its tag is t.")
       ["/* CONTAG; INT t; PRIM poly_eq; JUMPIFNOT o, the test of a match",
        "   against a constructor, in one */",
        "Value v = POP();",
        "int64_t tag = 0;",
        "if (v.tag == T_CON0) tag = v.u.i;",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) tag = v.u.p->contag;",
        "else FATAL(\"JUMPIFNOTTAG on non-constructor\");",
        "if (tag != b) JUMP_TO(a);"],
     inst ("TEELOCAL", [("l", Local)], (Fixed 1, 1), Next,
           "Store the top of stack into local slot l and leave it there: SETLOCAL l; LOCAL l in one.")
       ["LOCALV(a) = TOP(0);"]]

  (* The same by opcode number. *)
  val info : instruction vector = Vector.fromList instructions
end
