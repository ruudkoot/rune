(* The register bytecode of vm/new (docs/plans/middle-end.md, M5; its loop
   docs/plans/jit.md, M2), in the language of src/isa/isa.sml and its own
   kinds of operand: a register is a slot of the frame, and a list of
   registers is as long as an operand before it says, or as the arity of
   the primitive it names. An opcode's number is its place in this list,
   from 0.

   The registers of a frame are its slots on the VM's stack, from its base,
   so the collector sees every one of them (they start as unit, and one no
   longer used still holds a value). Above them the frame pushes only the
   arguments of a primitive, a call's result and the exception a raise
   leaves for CATCH: the checker works out how deep that goes
   (Function.maxstack, vm/new/isa_regs.c), a call makes room for it, and a
   push does not check. A call leaves its result for the instruction after
   it, RESULT, which the RET of the callee does itself where it can; a
   handler's code begins with CATCH, which takes the exception the raise
   left there. Both are how the runtime of vm/portable returns and raises,
   which vm/new shares (build/librune.a).

   A body is the lines of C of its case in vm/new's loop (vm/new/interp.c),
   written in the loop's words, since the loop keeps the frame's registers,
   the stack pointer, the pc and the count in its own variables:
   * `vm`, `p` (the program), `code`, `fr` (the frame), `pc` (already past
     this instruction), the operands `a`, `b`, `c` and `d` in order, and
     for a list `L` and `n`, its registers and how many;
   * R(x), register x of the frame; LIST(i), the i-th register of the
     list; PUSH(v) and POP(), above the registers, unchecked;
   * SYNC() before whatever reads the VM's stack pointer, pc or count --
     the collector, a raise, a primitive, a handler pushed, a fatal error
     -- and RELOAD() after whatever may have changed them, or moved the
     stack; ROOM(top, fn), room for a frame of fn at top, which may move
     the stack too;
   * ENTER(slot, fn), the frame's registers at slot and fn's code entered;
   * FATAL(...), a fatal error at this instruction; EXPECT(v, kind, what),
     the object v points to, of that kind, or a fatal error;
   * NEXT, on to the next instruction, for a body that ends early. *)
