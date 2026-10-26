(* The language the instruction sets of Rune are described in
   (docs/plans/middle-end.md, M1). An instruction set is a list of
   instructions and a list of primitives, each described once, in full; the
   generator runeisa (src/isa/isamain.sml) writes from them everything that
   is not their meaning: the tables of the VM and the compiler, the
   validators, the stack effects, the documentation. What each instruction
   does is its body, which the VM's interpreter is made from.

   The description of the stack bytecode of runevm-stack is StackIsa
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
     the interpreter's loop (runtime/stack/interp.c), where `vm`, `p` (the program),
     `code`, `fr` (the frame), `op`, `a` and `b` (the operands) are in scope;
     runeisa ends the case with break, and the body may leave the loop with
     return. A shared body is instead a function of runtime/stack/ops.h,
     `op_<NAME> (vm, a, b)`, which the case calls and so does the code of
     runeopt (runtime/native/native.c): it has only `vm`, `p`, `a` and `b`, and ends
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
     ty : string,                        (* its SML type, which primType reads *)
     doc : string,
     effects : effect list,
     group : string}                     (* the heading it is listed under *)

  (* What a value is to the VM, where something says: the representations
     of docs/bytecode.md (The representations), which the compiler gives
     each variable of Low (Low.rep) and the register bytecode's meta each
     register, by the same numbers (repCode). *)
  datatype rep =
      RAny                  (* anything: nothing is said *)
    | RInt | RWord | RReal | RChar
    | RCon0                 (* a nullary constructor, a bool *)
    | RPtr                  (* in the heap *)
    | RCon                  (* a nullary constructor or in the heap: a list *)
    | RUnit
    | RInt64 | RWord64

  fun repCode r =
    case r of
      RAny => 0 | RInt => 1 | RWord => 2 | RReal => 3 | RChar => 4 | RCon0 => 5 | RPtr => 6 | RCon => 7 | RUnit => 8
    | RInt64 => 9 | RWord64 => 10

  (* A primitive's type, as primType reads the string its description
     gives it ("'a array * int -> 'a"): a type variable, numbered from 0 in
     the order they first come; a type constructor by the name the Basis
     gives it ("int", "list", "Word64.word"), with its arguments; a tuple of
     two or more; a function. *)
  datatype ty =
      TVar of int
    | TCon of string * ty list
    | TTuple of ty list
    | TArrow of ty * ty

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

  (* A primitive that saves or restores an image, or may make the world
     another (the program grown, the debugger's mode put on): the register
     bytecode calls it by PRIMPUSH, whose result RESULT takes, so that a
     program resumed at RESULT finds it there and the loop takes the
     program again after it (src/isa/regs.sml). *)
  fun imagePrimitive (p : primitive) = hasEffect (p, SavesImage) orelse hasEffect (p, NewWorld)

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

  (* A type as an SML type is written, of the types a primitive's
     description gives: type variables, type constructors applied after
     their arguments, tuples, and arrows to the right; or Bad. *)
  fun parseTy (s : string) : ty =
    let
      datatype token = TyVarTok of string | Name of string | LParen | RParen | Star | Arrow | Comma
      val n = String.size s
      fun bad what = raise Bad ("the type \"" ^ s ^ "\" " ^ what)
      fun nameChar c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'" orelse c = #"."
      fun lex (i, acc) =
        if i >= n then List.rev acc
        else
          let val c = String.sub (s, i)
          in
            if Char.isSpace c then lex (i + 1, acc)
            else if c = #"(" then lex (i + 1, LParen :: acc)
            else if c = #")" then lex (i + 1, RParen :: acc)
            else if c = #"*" then lex (i + 1, Star :: acc)
            else if c = #"," then lex (i + 1, Comma :: acc)
            else if c = #"-" andalso i + 1 < n andalso String.sub (s, i + 1) = #">" then lex (i + 2, Arrow :: acc)
            else if nameChar c then
              let
                fun stop j = if j < n andalso nameChar (String.sub (s, j)) then stop (j + 1) else j
                val j = stop i
                val w = String.substring (s, i, j - i)
              in lex (j, (if c = #"'" then TyVarTok w else Name w) :: acc) end
            else bad ("has the character " ^ String.str c)
          end
      val tokens = ref (lex (0, []))
      val vars : string list ref = ref []        (* in reverse order of first appearance *)
      fun var v =
        let
          fun find (_, []) = NONE
            | find (k, w :: rest) = if w = v then SOME k else find (k - 1, rest)
        in
          case find (List.length (!vars) - 1, !vars) of
            SOME k => TVar k
          | NONE => (vars := v :: !vars; TVar (List.length (!vars) - 1))
        end
      fun peek () = case !tokens of t :: _ => SOME t | [] => NONE
      fun next () = case !tokens of t :: rest => (tokens := rest; t) | [] => bad "ends too soon"
      (* ty: a tuple, or a tuple -> ty *)
      fun ty () =
        let val t = tuple ()
        in case peek () of SOME Arrow => (ignore (next ()); TArrow (t, ty ())) | _ => t end
      and tuple () =
        let
          fun more acc = case peek () of SOME Star => (ignore (next ()); more (applied () :: acc)) | _ => List.rev acc
        in case more [applied ()] of [t] => t | ts => TTuple ts end
      (* an atom, or a sequence of types in parentheses, then the type
         constructors applied to it, each to what is before it *)
      and applied () =
        let
          fun apply args =
            case peek () of
              SOME (Name c) => (ignore (next ()); apply [TCon (c, args)])
            | _ => (case args of [t] => t | _ => bad "has a sequence of types applied to no type constructor")
        in apply (atom ()) end
      and atom () =
        case next () of
          TyVarTok v => [var v]
        | Name c => [TCon (c, [])]
        | LParen =>
            let
              fun seq acc =
                case next () of
                  Comma => seq (ty () :: acc)
                | RParen => List.rev acc
                | _ => bad "has a parenthesis not closed"
            in seq [ty ()] end
        | _ => bad "has a type missing"
      val t = ty ()
    in
      if List.null (!tokens) then t else bad "goes on after its type"
    end

  (* A primitive's parameters, as many as its arity, and its result: its
     type a function's, from a tuple of as many as that where it takes two
     or more, and from unit where it takes none. *)
  fun primType (p : primitive) : ty list * ty =
    let
      fun bad what = raise Bad ("primitive " ^ #name p ^ " has a type " ^ what)
    in
      case (parseTy (#ty p) handle Bad msg => bad ("that cannot be read: " ^ msg)) of
        TArrow (from, to) =>
          (case (#arity p, from) of
             (0, TCon ("unit", [])) => ([], to)
           | (1, _) => ([from], to)
           | (k, TTuple ts) => if List.length ts = k then (ts, to) else bad "of another number of arguments than its arity"
           | _ => bad "of another number of arguments than its arity")
      | _ => bad "that is no function's"
    end

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
        (if #arity p < 0 orelse #arity p > 255 then raise Bad ("primitive " ^ #name p ^ " has an arity out of range") else ();
         ignore (primType p))
    in
      unique ("instruction", List.map #name instrs);
      unique ("primitive", List.map #name prims);
      List.app instr instrs;
      List.app prim prims
    end
end
