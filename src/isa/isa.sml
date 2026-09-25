(* The language the instruction sets of Rune are described in
   (docs/plans/middle-end.md, M1). An instruction set is a list of
   instructions and a list of primitives, each described once, in full; the
   generator runeisa (src/isa/isamain.sml) writes from them everything that
   is not their meaning: the tables of the VM and the compiler, the
   validators, the stack effects, the documentation. What each instruction
   does is its body, which the VM's interpreter is made from.

   The description of the stack bytecode of vm/portable is StackIsa
   (src/isa/stack.sml); the primitives are PrimIsa (src/isa/prims.sml). *)
structure Isa =
struct
  (* What an operand is, which says what the loader accepts for it. *)
  datatype kind =
      Constant              (* an index of the constants *)
    | StringConstant        (* an index of a constant that is a string *)
    | Immediate             (* any number an operand holds *)
    | Tag                   (* the tag of a constructor, 0 to 65535 *)
    | Local                 (* a slot of the frame, below its number of locals *)
    | EnvSlot               (* a slot of the closure's environment, from 0 *)
    | Global                (* below the number of globals *)
    | Function              (* below the number of functions *)
    | Label                 (* where an instruction of the same function begins *)
    | HandlerLabel          (* the same, where a raise lands with the exception *)
    | Primitive             (* below the number of primitives *)
    | Count                 (* a number of values, 0 to 1000000 *)
    | Field                 (* the index of a field, from 0 *)
    | BuiltinExn            (* one of the built-in exceptions, 0 to 7 *)

  (* Every kind, in the order of the enum the VM is given, and each one's
     name there (OPND_<name>). *)
  val kinds =
    [Constant, StringConstant, Immediate, Tag, Local, EnvSlot, Global, Function, Label, HandlerLabel,
     Primitive, Count, Field, BuiltinExn]

  fun kindName k =
    case k of
      Constant => "CONSTANT" | StringConstant => "STRING_CONSTANT" | Immediate => "IMMEDIATE"
    | Tag => "TAG" | Local => "LOCAL" | EnvSlot => "ENV_SLOT" | Global => "GLOBAL"
    | Function => "FUNCTION" | Label => "LABEL" | HandlerLabel => "HANDLER_LABEL"
    | Primitive => "PRIMITIVE" | Count => "COUNT" | Field => "FIELD" | BuiltinExn => "BUILTIN_EXN"

  (* How many values an instruction pops: a number, the value of one of its
     operands (by position, from 0), or the arity of the primitive an
     operand names. *)
  datatype count =
      Fixed of int
    | OperandValue of int
    | ArityOf of int

  (* Where control goes after an instruction:
     * Next, to the one after it;
     * Branch, to the label of its first operand or to the one after it;
     * Jump, to the label of its first operand;
     * Call, into a function, and back to the one after it;
     * TailCall, into a function, not coming back;
     * Return, to the caller;
     * Raise, to the innermost handler;
     * Halt, nowhere: the program ends;
     * Switch, to the target of one of the JUMPs that follow it, as many as
       its first operand says (a table, never run itself), or to the
       instruction after them. *)
  datatype flow = Next | Branch | Jump | Call | TailCall | Return | Raise | Halt | Switch

  (* What an instruction does to the handlers of its function. *)
  datatype handlers = Keeps | Installs | Removes

  (* An instruction's body is what it does, as the lines of C of its case in
     the interpreter's loop (vm/interp.c), where `vm`, `p` (the program),
     `code`, `fr` (the frame), `op`, `a` and `b` (the operands) are in scope;
     runeisa ends the case with break, and the body may leave the loop with
     return. A shared body is instead a function of vm/ops.h,
     `op_<NAME> (vm, a, b)`, which the case calls and so does the code of
     runeopt (vm/native.c): it has only `vm`, `p`, `a` and `b`, and ends
     with return. *)
  type instruction =
    {name : string,
     operands : (string * kind) list,    (* each operand's letter and kind *)
     pops : count,
     pushes : int,
     flow : flow,
     handlers : handlers,
     raises : bool,                      (* may raise an exception of the program *)
     doc : string,
     body : string list,
     shared : bool}

  (* What a primitive may do beyond computing its result from its
     arguments. A primitive is described with the effects it has; one
     described with none is pure. *)
  datatype effect =
      Raises                (* raises an exception of the program *)
    | ReadsHeap             (* reads a mutable object: a ref, an array *)
    | WritesHeap            (* writes one *)
    | Allocates             (* makes an object *)
    | RoundingMode          (* its result depends on the rounding mode, which
                               real_set_round changes: it is not moved across
                               that call *)
    | System                (* input, output, time, the system *)
    | SavesImage            (* writes an image: a place the program resumes at *)
    | NewWorld              (* may become the world of an image *)

  (* The effects a primitive is given when nothing more precise is known:
     every one but the images. A primitive wrongly called pure is a
     miscompilation; one called impure without need only a lost
     optimisation. *)
  val anything = [Raises, ReadsHeap, WritesHeap, Allocates, System]

  type primitive =
    {name : string,
     arity : int,
     ty : string,                        (* its SML type, as documentation *)
     doc : string,
     effects : effect list,
     group : string}                     (* the heading it is listed under *)

  (* ---- building descriptions ---- *)

  fun inst (name, operands, (pops, pushes), flow, doc) (body : string list) : instruction =
    {name = name, operands = operands, pops = pops, pushes = pushes, flow = flow,
     handlers = Keeps, raises = false, doc = doc, body = body, shared = false}

  fun withHandlers (h : handlers) ({name, operands, pops, pushes, flow, raises, doc, body, shared, ...} : instruction)
      : instruction =
    {name = name, operands = operands, pops = pops, pushes = pushes, flow = flow,
     handlers = h, raises = raises, doc = doc, body = body, shared = shared}

  fun raising ({name, operands, pops, pushes, flow, handlers, doc, body, shared, ...} : instruction) : instruction =
    {name = name, operands = operands, pops = pops, pushes = pushes, flow = flow,
     handlers = handlers, raises = true, doc = doc, body = body, shared = shared}

  fun sharedBody ({name, operands, pops, pushes, flow, handlers, raises, doc, body, ...} : instruction) : instruction =
    {name = name, operands = operands, pops = pops, pushes = pushes, flow = flow,
     handlers = handlers, raises = raises, doc = doc, body = body, shared = true}

  (* The primitives listed under one heading, in order. *)
  fun group (heading : string)
            (ps : {name : string, arity : int, ty : string, effects : effect list, doc : string} list)
      : primitive list =
    List.map (fn {name, arity, ty, effects, doc} =>
                {name = name, arity = arity, ty = ty, effects = effects, doc = doc, group = heading}) ps

  (* ---- questions about a description ---- *)

  fun hasEffect (p : primitive, e : effect) = List.exists (fn e' => e' = e) (#effects p)

  (* An instruction after which control does not go on to the next. *)
  fun ends (i : instruction) =
    case #flow i of
      Jump => true | TailCall => true | Return => true | Raise => true | Halt => true | Switch => true | _ => false

  (* An instruction after which a straight run of code ends (docs/native.md,
     Counting): one that goes elsewhere, calls, or may raise. *)
  fun endsRun (i : instruction) = #flow i <> Next orelse #raises i

  (* The operand, by position, that is a label, if one is. *)
  fun labelOperand (i : instruction) : int option =
    let
      fun go (_, []) = NONE
        | go (k, (_, Label) :: _) = SOME k
        | go (k, (_, HandlerLabel) :: _) = SOME k
        | go (k, _ :: rest) = go (k + 1, rest)
    in
      go (0, #operands i)
    end

  (* A description that says two different things of one name, or that the
     format cannot hold, is refused before anything is written. *)
  exception Bad of string

  fun check (instrs : instruction list, prims : primitive list) : unit =
    let
      fun unique (what, names) =
        ignore (List.foldl (fn (n, seen) =>
                              if StringMap.member (seen, n) then raise Bad (what ^ " " ^ n ^ " is described twice")
                              else StringMap.insert (seen, n, ()))
                           StringMap.empty names)
      fun instr (i : instruction) =
        (if List.length (#operands i) > 2 then raise Bad ("instruction " ^ #name i ^ " has more than two operands") else ();
         if List.null (#body i) then raise Bad ("instruction " ^ #name i ^ " has no body") else ();
         (case #pops i of
            OperandValue k => if k >= List.length (#operands i) then raise Bad ("instruction " ^ #name i ^ " pops an operand it has not") else ()
          | ArityOf k => if k >= List.length (#operands i) then raise Bad ("instruction " ^ #name i ^ " pops an operand it has not") else ()
          | Fixed _ => ());
         (case (#flow i, labelOperand i) of
            (Branch, NONE) => raise Bad ("instruction " ^ #name i ^ " branches without a label")
          | (Jump, NONE) => raise Bad ("instruction " ^ #name i ^ " jumps without a label")
          | _ => ()))
      fun prim (p : primitive) =
        if #arity p < 0 orelse #arity p > 255 then raise Bad ("primitive " ^ #name p ^ " has an arity out of range") else ()
    in
      unique ("instruction", List.map #name instrs);
      unique ("primitive", List.map #name prims);
      List.app instr instrs;
      List.app prim prims
    end
end
