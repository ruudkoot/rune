(* The register bytecode of runtime/register (docs/plans/middle-end.md, M5; its loop
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
   (Function.maxstack, runtime/register/isa_regs.c), a call makes room for it, and a
   push does not check. A call leaves its result for the instruction after
   it, RESULT, which the RET of the callee does itself where it can; a
   handler's code begins with CATCH, which takes the exception the raise
   left there. Both are how the runtime of runevm-stack returns and raises,
   which runtime/register shares (build/librune.a).

   Beside what the VM reads of it -- its operands' kinds, its flow, its
   handlers, whether it raises, its body -- an instruction says what a
   checker of the code needs (docs/plans/correctness/linting.md, D10): of
   each register operand whether it reads or writes it and what it holds
   (value), what it does beside its operands (implicit), what must come
   after it (order), and which primitives it may name. None of that is in
   the fingerprint (RegGen.canonical), since none of it changes what a
   bytecode means; RegGen writes it into the compiler's RegCodes, and
   check refuses a description whose parts do not fit together.

   A body is the lines of C of its case in runtime/register's loop (runtime/register/interp.c),
   written in the loop's words, since the loop keeps the frame's registers,
   the stack pointer, the pc and the count in its own variables:
   * `vm`, `p` (the program), `code`, `pc` (already past this
     instruction), the operands `a`, `b`, `c` and `d` in order, and for a
     list `L` and `n`, its registers and how many; vm->fp and vm->func,
     the frame's base, which names it, and its function, which the loop
     keeps exact in the VM;
   * R(x), register x of the frame; LIST(i), the i-th register of the
     list; PUSH(v) and POP(), above the registers, unchecked;
   * SYNC() before whatever reads the VM's stack pointer, pc or count --
     the collector, a raise, a primitive, a handler pushed, a fatal error
     -- and RELOAD() after whatever may have changed them, or moved the
     stack; ROOM(top, fn), room for a frame of fn at top, which may move
     the stack too; HEADER(top, pc, closure), the header of a frame whose
     registers begin at top (docs/plans/native-frames.md, M4: the caller's
     function and the pc of the RESULT it returns to, the closure, and the
     interpreter's return word), and CLOSURE(), the slot of the running
     frame's closure in its header;
   * ENTER(slot, fn), the frame's registers at slot and fn's code entered;
     HANDOVER(f), the frame handed to the driver where function f has
     native code (runtime/register/jit.h), RESUME_NATIVE(f, pc), on in function
     f's native code at pc where it has some, RAISED(), on after a raise, into the handler's native
     code where it has some, BACKWARD(t), a loop's jump back, counted and
     gone on in the function's code where it has some, POLL(len), the
     user's interrupt raised here where one waits (VM.interrupt), at a jump
     back and a call, before either does anything -- or, where the debugger
     makes it a pause (runtime/debug.c), the instruction, len bytes back,
     left to the debug loop -- RESUME_NATIVE(f, pc),
     on in function f's code at pc where a run begins there,
     RETURN_LANDING(w, v), the value v returned into compiled code at the
     landing of the return word w where the loop runs code (else on in the
     interpreter), NEW_PROGRAM(), the JIT's view made again of a program
     that became another, and DEBUG_BEGUN(), the program given to the
     driver where a primitive put the debugger's debug mode on;
   * FATAL(...), a fatal error at this instruction; EXPECT(v, kind, what),
     the object v points to, of that kind, or a fatal error;
   * NEXT, on to the next instruction, for a body that ends early. *)
structure RegIsa =
struct
  open Isa

  (* What a register an instruction reads must hold, or one it writes then
     holds: a representation the instruction fixes, or what the program
     says of what another of its operands names, by that operand's letter.
     A checker of the code takes the rest from what it knows of the
     program (the compiler's, docs/plans/correctness/linting.md M8); the
     loader checks a part (runtime/register/isa_regs.c). *)
  datatype value =
      Is of rep                     (* that representation *)
    | Like of string                (* what that register holds: a move's *)
    | ConstOf of string             (* the constant's, by its kind *)
    | GlobalOf of string            (* the global's *)
    | EnvOf of string               (* the slot's, of the running closure's environment *)
    | SlotOf of string * string     (* the slot's (the second) of the environment of the closure
                                       in the register (the first) *)
    | ResultOf of string            (* the result's of the primitive, by its type *)
    | ReturnOf of string            (* what the function returns *)
    | Returned                      (* what the running function returns *)
    | Left                          (* what the instruction before left above the registers (Leaves) *)
    | UnitOr of string * rep        (* unit where the count is 0, else that representation *)
    | ParamsOf of string            (* of a list: the function's parameters, as many as it has,
                                       each register what the parameter of its place holds *)
    | CapturesOf of string          (* of a list: the slots of the environment of a closure of
                                       the function, as many as each of its closures has, each
                                       register what the slot of its place holds *)

  (* What an operand is, beside the kinds of the stack bytecode: a register
     of the frame, read or written, or a list of registers, read. *)
  datatype rkind =
      K of kind                     (* as in the stack bytecode *)
    | Reads of value                (* a register the instruction reads, which holds that *)
    | Writes of value               (* a register it writes, which then holds that *)
    | Registers of int * value      (* a list of registers, as long as the operand at that
                                       position, each holding that *)
    | PrimArgs of int               (* a list of registers, as many as the arity of the
                                       primitive there, each what its type says of the
                                       argument of its place *)

  (* What an instruction does beside what its operands say: above the
     frame's registers -- where a primitive's arguments are pushed, a call
     leaves its result for the instruction after it, and a raise the
     exception for the handler's CATCH, which is what the loader works out
     the depth of (Function.maxstack) -- and to the closures of frames. *)
  datatype implicit =
      PushesArgs                    (* its list pushed, the primitive's arguments, which the
                                       primitive takes *)
    | Leaves of value               (* one value left when it is done: a call's result *)
    | Takes                         (* the one value left there taken: a call's result after
                                       it, a raise's exception at a handler's start *)
    | ReadsClosure                  (* the running frame's closure read, which it must have *)
    | MakesClosure of string        (* a closure of the function, which CallsClosure enters *)
    | CallsClosure                  (* enters the function of the closure it reads, with the
                                       closure and one argument, its register 0: a function
                                       that is made a closure of takes one *)
    | CallsKnown of string          (* enters the function with its list as its parameters,
                                       and no closure: a function so called reads none *)

  (* What must come after an instruction, which the loop and the JIT rely
     on: the loader checks a SWITCH's table, nothing else. An instruction
     that Takes comes only where one of these puts it. *)
  datatype order =
      Then of string                (* that instruction right after it: a call's RESULT *)
    | Table of string * string      (* right after it, as many of that instruction (the second)
                                       as its count operand (the first) says: a SWITCH's JUMPs *)
    | Begins of string * string     (* the code at its label operand (the first) beginning with
                                       that instruction (the second): a handler's CATCH *)

  (* Which primitives an instruction that names one may name: the image
     primitives (Isa.imagePrimitive), or the others. *)
  datatype primitives = AnyPrimitive | Images | NotImages

  type rinstruction =
    {name : string,
     operands : (string * rkind) list,   (* each operand's letter and kind; a list comes last *)
     flow : flow,
     handlers : handlers,
     raises : bool,
     implicit : implicit list,
     order : order list,
     primitives : primitives,
     doc : string,
     body : string list}

  fun rinst (name, operands, flow, doc) (body : string list) : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = Keeps, raises = false, implicit = [], order = [],
     primitives = AnyPrimitive, doc = doc, body = body}

  fun rraising ({name, operands, flow, handlers, implicit, order, primitives, doc, body, ...} : rinstruction)
      : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = handlers, raises = true, implicit = implicit,
     order = order, primitives = primitives, doc = doc, body = body}

  fun rhandlers (h : handlers) ({name, operands, flow, raises, implicit, order, primitives, doc, body, ...} : rinstruction)
      : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = h, raises = raises, implicit = implicit,
     order = order, primitives = primitives, doc = doc, body = body}

  fun implicitly (is : implicit list) ({name, operands, flow, handlers, raises, order, primitives, doc, body, ...} : rinstruction)
      : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = handlers, raises = raises, implicit = is,
     order = order, primitives = primitives, doc = doc, body = body}

  fun ordered (os : order list) ({name, operands, flow, handlers, raises, implicit, primitives, doc, body, ...} : rinstruction)
      : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = handlers, raises = raises, implicit = implicit,
     order = os, primitives = primitives, doc = doc, body = body}

  fun naming (ps : primitives) ({name, operands, flow, handlers, raises, implicit, order, doc, body, ...} : rinstruction)
      : rinstruction =
    {name = name, operands = operands, flow = flow, handlers = handlers, raises = raises, implicit = implicit,
     order = order, primitives = ps, doc = doc, body = body}

  val any = Is RAny

  (* What CALL and TAILCALL share: the closure in register a checked, the
     argument in register b taken; and after the frame, the callee's
     registers made at top -- register 0 is the argument, the others start
     as unit -- and its code entered. A callee's frame begins above the
     caller's registers, with its header (docs/plans/native-frames.md, M4). *)
  val callee =
    ["Value arg = R(b);",
     "Obj *c = EXPECT(R(a), K_CLOSURE, \"closure in call\");",
     "int64_t fidx = val_imm(obj_field(c, 0));",
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
     rinst ("MOVE", [("d", Writes (Like "s")), ("s", Reads any)], Next, "Register d := register s.")
       ["R(a) = R(b);"],
     rinst ("INT", [("d", Writes (Is RInt)), ("i", K Immediate)], Next, "Register d := the small integer i.")
       ["R(a) = mk_int(b);"],
     rinst ("CONST", [("d", Writes (ConstOf "k")), ("k", K Constant)], Next, "Register d := constant k.")
       ["R(a) = p->consts[b];"],
     rinst ("UNIT", [("d", Writes (Is RUnit))], Next, "Register d := unit.")
       ["R(a) = mk_unit();"],
     rinst ("CON0", [("d", Writes (Is RCon0)), ("t", K Tag)], Next, "Register d := the nullary constructor with tag t.")
       ["R(a) = mk_con0(b);"],
     rinst ("GLOBAL", [("d", Writes (GlobalOf "g")), ("g", K Global)], Next, "Register d := global g.")
       ["if (!vm->global_set[b]) FATAL(\"global %d read before initialization\", b);",
        "R(a) = vm->globals[b];"],
     rinst ("SETGLOBAL", [("g", K Global), ("s", Reads (GlobalOf "g"))], Next, "Global g := register s.")
       ["vm->globals[a] = R(b);",
        "vm->global_set[a] = 1;"],
     implicitly [ReadsClosure]
       (rinst ("ENV", [("d", Writes (EnvOf "e")), ("e", K EnvSlot)], Next, "Register d := slot e of the current closure's environment.")
          ["/* the header's closure: a closure, or unit where the frame has none */",
           "Value cv = CLOSURE();",
           "if (!val_is_ptr(cv) || obj_kind(val_ptr(cv)) != K_CLOSURE || (uint32_t)b + 1 >= obj_len(val_ptr(cv))) FATAL(\"environment slot %d out of range\", b);",
           "R(a) = obj_field(val_ptr(cv), b + 1);"]),
     implicitly [ReadsClosure]
       (rinst ("SELF", [("d", Writes (Is RPtr))], Next, "Register d := the closure running.")
          ["Value cv = CLOSURE();",
           "if (!val_is_ptr(cv) || obj_kind(val_ptr(cv)) != K_CLOSURE) FATAL(\"SELF outside a closure\");",
           "R(a) = cv;"]),
     (ordered [Then "RESULT"] o implicitly [CallsClosure, Leaves any])
       (rinst ("CALL", [("f", Reads (Is RPtr)), ("x", Reads any)], Call,
               "Call the closure in register f with register x; RESULT takes what it returns.")
          (["POLL(9);",
            "CENSUS_CALL(0, R(b), CENSUS_REP(p, vm->func, b));"]   (* the census VM's hook: nothing in the stock build *)
           @ callee
           @ ["size_t top = (size_t)(sp - vm->stack) + FRAME_HEADER;",
              "ROOM(top, fn);",
              "HEADER(top, pc, mk_ptr(c));",
              "vm->fp = top;",
              "vm->func = (uint32_t)fidx;"]
           @ enter
           @ ["HANDOVER((uint32_t)fidx);"])),
     implicitly [Takes]
       (rinst ("RESULT", [("d", Writes Left)], Next, "Register d := what the call or primitive before it left on the stack.")
          ["R(a) = POP();"]),
     implicitly [CallsClosure]
       (rinst ("TAILCALL", [("f", Reads (Is RPtr)), ("x", Reads any)], TailCall, "Like CALL, but the current frame is replaced.")
          (["POLL(9);",
            "CENSUS_CALL(1, R(b), CENSUS_REP(p, vm->func, b));"]
           @ callee
           @ ["size_t top = vm->fp;",
              "ROOM(top, fn);",
              "/* the frame's header keeps its caller and its return; its closure is the callee's */",
              "CLOSURE() = mk_ptr(c);",
              "vm->func = (uint32_t)fidx;"]
           @ enter
           @ ["HANDOVER((uint32_t)fidx);"])),
     rinst ("RET", [("s", Reads Returned)], Return, "Return register s to the caller.")
       ["Value v = R(a);",
        "if (vm->callback_depth && vm_frame_id(vm) == vm->callback_frame) { vm->callback_result = v; SYNC(); return 3; }",
        "CENSUS_CALL(4, v, CENSUS_REP(p, vm->func, a));",
        "/* the caller, as the frame's header says (native-frames.md, M4):",
        "   the interpreter's, whose info word names it, or compiled code,",
        "   which takes the value at its landing where the loop runs code",
        "   (RETURN_LANDING), and else says what its landing is of */",
        "size_t at = vm->fp;",
        "Value w = vm->stack[at - 1], info = vm->stack[at - 3];",
        "/* the frame at the stack's watermark returns through its barrier,",
        "   which lowers the watermark (native-frames.md, M5) */",
        "if (w == vm->barrier_stub && at == vm->barrier_at) w = reg_barrier_pass(vm);",
        "uint32_t cf, back;",
        "size_t head = at - FRAME_HEADER, cb;",
        "if (reg_interp_word(vm, w)) {",
        "  cf = reg_info_func(info);",
        "  back = reg_info_pc(info);",
        "  int kind = reg_info_kind(info);",
        "  /* the top level's: the program ends, the value above the frame's",
        "     header, which stays whole for what walks the frames after the",
        "     end (the census's last collection, vm_exit) */",
        "  if (kind == REG_INFO_BOTTOM) { vm->sp = at; vm->pc = back; vm->instructions = count; vm_push(vm, v); return 0; }",
        "  if (kind == REG_INFO_EXPLICIT) { head--; cb = (size_t)val_imm(vm->stack[head]); }",
        "  else cb = head - p->funcs[cf].nlocals;",
        "} else {",
        "  RETURN_LANDING(w, v);",
        "  if (!jit_landing_info(vm, w, &cf, &back)) FATAL(\"a frame returns to no code\");",
        "  cb = head - p->funcs[cf].nlocals;",
        "}",
        "vm->fp = cb;",
        "vm->func = cf;",
        "reg_frames_lower(vm, cb);",
        "base = vm->stack + cb;",
        "sp = vm->stack + head;",
        "/* the caller goes on at RESULT d, which takes the value: written",
        "   into d here, and RESULT passed over; anything else takes it from",
        "   the stack, as an image resumed at RESULT does */",
        "if (code[back] == ROP_RESULT) { R(read_i32(code + back + 1)) = v; pc = back + 5; }",
        "else { PUSH(v); pc = back; }",
        "/* a caller whose function has code goes on in it where a run begins (M6) */",
        "RESUME_NATIVE(cf, pc);"],
     (rraising o naming NotImages o implicitly [PushesArgs])
       (rinst ("PRIM", [("p", K Primitive), ("d", Writes (ResultOf "p")), ("args", PrimArgs 0)], Next,
               "Register d := primitive p applied to the registers of args.")
          ["/* the common case of the primitives done in the loop (runtime/register/fastprim.h) */",
           "if (prim_fast(vm, a, n, base, L, &R(b))) NEXT;",
           "for (uint32_t i = 0; i < n; i++) PUSH(R(LIST(i)));",
           "SYNC();",
           "int r = prim_table[a](vm);",
           "if (a == PRIM_foreign) count = vm->instructions; /* bounded callbacks executed instructions */",
           "RELOAD();",
           "/* 1: it raised, and the handler has its exception (vm_raise) */",
           "if (r == 1) RAISED();",
           "if (r == PRIM_NEW_WORLD) FATAL(\"a primitive that changes the world in PRIM\");",
           "R(b) = POP();"]),
     (rraising o naming Images o ordered [Then "RESULT"] o implicitly [PushesArgs, Leaves (ResultOf "p")])
       (rinst ("PRIMPUSH", [("p", K Primitive), ("args", PrimArgs 0)], Next,
               "Primitive p applied to the registers of args, its result left for RESULT: for one that saves or restores an image, which resumes at RESULT.")
          ["for (uint32_t i = 0; i < n; i++) PUSH(R(LIST(i)));",
           "SYNC();",
           "/* one that says PRIM_NEW_WORLD has put another program here",
           "   (Runtime.restore): RELOAD takes its code again, and the pc with",
           "   it, and the JIT's view of the program is made again */",
           "int r = prim_table[a](vm);",
           "if (a == PRIM_foreign) count = vm->instructions; /* bounded callbacks executed instructions */",
           "if (r == PRIM_NEW_WORLD) NEW_PROGRAM();",
           "RELOAD();",
           "if (r == PRIM_NEW_WORLD) DEBUG_BEGUN();",
           "if (r == 1) RAISED();"]),
     rinst ("TUPLE", [("d", Writes (UnitOr ("n", RPtr))), ("n", K Count), ("fields", Registers (1, any))], Next,
            "Register d := a tuple of the n registers of fields.")
       ["if (n == 0) { R(a) = mk_unit(); NEXT; }",
        "SYNC();",
        "Obj *t = vm_alloc_fields(vm, K_TUPLE, 0, n);",
        "Value *f = obj_fields(t);",
        "for (uint32_t i = 0; i < n; i++) f[i] = R(LIST(i));",
        "R(a) = mk_ptr(t);"],
     implicitly [MakesClosure "f"]
       (rinst ("CLOSURE", [("d", Writes (Is RPtr)), ("f", K Function), ("n", K Count), ("env", Registers (2, CapturesOf "f"))], Next,
               "Register d := a closure of function f capturing the n registers of env.")
          ["SYNC();",
           "Obj *cl = vm_alloc_fields(vm, K_CLOSURE, 0, n + 1);",
           "Value *f = obj_fields(cl);",
           "f[0] = mk_int(b);",
           "for (uint32_t i = 0; i < n; i++) f[i + 1] = R(LIST(i));",
           "R(a) = mk_ptr(cl);"]),
     rinst ("SELECT", [("d", Writes any), ("i", K Field), ("s", Reads (Is RPtr))], Next, "Register d := field i of the tuple in register s.")
       ["Obj *t = EXPECT(R(c), K_TUPLE, \"tuple\");",
        "if ((uint32_t)b >= obj_len(t)) FATAL(\"tuple index %d out of range\", b);",
        "R(a) = obj_field(t, b);"],
     rinst ("CON", [("d", Writes (Is RPtr)), ("t", K Tag), ("s", Reads any)], Next, "Register d := constructor t applied to register s.")
       ["SYNC();",
        "Obj *o = vm_alloc_fields(vm, K_CON, (uint16_t)b, 1);",
        "obj_fill_field(o, 0, R(c));",
        "R(a) = mk_ptr(o);"],
     rinst ("DECON", [("d", Writes any), ("s", Reads (Is RPtr)), ("t", K Tag)], Next,
            "Register d := the argument of the constructor value, of tag t, in register s; --checked stops where the tag is another.")
       ["Obj *o = EXPECT(R(b), K_CON, \"constructor with argument\");",
        "if (vm->checked && obj_contag(o) != c) FATAL(\"DECON of a constructor of tag %d where %d is wanted\", (int)obj_contag(o), (int)c);",
        "R(a) = obj_field(o, 0);"],
     rinst ("CONTAG", [("d", Writes (Is RInt)), ("s", Reads (Is RCon))], Next, "Register d := the tag of the constructor value in register s, as an int.")
       ["Value v = R(b);",
        "if (val_is(v, T_CON0)) R(a) = mk_int(val_imm(v));",
        "else if (val_is(v, T_PTR) && obj_kind(val_ptr(v)) == K_CON) R(a) = mk_int(obj_contag(val_ptr(v)));",
        "else FATAL(\"CONTAG on non-constructor\");"],
     rinst ("NEWEXN", [("d", Writes (Is RPtr)), ("k", K StringConstant)], Next,
            "Register d := a fresh exception constructor named by string constant k.")
       ["SYNC();",
        "Obj *o = vm_alloc_fields(vm, K_EXNCON, 0, 1);",
        "obj_fill_field(o, 0, p->consts[b]);",
        "R(a) = mk_ptr(o);"],
     rinst ("BUILTINEXN", [("d", Writes (Is RPtr)), ("i", K BuiltinExn)], Next,
            "Register d := built-in exception constructor i (see docs/bytecode.md).")
       ["R(a) = mk_ptr(vm->builtin_exns[b]);"],
     rinst ("MKEXN", [("d", Writes (Is RPtr)), ("c", Reads (Is RPtr)), ("x", Reads any)], Next,
            "Register d := the exception of the constructor in register c and the payload in register x.")
       ["SYNC();",
        "Obj *e = vm_alloc_fields(vm, K_EXN, 0, 2);",
        "Value con = R(b);",
        "if (!val_is(con, T_PTR) || obj_kind(val_ptr(con)) != K_EXNCON) FATAL(\"MKEXN on non-constructor\");",
        "obj_fill_field(e, 0, con);",
        "obj_fill_field(e, 1, R(c));",
        "R(a) = mk_ptr(e);"],
     rinst ("EXNCON", [("d", Writes (Is RPtr)), ("s", Reads (Is RPtr))], Next, "Register d := the constructor of the exception in register s.")
       ["Obj *e = EXPECT(R(b), K_EXN, \"exception\");",
        "R(a) = obj_field(e, 0);"],
     rinst ("EXNARG", [("d", Writes any), ("s", Reads (Is RPtr))], Next, "Register d := the payload of the exception in register s.")
       ["Obj *e = EXPECT(R(b), K_EXN, \"exception\");",
        "R(a) = obj_field(e, 1);"],
     rinst ("SETENV", [("c", Reads (Is RPtr)), ("e", K EnvSlot), ("v", Reads (SlotOf ("c", "e")))], Next,
            "Slot e of the environment of the closure in register c := register v.")
       ["Obj *o = EXPECT(R(a), K_CLOSURE, \"closure\");",
        "if ((uint32_t)b + 1 >= obj_len(o)) FATAL(\"environment slot %d out of range\", b);",
        "CENSUS_STORE(o, b + 1, R(c), 0, CENSUS_REP(p, vm->func, c));",
        "obj_set_field(vm, o, b + 1, R(c));"],
     rinst ("JUMP", [("o", K Label)], Jump, "Jump to absolute code offset o.")
       ["/* a jump back is a loop's: a poll, counted, and where the",
        "   function has code, gone on in it (M6) */",
        "if ((uint32_t)a < pc) { POLL(5); BACKWARD((uint32_t)a); }",
        "pc = (uint32_t)a;"],
     rinst ("JUMPIF", [("s", Reads (Is RCon0)), ("o", K Label)], Branch, "Jump to o if register s holds true.")
       ["Value v = R(a);",
        "if (!val_is(v, T_CON0)) FATAL(\"JUMPIF on non-bool\");",
        "if (val_imm(v) != 0) pc = (uint32_t)b;"],
     rinst ("JUMPIFNOT", [("s", Reads (Is RCon0)), ("o", K Label)], Branch, "Jump to o if register s holds false.")
       ["Value v = R(a);",
        "if (!val_is(v, T_CON0)) FATAL(\"JUMPIFNOT on non-bool\");",
        "if (val_imm(v) == 0) pc = (uint32_t)b;"],
     rinst ("JUMPIFNOTTAG", [("s", Reads (Is RCon)), ("o", K Label), ("t", K Tag)], Branch,
            "Jump to o unless the constructor value in register s has tag t.")
       ["Value v = R(a);",
        "int64_t tag = 0;",
        "if (val_is(v, T_CON0)) tag = val_imm(v);",
        "else if (val_is(v, T_PTR) && obj_kind(val_ptr(v)) == K_CON) tag = obj_contag(val_ptr(v));",
        "else FATAL(\"JUMPIFNOTTAG on non-constructor\");",
        "if (tag != c) pc = (uint32_t)b;"],
     (rhandlers Installs o ordered [Begins ("o", "CATCH")])
       (rinst ("PUSHHANDLER", [("o", K HandlerLabel)], Next,
               "Install an exception handler whose code starts at o, with CATCH.")
          ["SYNC();",
           "vm_push_handler(vm, (uint32_t)a);"]),
     rhandlers Removes
       (rinst ("POPHANDLER", [], Next, "Remove the innermost exception handler.")
          ["if (vm->hp == 0) FATAL(\"POPHANDLER with no handler\");",
           "vm->hp--;"]),
     implicitly [Takes]
       (rinst ("CATCH", [("d", Writes (Is RPtr))], Next, "Register d := the exception a raise left for the handler this begins.")
          ["R(a) = POP();"]),
     rraising
       (rinst ("RAISE", [("s", Reads (Is RPtr))], Raise, "Raise the exception in register s.")
          ["Value v = R(a);",
           "if (!val_is(v, T_PTR) || obj_kind(val_ptr(v)) != K_EXN) FATAL(\"RAISE of non-exception\");",
           "SYNC();",
           "vm_raise(vm, v);",
           "RELOAD();",
           "RAISED();"]),
     (ordered [Then "RESULT"] o implicitly [CallsKnown "f", Leaves (ReturnOf "f")])
       (rinst ("CALLK", [("f", K Function), ("n", K Count), ("args", Registers (1, ParamsOf "f"))], Call,
               "Call function f, known, with the n registers of args, which become its registers 0 to n-1; no closure; RESULT takes what it returns.")
          ["POLL(9 + 4 * n);",
           "for (uint32_t i = 0; i < n; i++) CENSUS_CALL(2, R(LIST(i)), CENSUS_REP(p, vm->func, LIST(i)));",
           "Function *fn = &p->funcs[a];",
           "size_t top = (size_t)(sp - vm->stack) + FRAME_HEADER;",
           "ROOM(top, fn);",
           "/* the arguments read before the frame is pushed, which R would read */",
           "Value *slot = vm->stack + top;",
           "for (uint32_t i = 0; i < n; i++) slot[i] = R(LIST(i));",
           "for (uint32_t i = n; i < fn->nlocals; i++) slot[i] = mk_unit();",
           "HEADER(top, pc, mk_unit());",
           "vm->fp = top;",
           "vm->func = (uint32_t)a;",
           "ENTER(slot, fn);",
           "HANDOVER((uint32_t)a);"]),
     implicitly [CallsKnown "f"]
       (rinst ("TAILCALLK", [("f", K Function), ("n", K Count), ("args", Registers (1, ParamsOf "f"))], TailCall,
               "Like CALLK, but the current frame is replaced.")
          ["POLL(9 + 4 * n);",
           "for (uint32_t i = 0; i < n; i++) CENSUS_CALL(3, R(LIST(i)), CENSUS_REP(p, vm->func, LIST(i)));",
           "Function *fn = &p->funcs[a];",
           "size_t top = vm->fp;",
           "size_t need = (size_t)(sp - vm->stack) + n;",
           "if (top + fn->nlocals + fn->maxstack > need) need = top + fn->nlocals + fn->maxstack;",
           "if (need > vm->stack_cap) { SYNC(); vm_grow_stack(vm, need); RELOAD(); }",
           "/* the arguments above the frame first, since they are its registers */",
           "Value *tmp = sp;",
           "for (uint32_t i = 0; i < n; i++) tmp[i] = R(LIST(i));",
           "Value *slot = vm->stack + top;",
           "memmove(slot, tmp, (size_t)n * sizeof(Value));",
           "for (uint32_t i = n; i < fn->nlocals; i++) slot[i] = mk_unit();",
           "CLOSURE() = mk_unit();",
           "vm->func = (uint32_t)a;",
           "ENTER(slot, fn);",
           "HANDOVER((uint32_t)a);"]),
     ordered [Table ("n", "JUMP")]
       (rinst ("SWITCH", [("s", Reads (Is RCon)), ("n", K Count)], Switch,
               "Jump to the target of the JUMP of the tag of the constructor value in register s among the n that follow, or past them.")
          ["/* the JUMPs are a table, which the loader has checked; each is",
           "   5 bytes, its target after its opcode */",
           "Value v = R(a);",
           "int64_t tag = 0;",
           "if (val_is(v, T_CON0)) tag = val_imm(v);",
           "else if (val_is(v, T_PTR) && obj_kind(val_ptr(v)) == K_CON) tag = obj_contag(val_ptr(v));",
           "else FATAL(\"SWITCH on non-constructor\");",
           "if (tag >= 0 && tag < b) pc = (uint32_t)read_i32(code + pc + 5 * (uint32_t)tag + 1);",
           "else pc += 5 * (uint32_t)b;"]),
     rinst ("CONN", [("d", Writes (Is RPtr)), ("t", K Tag), ("n", K Count), ("fields", Registers (2, any))], Next,
            "Register d := constructor t made of the n registers of fields: one object of n fields, for a constructor whose argument is a tuple of n (middle-end M11).")
       ["SYNC();",
        "Obj *o = vm_alloc_fields(vm, K_CON, (uint16_t)b, n);",
        "Value *f = obj_fields(o);",
        "for (uint32_t i = 0; i < n; i++) f[i] = R(LIST(i));",
        "R(a) = mk_ptr(o);"],
     rinst ("FIELD", [("d", Writes any), ("s", Reads (Is RPtr)), ("t", K Tag), ("i", K Field)], Next,
            "Register d := field i of the constructor value that CONN made, of tag t, in register s; --checked stops where the tag is another.")
       ["Obj *o = EXPECT(R(b), K_CON, \"constructor with fields\");",
        "if (vm->checked && obj_contag(o) != c) FATAL(\"FIELD of a constructor of tag %d where %d is wanted\", (int)obj_contag(o), (int)c);",
        "if ((uint32_t)d >= obj_len(o)) FATAL(\"constructor field %d out of range\", d);",
        "R(a) = obj_field(o, d);"]]

  (* ---- questions about the description ---- *)

  (* The operands before the list, and the list, if there is one. *)
  fun fixed (i : rinstruction) = List.filter (fn (_, Registers _) => false | (_, PrimArgs _) => false | _ => true) (#operands i)
  fun list (i : rinstruction) =
    List.find (fn (_, Registers _) => true | (_, PrimArgs _) => true | _ => false) (#operands i)

  (* An operand by its letter: its position among the operands, and its kind. *)
  fun operand (i : rinstruction, letter : string) : (int * rkind) option =
    let
      fun go (_, []) = NONE
        | go (k, (l, kind) :: rest) = if l = letter then SOME (k, kind) else go (k + 1, rest)
    in go (0, #operands i) end

  fun isRegister k = case k of Reads _ => true | Writes _ => true | _ => false

  fun takes (i : rinstruction) = List.exists (fn Takes => true | _ => false) (#implicit i)
  fun leaves (i : rinstruction) = List.exists (fn Leaves _ => true | _ => false) (#implicit i)

  fun check (instrs : rinstruction list) : unit =
    let
      fun byName n = List.find (fn (i : rinstruction) => #name i = n) instrs
      fun instr (i : rinstruction) =
        let
          val nf = List.length (fixed i)
          fun bad what = raise Bad ("register instruction " ^ #name i ^ " " ^ what)
          fun kindOf letter =
            case operand (i, letter) of
              SOME (_, k) => k
            | NONE => bad ("names an operand " ^ letter ^ " it has not")
          fun wants (letter, ok, what) = if ok (kindOf letter) then () else bad ("names " ^ letter ^ " as " ^ what ^ ", which it is not")
          fun isK ks k = case k of K k' => List.exists (fn k'' => k'' = k') ks | _ => false
          (* a value, where it is: read, written, of a list, or left *)
          datatype place = Read | Written | OfList | LeftBehind
          fun value (place, v) =
            case v of
              Is _ => ()
            | Like x => (if place = Written then () else bad "reads or leaves what another register holds";
                         wants (x, isRegister, "a register"))
            | ConstOf x => wants (x, isK [Constant, StringConstant], "a constant")
            | GlobalOf x => wants (x, isK [Global], "a global")
            | EnvOf x => (wants (x, isK [EnvSlot], "a slot of the environment");
                          if List.exists (fn ReadsClosure => true | _ => false) (#implicit i) then ()
                          else bad "reads the environment without reading the closure")
            | SlotOf (c, x) => (wants (c, isRegister, "a register"); wants (x, isK [EnvSlot], "a slot of the environment"))
            | ResultOf x => wants (x, isK [Primitive], "a primitive")
            | ReturnOf x => wants (x, isK [Function], "a function")
            | Returned => if place = Read then () else bad "writes what the function returns"
            | Left => if place = Written andalso takes i then () else bad "has what is left where it takes nothing"
            | UnitOr (x, _) => wants (x, isK [Count], "a count")
            | ParamsOf x => (if place = OfList then () else bad "has a function's parameters outside a list";
                             wants (x, isK [Function], "a function"))
            | CapturesOf x => (if place = OfList then () else bad "has a closure's slots outside a list";
                               wants (x, isK [Function], "a function"))
          fun hasPrimitive () = List.exists (fn (_, K Primitive) => true | _ => false) (#operands i)
        in
          if nf > 4 then bad "has more than four operands" else ();
          if List.null (#body i) then bad "has no body" else ();
          ignore (List.foldl (fn ((l, _), seen) =>
                                if StringMap.member (seen, l) then bad ("has two operands " ^ l)
                                else StringMap.insert (seen, l, ())) StringMap.empty (#operands i));
          case list i of
            SOME (_, Registers (k, _)) =>
              (case List.nth (#operands i, k) of
                 (_, K Count) => ()
               | _ => bad "has a list whose length is no count")
          | SOME (_, PrimArgs k) =>
              (case List.nth (#operands i, k) of
                 (_, K Primitive) => ()
               | _ => bad "has a list whose length is no primitive's")
          | _ => ();
          case list i of
            SOME l => if #1 l = #1 (List.last (#operands i)) then () else bad "has its list before the end"
          | NONE => ();
          (* the register it writes, which the VM's tables name (rop_dest) *)
          case List.filter (fn (_, Writes _) => true | _ => false) (#operands i) of
            [] => ()
          | [("d", _)] => ()
          | [_] => bad "writes a register not named d"
          | _ => bad "writes more than one register";
          List.app (fn (_, Reads v) => value (Read, v)
                     | (_, Writes v) => value (Written, v)
                     | (_, Registers (_, v)) => value (OfList, v)
                     | _ => ()) (#operands i);
          List.app (fn PushesArgs => (case list i of SOME (_, PrimArgs _) => () | _ => bad "pushes a primitive's arguments it has not")
                     | Leaves v =>
                         (value (LeftBehind, v);
                          if List.exists (fn Then n => (case byName n of SOME j => takes j | NONE => false) | _ => false) (#order i)
                          then () else bad "leaves a value for no instruction after it that takes it")
                     | Takes =>
                         if List.exists (fn (j : rinstruction) =>
                                           List.exists (fn Then n => n = #name i | Begins (_, n) => n = #name i | _ => false) (#order j))
                                        instrs
                         then () else bad "takes a value no instruction says is left before it"
                     | ReadsClosure => ()
                     | MakesClosure x =>
                         (wants (x, isK [Function], "a function");
                          case list i of
                            SOME (_, Registers (_, CapturesOf y)) => if x = y then () else bad "makes a closure of another function than it captures for"
                          | _ => bad "makes a closure without capturing for it")
                     | CallsClosure =>
                         if List.exists (fn (_, Reads (Is RPtr)) => true | _ => false) (#operands i) then ()
                         else bad "calls a closure it does not read"
                     | CallsKnown x =>
                         (wants (x, isK [Function], "a function");
                          case list i of
                            SOME (_, Registers (_, ParamsOf y)) => if x = y then () else bad "calls a function with another's parameters"
                          | _ => bad "calls a function without its parameters")) (#implicit i);
          List.app (fn Then n =>
                         (case byName n of
                            SOME j =>
                              if not (takes j) then bad ("is followed by " ^ n ^ ", which takes nothing")
                              else if not (leaves i) then bad ("is followed by " ^ n ^ ", and leaves nothing for it")
                              else ()
                          | NONE => bad ("is followed by " ^ n ^ ", which is no instruction"))
                     | Table (x, n) =>
                         (wants (x, isK [Count], "a count");
                          case byName n of
                            SOME j => if #flow j = Jump then () else bad ("has a table of " ^ n ^ ", which does not jump")
                          | NONE => bad ("has a table of " ^ n ^ ", which is no instruction"))
                     | Begins (x, n) =>
                         (wants (x, isK [HandlerLabel], "a handler's label");
                          case byName n of
                            SOME j => if takes j then () else bad ("has a handler that begins with " ^ n ^ ", which takes nothing")
                          | NONE => bad ("has a handler that begins with " ^ n ^ ", which is no instruction"))) (#order i);
          case #primitives i of
            AnyPrimitive => ()
          | _ => if hasPrimitive () then () else bad "says which primitives it names, and names none"
        end
    in
      List.app instr instrs;
      ignore (List.foldl (fn (i : rinstruction, seen) =>
                            if StringMap.member (seen, #name i) then raise Bad ("register instruction " ^ #name i ^ " is described twice")
                            else StringMap.insert (seen, #name i, ())) StringMap.empty instrs)
    end
end