structure RegIsa =
struct
  open Isa

  (* What a register operand is, beside the kinds of the stack bytecode. *)
  datatype rkind =
      K of kind              (* as in the stack bytecode *)
    | Register               (* a register of the frame *)
    | Registers of int       (* a list of registers, as long as the operand at that position *)
    | PrimArgs of int        (* a list of registers, as many as the arity of the primitive there *)

  type rinstruction =
    {name : string,
     operands : (string * rkind) list,   (* each operand's letter and kind; a list comes last *)
     flow : flow,
     handlers : handlers,
     raises : bool,
     doc : string,
     body : string list}

  fun rinst (name, operands, flow, doc) (body : string list) : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = Keeps, raises = false, doc = doc, body = body}

  fun rraising ({name, operands, flow, handlers, doc, body, ...} : rinstruction) : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = handlers, raises = true, doc = doc, body = body}

  fun rhandlers (h : handlers) ({name, operands, flow, raises, doc, body, ...} : rinstruction) : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = h, raises = raises, doc = doc, body = body}

  val reg = Register

  (* What CALL and TAILCALL share: the closure in register a checked, the
     argument in register b taken; and after the frame, the callee's
     registers made at top -- register 0 is the argument, the others start
     as unit -- and its code entered. *)
  val callee =
    ["Value arg = R(b);",
     "Obj *c = EXPECT(R(a), K_CLOSURE, \"closure in call\");",
     "int64_t fidx = OBJ_FIELDS(c)[0].u.i;",
     "if (fidx < 0 || (uint64_t)fidx >= p->nfuncs) FATAL(\"bad function index\");",
     "Function *fn = &p->funcs[fidx];"]
  val enter =
    ["Value *slot = vm->stack + top;",
     "slot[0] = arg;",
     "for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();",
     "ENTER(slot, fn);"]

  val instructions : rinstruction list =
    [rinst ("HALT", [], Halt, "Stop execution.")
       ["SYNC();",
        "return 0;"],
     rinst ("MOVE", [("d", reg), ("s", reg)], Next, "Register d := register s.")
       ["R(a) = R(b);"],
     rinst ("INT", [("d", reg), ("i", K Immediate)], Next, "Register d := the small integer i.")
       ["R(a) = mk_int(b);"],
     rinst ("CONST", [("d", reg), ("k", K Constant)], Next, "Register d := constant k.")
       ["R(a) = p->consts[b];"],
     rinst ("UNIT", [("d", reg)], Next, "Register d := unit.")
       ["R(a) = mk_unit();"],
     rinst ("CON0", [("d", reg), ("t", K Tag)], Next, "Register d := the nullary constructor with tag t.")
       ["R(a) = mk_con0(b);"],
     rinst ("GLOBAL", [("d", reg), ("g", K Global)], Next, "Register d := global g.")
       ["if (!vm->global_set[b]) FATAL(\"global %d read before initialization\", b);",
        "R(a) = vm->globals[b];"],
     rinst ("SETGLOBAL", [("g", K Global), ("s", reg)], Next, "Global g := register s.")
       ["vm->globals[a] = R(b);",
        "vm->global_set[a] = 1;"],
     rinst ("ENV", [("d", reg), ("e", K EnvSlot)], Next, "Register d := slot e of the current closure's environment.")
       ["Obj *c = fr->closure;",
        "if (!c || (uint32_t)b + 1 >= c->len) FATAL(\"environment slot %d out of range\", b);",
        "R(a) = OBJ_FIELDS(c)[b + 1];"],
     rinst ("SELF", [("d", reg)], Next, "Register d := the closure running.")
       ["if (!fr->closure) FATAL(\"SELF outside a closure\");",
        "R(a) = mk_ptr(fr->closure);"],
     rinst ("CALL", [("f", reg), ("x", reg)], Call,
            "Call the closure in register f with register x; RESULT takes what it returns.")
       (callee
        @ ["size_t top = (size_t)(sp - vm->stack);",
           "ROOM(top, fn);",
           "vm_push_frame(vm, (uint32_t)fidx, c, pc, top);"]
        @ enter),
     rinst ("RESULT", [("d", reg)], Next, "Register d := what the call or primitive before it left on the stack.")
       ["R(a) = POP();"],
     rinst ("TAILCALL", [("f", reg), ("x", reg)], TailCall, "Like CALL, but the current frame is replaced.")
       (callee
        @ ["size_t top = fr->base;",
           "ROOM(top, fn);",
           "fr->func = (uint32_t)fidx;",
           "fr->closure = c;"]
        @ enter),
     rinst ("RET", [("s", reg)], Return, "Return register s to the caller.")
       ["Value v = R(a);",
        "uint32_t back = fr->ret_pc;",
        "size_t top = fr->base;   /* the caller's stack pointer, where the callee's registers began */",
        "if (vm->fp == 0) { vm->sp = top; vm->pc = back; vm->instructions = count; vm_push(vm, v); return 0; }",
        "vm->fp--;",
        "fr = &vm->frames[vm->fp];",
        "base = vm->stack + fr->base;",
        "sp = vm->stack + top;",
        "/* the caller goes on at RESULT d, which takes the value: written",
        "   into d here, and RESULT passed over; anything else takes it from",
        "   the stack, as an image resumed at RESULT does */",
        "if (code[back] == ROP_RESULT) { R(read_i32(code + back + 1)) = v; pc = back + 5; }",
        "else { PUSH(v); pc = back; }"],
     rraising
       (rinst ("PRIM", [("p", K Primitive), ("d", reg), ("args", PrimArgs 0)], Next,
               "Register d := primitive p applied to the registers of args.")
          ["/* the common case of the primitives done in the loop (vm/new/fastprim.h) */",
           "if (prim_fast(a, n, base, L, &R(b))) NEXT;",
           "for (uint32_t i = 0; i < n; i++) PUSH(R(LIST(i)));",
           "SYNC();",
           "int r = prim_table[a](vm);",
           "RELOAD();",
           "/* 1: it raised, and the handler has its exception (vm_raise) */",
           "if (r == 1) NEXT;",
           "if (r == PRIM_NEW_WORLD) FATAL(\"a primitive that changes the world in PRIM\");",
           "R(b) = POP();"]),
     rraising
       (rinst ("PRIMPUSH", [("p", K Primitive), ("args", PrimArgs 0)], Next,
               "Primitive p applied to the registers of args, its result left for RESULT: for one that saves or restores an image, which resumes at RESULT.")
          ["for (uint32_t i = 0; i < n; i++) PUSH(R(LIST(i)));",
           "SYNC();",
           "/* one that says PRIM_NEW_WORLD has put another program here",
           "   (Runtime.restore): RELOAD takes its code again, and the pc with it */",
           "(void)prim_table[a](vm);",
           "RELOAD();"]),
     rinst ("TUPLE", [("d", reg), ("n", K Count), ("fields", Registers 1)], Next,
            "Register d := a tuple of the n registers of fields.")
       ["if (n == 0) { R(a) = mk_unit(); NEXT; }",
        "SYNC();",
        "Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, n);",
        "Value *f = OBJ_FIELDS(t);",
        "for (uint32_t i = 0; i < n; i++) f[i] = R(LIST(i));",
        "R(a) = mk_ptr(t);"],
     rinst ("CLOSURE", [("d", reg), ("f", K Function), ("n", K Count), ("env", Registers 2)], Next,
            "Register d := a closure of function f capturing the n registers of env.")
       ["SYNC();",
        "Obj *cl = vm_alloc_fields(vm, K_CLOSURE, 0, n + 1);",
        "Value *f = OBJ_FIELDS(cl);",
        "f[0] = mk_int(b);",
        "for (uint32_t i = 0; i < n; i++) f[i + 1] = R(LIST(i));",
        "R(a) = mk_ptr(cl);"],
     rinst ("SELECT", [("d", reg), ("i", K Field), ("s", reg)], Next, "Register d := field i of the tuple in register s.")
       ["Obj *t = EXPECT(R(c), K_TUPLE, \"tuple\");",
        "if ((uint32_t)b >= t->len) FATAL(\"tuple index %d out of range\", b);",
        "R(a) = OBJ_FIELDS(t)[b];"],
     rinst ("CON", [("d", reg), ("t", K Tag), ("s", reg)], Next, "Register d := constructor t applied to register s.")
       ["SYNC();",
        "Obj *o = vm_alloc_fields(vm, K_CON, (uint16_t)b, 1);",
        "OBJ_FIELDS(o)[0] = R(c);",
        "R(a) = mk_ptr(o);"],
     rinst ("DECON", [("d", reg), ("s", reg), ("t", K Tag)], Next,
            "Register d := the argument of the constructor value, of tag t, in register s; --checked stops where the tag is another.")
       ["Obj *o = EXPECT(R(b), K_CON, \"constructor with argument\");",
        "if (vm->checked && o->contag != c) FATAL(\"DECON of a constructor of tag %d where %d is wanted\", (int)o->contag, (int)c);",
        "R(a) = OBJ_FIELDS(o)[0];"],
     rinst ("CONTAG", [("d", reg), ("s", reg)], Next, "Register d := the tag of the constructor value in register s, as an int.")
       ["Value v = R(b);",
        "if (v.tag == T_CON0) R(a) = mk_int(v.u.i);",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) R(a) = mk_int(v.u.p->contag);",
        "else FATAL(\"CONTAG on non-constructor\");"],
     rinst ("NEWEXN", [("d", reg), ("k", K StringConstant)], Next,
            "Register d := a fresh exception constructor named by string constant k.")
       ["SYNC();",
        "Obj *o = vm_alloc_fields(vm, K_EXNCON, 0, 1);",
        "OBJ_FIELDS(o)[0] = p->consts[b];",
        "R(a) = mk_ptr(o);"],
     rinst ("BUILTINEXN", [("d", reg), ("i", K BuiltinExn)], Next,
            "Register d := built-in exception constructor i (see docs/bytecode.md).")
       ["R(a) = mk_ptr(vm->builtin_exns[b]);"],
     rinst ("MKEXN", [("d", reg), ("c", reg), ("x", reg)], Next,
            "Register d := the exception of the constructor in register c and the payload in register x.")
       ["SYNC();",
        "Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);",
        "Value con = R(b);",
        "if (con.tag != T_PTR || con.u.p->kind != K_EXNCON) FATAL(\"MKEXN on non-constructor\");",
        "OBJ_FIELDS(e)[0] = con;",
        "OBJ_FIELDS(e)[1] = R(c);",
        "R(a) = mk_ptr(e);"],
     rinst ("EXNCON", [("d", reg), ("s", reg)], Next, "Register d := the constructor of the exception in register s.")
       ["Obj *e = EXPECT(R(b), K_EXN, \"exception\");",
        "R(a) = OBJ_FIELDS(e)[0];"],
     rinst ("EXNARG", [("d", reg), ("s", reg)], Next, "Register d := the payload of the exception in register s.")
       ["Obj *e = EXPECT(R(b), K_EXN, \"exception\");",
        "R(a) = OBJ_FIELDS(e)[1];"],
     rinst ("SETENV", [("c", reg), ("e", K EnvSlot), ("v", reg)], Next,
            "Slot e of the environment of the closure in register c := register v.")
       ["Obj *o = EXPECT(R(a), K_CLOSURE, \"closure\");",
        "if ((uint32_t)b + 1 >= o->len) FATAL(\"environment slot %d out of range\", b);",
        "OBJ_FIELDS(o)[b + 1] = R(c);"],
     rinst ("JUMP", [("o", K Label)], Jump, "Jump to absolute code offset o.")
       ["pc = (uint32_t)a;"],
     rinst ("JUMPIF", [("s", reg), ("o", K Label)], Branch, "Jump to o if register s holds true.")
       ["Value v = R(a);",
        "if (v.tag != T_CON0) FATAL(\"JUMPIF on non-bool\");",
        "if (v.u.i != 0) pc = (uint32_t)b;"],
     rinst ("JUMPIFNOT", [("s", reg), ("o", K Label)], Branch, "Jump to o if register s holds false.")
       ["Value v = R(a);",
        "if (v.tag != T_CON0) FATAL(\"JUMPIFNOT on non-bool\");",
        "if (v.u.i == 0) pc = (uint32_t)b;"],
     rinst ("JUMPIFNOTTAG", [("s", reg), ("o", K Label), ("t", K Tag)], Branch,
            "Jump to o unless the constructor value in register s has tag t.")
       ["Value v = R(a);",
        "int64_t tag = 0;",
        "if (v.tag == T_CON0) tag = v.u.i;",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) tag = v.u.p->contag;",
        "else FATAL(\"JUMPIFNOTTAG on non-constructor\");",
        "if (tag != c) pc = (uint32_t)b;"],
     rhandlers Installs
       (rinst ("PUSHHANDLER", [("o", K HandlerLabel)], Next,
               "Install an exception handler whose code starts at o, with CATCH.")
          ["SYNC();",
           "vm_push_handler(vm, (uint32_t)a);"]),
     rhandlers Removes
       (rinst ("POPHANDLER", [], Next, "Remove the innermost exception handler.")
          ["if (vm->hp == 0) FATAL(\"POPHANDLER with no handler\");",
           "vm->hp--;"]),
     rinst ("CATCH", [("d", reg)], Next, "Register d := the exception a raise left for the handler this begins.")
       ["R(a) = POP();"],
     rraising
       (rinst ("RAISE", [("s", reg)], Raise, "Raise the exception in register s.")
          ["Value v = R(a);",
           "if (v.tag != T_PTR || v.u.p->kind != K_EXN) FATAL(\"RAISE of non-exception\");",
           "SYNC();",
           "vm_raise(vm, v);",
           "RELOAD();"]),
     rinst ("CALLK", [("f", K Function), ("n", K Count), ("args", Registers 1)], Call,
            "Call function f, known, with the n registers of args, which become its registers 0 to n-1; no closure; RESULT takes what it returns.")
       ["Function *fn = &p->funcs[a];",
        "size_t top = (size_t)(sp - vm->stack);",
        "ROOM(top, fn);",
        "/* the arguments read before the frame is pushed, which R would read */",
        "Value *slot = vm->stack + top;",
        "for (uint32_t i = 0; i < n; i++) slot[i] = R(LIST(i));",
        "for (uint32_t i = n; i < fn->nlocals; i++) slot[i] = mk_unit();",
        "vm_push_frame(vm, (uint32_t)a, NULL, pc, top);",
        "ENTER(slot, fn);"],
     rinst ("TAILCALLK", [("f", K Function), ("n", K Count), ("args", Registers 1)], TailCall,
            "Like CALLK, but the current frame is replaced.")
       ["Function *fn = &p->funcs[a];",
        "size_t top = fr->base;",
        "size_t need = (size_t)(sp - vm->stack) + n;",
        "if (top + fn->nlocals + fn->maxstack > need) need = top + fn->nlocals + fn->maxstack;",
        "if (need > vm->stack_cap) { SYNC(); vm_grow_stack(vm, need); RELOAD(); }",
        "/* the arguments above the frame first, since they are its registers */",
        "Value *tmp = sp;",
        "for (uint32_t i = 0; i < n; i++) tmp[i] = R(LIST(i));",
        "Value *slot = vm->stack + top;",
        "memmove(slot, tmp, (size_t)n * sizeof(Value));",
        "for (uint32_t i = n; i < fn->nlocals; i++) slot[i] = mk_unit();",
        "fr->func = (uint32_t)a;",
        "fr->closure = NULL;",
        "ENTER(slot, fn);"],
     rinst ("SWITCH", [("s", reg), ("n", K Count)], Switch,
            "Jump to the target of the JUMP of the tag of the constructor value in register s among the n that follow, or past them.")
       ["/* the JUMPs are a table, which the loader has checked; each is",
        "   5 bytes, its target after its opcode */",
        "Value v = R(a);",
        "int64_t tag = 0;",
        "if (v.tag == T_CON0) tag = v.u.i;",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) tag = v.u.p->contag;",
        "else FATAL(\"SWITCH on non-constructor\");",
        "if (tag >= 0 && tag < b) pc = (uint32_t)read_i32(code + pc + 5 * (uint32_t)tag + 1);",
        "else pc += 5 * (uint32_t)b;"],
     rinst ("CONN", [("d", reg), ("t", K Tag), ("n", K Count), ("fields", Registers 2)], Next,
            "Register d := constructor t made of the n registers of fields: one object of n fields, for a constructor whose argument is a tuple of n (middle-end M11).")
       ["SYNC();",
        "Obj *o = vm_alloc_fields(vm, K_CON, (uint16_t)b, n);",
        "Value *f = OBJ_FIELDS(o);",
        "for (uint32_t i = 0; i < n; i++) f[i] = R(LIST(i));",
        "R(a) = mk_ptr(o);"],
     rinst ("FIELD", [("d", reg), ("s", reg), ("t", K Tag), ("i", K Field)], Next,
            "Register d := field i of the constructor value that CONN made, of tag t, in register s; --checked stops where the tag is another.")
       ["Obj *o = EXPECT(R(b), K_CON, \"constructor with fields\");",
        "if (vm->checked && o->contag != c) FATAL(\"FIELD of a constructor of tag %d where %d is wanted\", (int)o->contag, (int)c);",
        "if ((uint32_t)d >= o->len) FATAL(\"constructor field %d out of range\", d);",
        "R(a) = OBJ_FIELDS(o)[d];"]]

  (* ---- questions about the description ---- *)

  (* The operands before the list, and the list, if there is one. *)
  fun fixed (i : rinstruction) = List.filter (fn (_, Registers _) => false | (_, PrimArgs _) => false | _ => true) (#operands i)
  fun list (i : rinstruction) =
    List.find (fn (_, Registers _) => true | (_, PrimArgs _) => true | _ => false) (#operands i)

  fun check (instrs : rinstruction list) : unit =
    let
      fun instr (i : rinstruction) =
        let val nf = List.length (fixed i)
        in
          if nf > 4 then raise Bad ("register instruction " ^ #name i ^ " has more than four operands") else ();
          if List.null (#body i) then raise Bad ("register instruction " ^ #name i ^ " has no body") else ();
          case list i of
            SOME (_, Registers k) =>
              (case List.nth (#operands i, k) of
                 (_, K Count) => ()
               | _ => raise Bad ("register instruction " ^ #name i ^ " has a list whose length is no count"))
          | SOME (_, PrimArgs k) =>
              (case List.nth (#operands i, k) of
                 (_, K Primitive) => ()
               | _ => raise Bad ("register instruction " ^ #name i ^ " has a list whose length is no primitive's"))
          | _ => ();
          case list i of
            SOME l => if #1 l = #1 (List.last (#operands i)) then () else raise Bad ("register instruction " ^ #name i ^ " has its list before the end")
          | NONE => ()
        end
    in
      List.app instr instrs;
      ignore (List.foldl (fn (i : rinstruction, seen) =>
                            if StringMap.member (seen, #name i) then raise Bad ("register instruction " ^ #name i ^ " is described twice")
                            else StringMap.insert (seen, #name i, ())) StringMap.empty instrs)
    end
end
