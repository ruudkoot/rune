(* Low, the representation both targets are made from (docs/ir.md;
   docs/plans/middle-end.md, D2 and M4): each function is blocks with
   parameters, in SSA form -- every variable is defined once, by an
   instruction or as a parameter of a block, and every use is where its
   definition dominates it. What Mid leaves implicit is explicit here:
   closures, their captured values and the running closure itself, and
   the handlers, which a block pushes and pops around a region whose raises
   go to the handler's block (an exceptional edge to each block of the
   region).

   The stack target (Stack) makes the bytecode of runevm-stack from it; the
   register target (M5) will make runtime/register's. *)
structure Low =
struct
  type var = int
  type label = int

  (* What a variable holds, from the type Mid gave it (Lower, repOfTy): a
     target that keeps values out of their tagged slots (the JIT's tier 2,
     docs/plans/jit.md M8, M9) needs to know. Any is a variable of a
     polymorphic type, or one nothing is known of; Con0 a datatype of
     nullary constructors only (bool, order: a T_CON0 value); Ptr a value
     always in the heap (a tuple, a string, an array, a ref, a closure, an
     exception, a datatype of non-nullary constructors only); Con a datatype
     with both kinds of constructor (a list). The numbers are the file's
     (docs/bytecode.md, The representations). *)
  datatype rep = RAny | RInt | RWord | RReal | RChar | RCon0 | RPtr | RCon | RUnit | RInt64 | RWord64
  fun repCode r = case r of RAny => 0 | RInt => 1 | RWord => 2 | RReal => 3 | RChar => 4 | RCon0 => 5 | RPtr => 6 | RCon => 7 | RUnit => 8
                          | RInt64 => 9 | RWord64 => 10
  fun repOfCode c =
    case c of 1 => RInt | 2 => RWord | 3 => RReal | 4 => RChar | 5 => RCon0 | 6 => RPtr | 7 => RCon | 8 => RUnit
            | 9 => RInt64 | 10 => RWord64 | _ => RAny
  fun repName r = case r of RAny => "any" | RInt => "int" | RWord => "word" | RReal => "real" | RChar => "char"
                          | RCon0 => "con0" | RPtr => "ptr" | RCon => "con" | RUnit => "unit"
                          | RInt64 => "int64" | RWord64 => "word64"

  (* A place in the source, and the functions its code was inlined from on
     the way, innermost first (Mid.pos). *)
  type pos = Source.span * {name : string, site : Source.span option} list

  datatype operation =
      Const of Lambda.const
    | Unit
    | Con0 of int                         (* a nullary constructor, by its tag *)
    | Global of int
    | Slot of int                         (* a global read here, not again where it is used: a result a
                                             known call left there (Lower, performance M8) *)
    | SetGlobal of int * var              (* unit *)
    | Env of int                          (* a value the running closure captured *)
    | Self                                (* the running closure *)
    | Call of var * var                   (* closure, argument *)
    | CallK of int * var list             (* a known function, by its id, and its arguments: no closure *)
    | Prim of string * var list
    | Tuple of var list
    | Select of int * var
    | Con of int * var list               (* a constructor by its tag, of its argument, or of the fields of
                                             its argument where that is a tuple (Rep, M11) *)
    | Decon of int * var                  (* the argument of var, made by the constructor with the tag *)
    | Field of int * int * var            (* field i of var, made by the constructor with the tag of the
                                             fields of its argument (Rep) *)
    | ConTag of var
    | NewExn of string
    | BuiltinExn of int
    | MkExn of var * var
    | ExnCon of var
    | ExnArg of var
    | Closure of int * var option list    (* a function, what it captures; NONE: a closure of its group not
                                             made yet, set by a SetEnv after *)
    | SetEnv of var * int * var           (* the closure's i-th captured value; unit *)

  datatype instr =
      Def of var * operation                     (* var := op *)
    | Push of label                       (* push the handler whose code is the block *)
    | Pop                                 (* pop the handler pushed last *)
    | At of pos                           (* where the instructions that follow came from *)

  datatype transfer =
      Goto of label * var list
    | If of var * label * label           (* on a bool *)
    | IfTag of var * int * label * label  (* whether var's constructor has the tag *)
    | Switch of var * (int * label) list * label  (* by var's constructor's tag: the block of each tag,
                                                     and the one for the rest *)
    | Return of var
    | TailCall of var * var
    | TailCallK of int * var list
    | Raise of var

  type block = {label : label, params : var list, instrs : instr list, transfer : transfer}

  (* A function: its parameters -- one, where it is called through a
     closure; any number where only a known call (CallK) calls it -- how
     many values it captures, how many variables it has -- they are numbered
     from 0 in each function, so that a target keeps what it knows of them
     in arrays -- and its blocks, the entry first. The top level of the
     program is a function too, whose parameter is never used. What it
     returns and what each value it captures holds are declared, from
     their types (Lower), for a check of the code made of it (RegVerify):
     its result, and its captures, ncaptured of them. *)
  type func = {id : int, name : string, params : var list, ncaptured : int, nvars : int, blocks : block list,
               pos : Source.span option, reps : rep vector,   (* by variable; nvars long *)
               result : rep, captures : rep list}

  type program = func list

  fun succs (t : transfer) : label list =
    case t of
      Goto (l, _) => [l]
    | If (_, a, b) => [a, b]
    | IfTag (_, _, a, b) => [a, b]
    | Switch (_, cases, d) => List.map #2 cases @ [d]
    | _ => []

  (* The variables an operation reads. *)
  fun uses (oper : operation) : var list =
    case oper of
      SetGlobal (_, v) => [v]
    | Call (f, a) => [f, a]
    | CallK (_, vs) => vs
    | Prim (_, vs) => vs
    | Tuple vs => vs
    | Select (_, v) => [v]
    | Con (_, vs) => vs
    | Decon (_, v) => [v]
    | Field (_, _, v) => [v]
    | ConTag v => [v]
    | MkExn (c, p) => [c, p]
    | ExnCon v => [v]
    | ExnArg v => [v]
    | Closure (_, vs) => List.mapPartial (fn x => x) vs
    | SetEnv (c, _, v) => [c, v]
    | _ => []

  fun transferUses (t : transfer) : var list =
    case t of
      Goto (_, vs) => vs
    | If (v, _, _) => [v]
    | IfTag (v, _, _, _) => [v]
    | Switch (v, _, _) => [v]
    | Return v => [v]
    | TailCall (f, a) => [f, a]
    | TailCallK (_, vs) => vs
    | Raise v => [v]

  (* An operation and a transfer with each variable they read given by f. *)
  fun mapOperation (f : var -> var) (oper : operation) : operation =
    case oper of
      Const c => Const c
    | Unit => Unit
    | Con0 t => Con0 t
    | Global g => Global g
    | Slot g => Slot g
    | SetGlobal (g, v) => SetGlobal (g, f v)
    | Env i => Env i
    | Self => Self
    | Call (c, a) => Call (f c, f a)
    | CallK (k, vs) => CallK (k, List.map f vs)
    | Prim (p, vs) => Prim (p, List.map f vs)
    | Tuple vs => Tuple (List.map f vs)
    | Select (i, v) => Select (i, f v)
    | Con (t, vs) => Con (t, List.map f vs)
    | Decon (t, v) => Decon (t, f v)
    | Field (t, i, v) => Field (t, i, f v)
    | ConTag v => ConTag (f v)
    | NewExn n => NewExn n
    | BuiltinExn k => BuiltinExn k
    | MkExn (c, p) => MkExn (f c, f p)
    | ExnCon v => ExnCon (f v)
    | ExnArg v => ExnArg (f v)
    | Closure (k, vs) => Closure (k, List.map (Option.map f) vs)
    | SetEnv (c, i, v) => SetEnv (f c, i, f v)
  fun mapTransfer (f : var -> var) (t : transfer) : transfer =
    case t of
      Goto (l, vs) => Goto (l, List.map f vs)
    | If (v, a, b) => If (f v, a, b)
    | IfTag (v, tag, a, b) => IfTag (f v, tag, a, b)
    | Switch (v, cases, d) => Switch (f v, cases, d)
    | Return v => Return (f v)
    | TailCall (c, a) => TailCall (f c, f a)
    | TailCallK (k, vs) => TailCallK (k, List.map f vs)
    | Raise v => Raise (f v)

  (* Whether a function is a suspension's code (docs/ir.md, Suspensions):
     one that says thunk_blackhole in its entry block, where it goes under
     evaluation. *)
  fun suspensionCode (f : func) : bool =
    case #blocks f of
      {instrs, ...} :: _ => List.exists (fn Def (_, Prim ("thunk_blackhole", _)) => true | _ => false) instrs
    | [] => false

  (* A suspension's code with what it captured read at its entry, before it
     goes under evaluation, after which the collector follows none of its
     closure's fields (BLACKHOLE): each slot read once, by the first read of
     it, moved to the entry block's start, and every other read of the slot
     that variable. Any other function as it is. *)
  fun hoistEnv (f : func) : func =
    if not (suspensionCode f) then f
    else
      let
        (* the variable read of each slot, and what each other read is *)
        val reads : (int * var) list ref = ref []
        val renamed : var IntMap.map ref = ref IntMap.empty
        val () =
          List.app (fn ({instrs, ...} : block) =>
                      List.app (fn Def (x, Env i) =>
                                     (case List.find (fn (j, _) => j = i) (!reads) of
                                        SOME (_, y) => renamed := IntMap.insert (!renamed, x, y)
                                      | NONE => reads := (i, x) :: !reads)
                                 | _ => ()) instrs)
                   (#blocks f)
        fun name x = case IntMap.find (!renamed, x) of SOME y => y | NONE => x
        fun instr (Def (_, Env _)) = NONE
          | instr (Def (x, oper)) = SOME (Def (x, mapOperation name oper))
          | instr i = SOME i
        val blocks =
          List.map (fn {label, params, instrs, transfer} =>
                      {label = label, params = params, instrs = List.mapPartial instr instrs,
                       transfer = mapTransfer name transfer})
                   (#blocks f)
        val hoisted = List.map (fn (i, x) => Def (x, Env i)) (List.rev (!reads))
        val blocks =
          case blocks of
            {label, params, instrs, transfer} :: rest =>
              {label = label, params = params, instrs = hoisted @ instrs, transfer = transfer} :: rest
          | [] => []
      in
        {id = #id f, name = #name f, params = #params f, ncaptured = #ncaptured f, nvars = #nvars f, blocks = blocks,
         pos = #pos f, reps = #reps f, result = #result f, captures = #captures f}
      end

  fun size (p : program) : int =
    List.foldl (fn ({blocks, ...} : func, n) =>
                  List.foldl (fn ({instrs, ...} : block, n) => n + 1 + List.length instrs) n blocks) 0 p

  (* ---- printing (--dump-after=lower) ---- *)

  fun show (p : program) : string =
    let
      (* variables numbered afresh in each function, and globals in the
       program, as a dump of Mid numbers them *)
      fun counter () = (ref IntMap.empty, ref 0)
      fun number ((m, c), x) =
        case IntMap.find (!m, x) of
          SOME n => n
        | NONE => (c := !c + 1; m := IntMap.insert (!m, x, !c); !c)
      val vars = counter ()
      fun restart () = (#1 vars := IntMap.empty; #2 vars := 0)
      val globals = counter ()
      fun v x = "v" ^ Int.toString (number (vars, x))
      fun g x = "g" ^ Int.toString (number (globals, x))
      fun l x = "b" ^ Int.toString x
      fun vs xs = String.concatWith " " (List.map v xs)
      fun opText oper =
        case oper of
          Const c => "const " ^ Lambda.constToString c
        | Unit => "()"
        | Con0 t => "con0 " ^ Int.toString t
        | Global x => "global " ^ g x
        | Slot x => "slot " ^ g x
        | SetGlobal (y, x) => let val y = g y in "setglobal " ^ y ^ " " ^ v x end
        | Env i => "env " ^ Int.toString i
        | Self => "self"
        | Call (f, a) => "call " ^ vs [f, a]
        | CallK (f, xs) => "callk f" ^ Int.toString f ^ (if null xs then "" else " " ^ vs xs)
        | Prim (p, xs) => "prim " ^ p ^ " " ^ vs xs
        | Tuple xs => "tuple " ^ vs xs
        | Select (i, x) => "select " ^ Int.toString i ^ " " ^ v x
        | Con (t, xs) => "con " ^ Int.toString t ^ " " ^ vs xs
        | Decon (t, x) => "decon " ^ Int.toString t ^ " " ^ v x
        | Field (t, i, x) => "field " ^ Int.toString t ^ " " ^ Int.toString i ^ " " ^ v x
        | ConTag x => "tag " ^ v x
        | NewExn n => "newexn " ^ n
        | BuiltinExn k => "builtinexn " ^ Int.toString k
        | MkExn (c, x) => "mkexn " ^ vs [c, x]
        | ExnCon x => "exncon " ^ v x
        | ExnArg x => "exnarg " ^ v x
        | Closure (f, xs) =>
            "closure f" ^ Int.toString f ^ " " ^ String.concatWith " " (List.map (fn SOME x => v x | NONE => "_") xs)
        | SetEnv (c, i, x) => "setenv " ^ v c ^ " " ^ Int.toString i ^ " " ^ v x
      fun instr i =
        case i of
          Def (x, oper) => let val x = v x in "    " ^ x ^ " = " ^ opText oper end
        | Push h => "    push " ^ l h
        | Pop => "    pop"
        | At _ => ""
      fun transfer t =
        case t of
          Goto (b, xs) => "    goto " ^ l b ^ (if null xs then "" else " " ^ vs xs)
        | If (x, a, b) => "    if " ^ v x ^ " " ^ l a ^ " " ^ l b
        | IfTag (x, tag, a, b) => "    iftag " ^ v x ^ " " ^ Int.toString tag ^ " " ^ l a ^ " " ^ l b
        | Switch (x, cases, d) =>
            "    switch " ^ v x ^ String.concat (List.map (fn (t, b) => " " ^ Int.toString t ^ ":" ^ l b) cases) ^ " else " ^ l d
        | Return x => "    return " ^ v x
        | TailCall (f, a) => "    tailcall " ^ vs [f, a]
        | TailCallK (f, xs) => "    tailcallk f" ^ Int.toString f ^ (if null xs then "" else " " ^ vs xs)
        | Raise x => "    raise " ^ v x
      fun block ({label, params, instrs, transfer = t} : block) =
        let val head = "  " ^ l label ^ (if null params then "" else "(" ^ vs params ^ ")") ^ ":"
        in head :: List.filter (fn s => s <> "") (List.map instr instrs) @ [transfer t] end
      fun func ({id, name, params, ncaptured, blocks, reps, ...} : func) =
        let
          val () = restart ()
          val head = "function f" ^ Int.toString id ^ " " ^ name ^ " (" ^ vs params ^ ", " ^ Int.toString ncaptured ^ " captured)"
          val body = List.concat (List.map block blocks)
          (* each variable's representation, where it is not any: after the
             blocks, which number the variables as they did *)
          val typed =
            Vector.foldri (fn (x, r, acc) => if r = RAny then acc else (v x ^ ":" ^ repName r) :: acc) [] reps
        in
          head :: body @ (if null typed then [] else ["  reps " ^ String.concatWith " " typed])
        end
    in
      String.concatWith "\n" (List.concat (List.map func p))
    end
end
