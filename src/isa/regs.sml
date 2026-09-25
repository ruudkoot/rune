(* The register bytecode of vm/new (docs/plans/middle-end.md, M5), in the
   language of src/isa/isa.sml and its own kinds of operand: a register is
   a slot of the frame, and a list of registers is as long as an operand
   before it says, or as the arity of the primitive it names. An opcode's
   number is its place in this list, from 0.

   The registers of a frame are its slots on the VM's stack, from its base,
   so the collector sees every one of them (they start as unit, and one no
   longer used still holds a value). A call leaves its result on the stack
   and the instruction after it, RESULT, takes it; a handler's code begins
   with CATCH, which takes the exception the raise left there. Both are how
   the runtime of vm/portable returns and raises, which vm/new shares
   (build/librune.a).

   A body is the lines of C of its case in vm/new's loop, where `vm`, `p`
   (the program), `code`, `fr` (the frame), `op`, the operands `a`, `b`, `c`
   and `d` in order, and the list `L` (LIST(i), its i-th register) of `n`
   registers are in scope, and R(x) is register x of the frame. *)
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
     registers made -- register 0 is the argument, the others start as unit
     -- and its code entered. *)
  val callee =
    ["Value arg = R(b);",
     "Value cv = R(a);",
     "Obj *c = vm_expect_obj(vm, cv, K_CLOSURE, \"closure in call\");",
     "int64_t fidx = OBJ_FIELDS(c)[0].u.i;",
     "if (fidx < 0 || (uint64_t)fidx >= p->nfuncs) vm_fatal(vm, \"bad function index\");",
     "Function *fn = &p->funcs[fidx];"]
  val enter =
    ["if (vm->sp + fn->nlocals > vm->stack_cap) vm_grow_stack(vm, vm->sp + fn->nlocals);",
     "Value *slot = &vm->stack[vm->sp];",
     "slot[0] = arg;",
     "for (uint32_t i = 1; i < fn->nlocals; i++) slot[i] = mk_unit();",
     "vm->sp += fn->nlocals;",
     "vm->pc = fn->code_offset;"]

  val instructions : rinstruction list =
    [rinst ("HALT", [], Halt, "Stop execution.")
       ["return 0;"],
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
       ["if (!vm->global_set[b]) vm_fatal(vm, \"global %d read before initialization\", b);",
        "R(a) = vm->globals[b];"],
     rinst ("SETGLOBAL", [("g", K Global), ("s", reg)], Next, "Global g := register s.")
       ["vm->globals[a] = R(b);",
        "vm->global_set[a] = 1;"],
     rinst ("ENV", [("d", reg), ("e", K EnvSlot)], Next, "Register d := slot e of the current closure's environment.")
       ["Obj *c = fr->closure;",
        "if (!c || (uint32_t)b + 1 >= c->len) vm_fatal(vm, \"environment slot %d out of range\", b);",
        "R(a) = OBJ_FIELDS(c)[b + 1];"],
     rinst ("SELF", [("d", reg)], Next, "Register d := the closure running.")
       ["if (!fr->closure) vm_fatal(vm, \"SELF outside a closure\");",
        "R(a) = mk_ptr(fr->closure);"],
     rinst ("CALL", [("f", reg), ("x", reg)], Call,
            "Call the closure in register f with register x; RESULT takes what it returns.")
       (callee
        @ ["vm_push_frame(vm, (uint32_t)fidx, c, vm->pc, vm->sp);"]
        @ enter),
     rinst ("RESULT", [("d", reg)], Next, "Register d := what the call or primitive before it left on the stack.")
       ["Value v = vm_pop(vm);",
        "R(a) = v;"],
     rinst ("TAILCALL", [("f", reg), ("x", reg)], TailCall, "Like CALL, but the current frame is replaced.")
       (callee
        @ ["vm->sp = fr->base;",
           "fr->func = (uint32_t)fidx;",
           "fr->closure = c;"]
        @ enter),
     rinst ("RET", [("s", reg)], Return, "Return register s to the caller.")
       ["Value v = R(a);",
        "vm->sp = fr->base;",
        "vm->pc = fr->ret_pc;",
        "if (vm->fp == 0) { vm_push(vm, v); return 0; }",
        "vm->fp--;",
        "vm_push(vm, v);"],
     rraising
       (rinst ("PRIM", [("p", K Primitive), ("d", reg), ("args", PrimArgs 0)], Next,
               "Register d := primitive p applied to the registers of args.")
          ["for (uint32_t i = 0; i < n; i++) vm_push(vm, R(LIST(i)));",
           "/* 1: it raised, and the handler has its exception (vm_raise) */",
           "int r = prim_table[a](vm);",
           "if (r == 1) break;",
           "if (r == PRIM_NEW_WORLD) vm_fatal(vm, \"a primitive that changes the world in PRIM\");",
           "Value v = vm_pop(vm);",
           "R(b) = v;"]),
     rraising
       (rinst ("PRIMPUSH", [("p", K Primitive), ("args", PrimArgs 0)], Next,
               "Primitive p applied to the registers of args, its result left for RESULT: for one that saves or restores an image, which resumes at RESULT.")
          ["for (uint32_t i = 0; i < n; i++) vm_push(vm, R(LIST(i)));",
           "/* one that says PRIM_NEW_WORLD has put another program here",
           "   (Runtime.restore): take its code again, and the pc with it */",
           "if (prim_table[a](vm) == PRIM_NEW_WORLD) code = p->code;"]),
     rinst ("TUPLE", [("d", reg), ("n", K Count), ("fields", Registers 1)], Next,
            "Register d := a tuple of the n registers of fields.")
       ["if (n == 0) { R(a) = mk_unit(); break; }",
        "Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, n);",
        "Value *f = OBJ_FIELDS(t);",
        "for (uint32_t i = 0; i < n; i++) f[i] = R(LIST(i));",
        "R(a) = mk_ptr(t);"],
     rinst ("CLOSURE", [("d", reg), ("f", K Function), ("n", K Count), ("env", Registers 2)], Next,
            "Register d := a closure of function f capturing the n registers of env.")
       ["Obj *c = vm_alloc_fields(vm, K_CLOSURE, 0, n + 1);",
        "Value *f = OBJ_FIELDS(c);",
        "f[0] = mk_int(b);",
        "for (uint32_t i = 0; i < n; i++) f[i + 1] = R(LIST(i));",
        "R(a) = mk_ptr(c);"],
     rinst ("SELECT", [("d", reg), ("i", K Field), ("s", reg)], Next, "Register d := field i of the tuple in register s.")
       ["Value v = R(c);",
        "Obj *t = vm_expect_obj(vm, v, K_TUPLE, \"tuple\");",
        "if ((uint32_t)b >= t->len) vm_fatal(vm, \"tuple index %d out of range\", b);",
        "R(a) = OBJ_FIELDS(t)[b];"],
     rinst ("CON", [("d", reg), ("t", K Tag), ("s", reg)], Next, "Register d := constructor t applied to register s.")
       ["Obj *o = vm_alloc_fields(vm, K_CON, (uint16_t)b, 1);",
        "OBJ_FIELDS(o)[0] = R(c);",
        "R(a) = mk_ptr(o);"],
     rinst ("DECON", [("d", reg), ("s", reg), ("t", K Tag)], Next,
            "Register d := the argument of the constructor value, of tag t, in register s; --checked stops where the tag is another.")
       ["Value v = R(b);",
        "Obj *o = vm_expect_obj(vm, v, K_CON, \"constructor with argument\");",
        "if (vm->checked && o->contag != c) vm_fatal(vm, \"DECON of a constructor of tag %d where %d is wanted\", (int)o->contag, (int)c);",
        "R(a) = OBJ_FIELDS(o)[0];"],
     rinst ("CONTAG", [("d", reg), ("s", reg)], Next, "Register d := the tag of the constructor value in register s, as an int.")
       ["Value v = R(b);",
        "if (v.tag == T_CON0) R(a) = mk_int(v.u.i);",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) R(a) = mk_int(v.u.p->contag);",
        "else vm_fatal(vm, \"CONTAG on non-constructor\");"],
     rinst ("NEWEXN", [("d", reg), ("k", K StringConstant)], Next,
            "Register d := a fresh exception constructor named by string constant k.")
       ["Obj *o = vm_alloc_fields(vm, K_EXNCON, 0, 1);",
        "OBJ_FIELDS(o)[0] = p->consts[b];",
        "R(a) = mk_ptr(o);"],
     rinst ("BUILTINEXN", [("d", reg), ("i", K BuiltinExn)], Next,
            "Register d := built-in exception constructor i (see docs/bytecode.md).")
       ["R(a) = mk_ptr(vm->builtin_exns[b]);"],
     rinst ("MKEXN", [("d", reg), ("c", reg), ("x", reg)], Next,
            "Register d := the exception of the constructor in register c and the payload in register x.")
       ["Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);",
        "Value con = R(b);",
        "if (con.tag != T_PTR || con.u.p->kind != K_EXNCON) vm_fatal(vm, \"MKEXN on non-constructor\");",
        "OBJ_FIELDS(e)[0] = con;",
        "OBJ_FIELDS(e)[1] = R(c);",
        "R(a) = mk_ptr(e);"],
     rinst ("EXNCON", [("d", reg), ("s", reg)], Next, "Register d := the constructor of the exception in register s.")
       ["Value v = R(b);",
        "Obj *e = vm_expect_obj(vm, v, K_EXN, \"exception\");",
        "R(a) = OBJ_FIELDS(e)[0];"],
     rinst ("EXNARG", [("d", reg), ("s", reg)], Next, "Register d := the payload of the exception in register s.")
       ["Value v = R(b);",
        "Obj *e = vm_expect_obj(vm, v, K_EXN, \"exception\");",
        "R(a) = OBJ_FIELDS(e)[1];"],
     rinst ("SETENV", [("c", reg), ("e", K EnvSlot), ("v", reg)], Next,
            "Slot e of the environment of the closure in register c := register v.")
       ["Value cv = R(a);",
        "Obj *o = vm_expect_obj(vm, cv, K_CLOSURE, \"closure\");",
        "if ((uint32_t)b + 1 >= o->len) vm_fatal(vm, \"environment slot %d out of range\", b);",
        "OBJ_FIELDS(o)[b + 1] = R(c);"],
     rinst ("JUMP", [("o", K Label)], Jump, "Jump to absolute code offset o.")
       ["vm->pc = (uint32_t)a;"],
     rinst ("JUMPIF", [("s", reg), ("o", K Label)], Branch, "Jump to o if register s holds true.")
       ["Value v = R(a);",
        "if (v.tag != T_CON0) vm_fatal(vm, \"JUMPIF on non-bool\");",
        "if (v.u.i != 0) vm->pc = (uint32_t)b;"],
     rinst ("JUMPIFNOT", [("s", reg), ("o", K Label)], Branch, "Jump to o if register s holds false.")
       ["Value v = R(a);",
        "if (v.tag != T_CON0) vm_fatal(vm, \"JUMPIFNOT on non-bool\");",
        "if (v.u.i == 0) vm->pc = (uint32_t)b;"],
     rinst ("JUMPIFNOTTAG", [("s", reg), ("o", K Label), ("t", K Tag)], Branch,
            "Jump to o unless the constructor value in register s has tag t.")
       ["Value v = R(a);",
        "int64_t tag = 0;",
        "if (v.tag == T_CON0) tag = v.u.i;",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) tag = v.u.p->contag;",
        "else vm_fatal(vm, \"JUMPIFNOTTAG on non-constructor\");",
        "if (tag != c) vm->pc = (uint32_t)b;"],
     rhandlers Installs
       (rinst ("PUSHHANDLER", [("o", K HandlerLabel)], Next,
               "Install an exception handler whose code starts at o, with CATCH.")
          ["vm_push_handler(vm, (uint32_t)a);"]),
     rhandlers Removes
       (rinst ("POPHANDLER", [], Next, "Remove the innermost exception handler.")
          ["if (vm->hp == 0) vm_fatal(vm, \"POPHANDLER with no handler\");",
           "vm->hp--;"]),
     rinst ("CATCH", [("d", reg)], Next, "Register d := the exception a raise left for the handler this begins.")
       ["Value v = vm_pop(vm);",
        "R(a) = v;"],
     rraising
       (rinst ("RAISE", [("s", reg)], Raise, "Raise the exception in register s.")
          ["Value v = R(a);",
           "if (v.tag != T_PTR || v.u.p->kind != K_EXN) vm_fatal(vm, \"RAISE of non-exception\");",
           "vm_raise(vm, v);"]),
     rinst ("CALLK", [("f", K Function), ("n", K Count), ("args", Registers 1)], Call,
            "Call function f, known, with the n registers of args, which become its registers 0 to n-1; no closure; RESULT takes what it returns.")
       ["Function *fn = &p->funcs[a];",
        "if (vm->sp + fn->nlocals > vm->stack_cap) vm_grow_stack(vm, vm->sp + fn->nlocals);",
        "/* the arguments read before the frame is pushed, which R would read */",
        "Value *slot = &vm->stack[vm->sp];",
        "for (uint32_t i = 0; i < n; i++) slot[i] = R(LIST(i));",
        "for (uint32_t i = n; i < fn->nlocals; i++) slot[i] = mk_unit();",
        "vm_push_frame(vm, (uint32_t)a, NULL, vm->pc, vm->sp);",
        "vm->sp += fn->nlocals;",
        "vm->pc = fn->code_offset;"],
     rinst ("TAILCALLK", [("f", K Function), ("n", K Count), ("args", Registers 1)], TailCall,
            "Like CALLK, but the current frame is replaced.")
       ["Function *fn = &p->funcs[a];",
        "size_t base = fr->base;",
        "size_t need = vm->sp + n;",
        "if (base + fn->nlocals > need) need = base + fn->nlocals;",
        "if (need > vm->stack_cap) vm_grow_stack(vm, need);",
        "/* the arguments above the frame first, since they are its registers */",
        "Value *tmp = &vm->stack[vm->sp];",
        "for (uint32_t i = 0; i < n; i++) tmp[i] = R(LIST(i));",
        "Value *slot = &vm->stack[base];",
        "memmove(slot, tmp, (size_t)n * sizeof(Value));",
        "for (uint32_t i = n; i < fn->nlocals; i++) slot[i] = mk_unit();",
        "vm->sp = base + fn->nlocals;",
        "fr->func = (uint32_t)a;",
        "fr->closure = NULL;",
        "vm->pc = fn->code_offset;"],
     rinst ("SWITCH", [("s", reg), ("n", K Count)], Switch,
            "Jump to the target of the JUMP of the tag of the constructor value in register s among the n that follow, or past them.")
       ["/* the JUMPs are a table, which the loader has checked; each is",
        "   5 bytes, its target after its opcode */",
        "Value v = R(a);",
        "int64_t tag = 0;",
        "if (v.tag == T_CON0) tag = v.u.i;",
        "else if (v.tag == T_PTR && v.u.p->kind == K_CON) tag = v.u.p->contag;",
        "else vm_fatal(vm, \"SWITCH on non-constructor\");",
        "if (tag >= 0 && tag < b) vm->pc = (uint32_t)read_i32(code + vm->pc + 5 * (uint32_t)tag + 1);",
        "else vm->pc += 5 * (uint32_t)b;"],
     rinst ("CONN", [("d", reg), ("t", K Tag), ("n", K Count), ("fields", Registers 2)], Next,
            "Register d := constructor t made of the n registers of fields: one object of n fields, for a constructor whose argument is a tuple of n (middle-end M11).")
       ["Obj *o = vm_alloc_fields(vm, K_CON, (uint16_t)b, n);",
        "Value *f = OBJ_FIELDS(o);",
        "for (uint32_t i = 0; i < n; i++) f[i] = R(LIST(i));",
        "R(a) = mk_ptr(o);"],
     rinst ("FIELD", [("d", reg), ("s", reg), ("t", K Tag), ("i", K Field)], Next,
            "Register d := field i of the constructor value that CONN made, of tag t, in register s; --checked stops where the tag is another.")
       ["Value v = R(b);",
        "Obj *o = vm_expect_obj(vm, v, K_CON, \"constructor with fields\");",
        "if (vm->checked && o->contag != c) vm_fatal(vm, \"FIELD of a constructor of tag %d where %d is wanted\", (int)o->contag, (int)c);",
        "if ((uint32_t)d >= o->len) vm_fatal(vm, \"constructor field %d out of range\", d);",
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
