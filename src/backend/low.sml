(* Low, the representation both targets are made from (docs/ir.md;
   docs/plans/middle-end.md, D2 and M4): each function is blocks with
   parameters, in SSA form -- every variable is defined once, by an
   instruction or as a parameter of a block, and every use is where its
   definition dominates it. What Mid leaves implicit is explicit here:
   closures, their captured values and the running closure itself, and
   the handlers, which a block pushes and pops around a region whose raises
   go to the handler's block (an exceptional edge to each block of the
   region).

   The stack target (Stack) makes the bytecode of runevm from it; the
   register target (M5) will make vm/new's. *)
structure Low =
struct
  type var = int
  type label = int

  datatype operation =
      Const of Lambda.const
    | Unit
    | Con0 of int                         (* a nullary constructor, by its tag *)
    | Global of int
    | SetGlobal of int * var              (* unit *)
    | Env of int                          (* a value the running closure captured *)
    | Self                                (* the running closure *)
    | Call of var * var                   (* closure, argument *)
    | CallK of int * var list             (* a known function, by its id, and its arguments: no closure *)
    | Prim of string * var list
    | Tuple of var list
    | Select of int * var
    | Con of int * var
    | Decon of var
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
    | At of Source.span                   (* where the instructions that follow came from *)

  datatype transfer =
      Goto of label * var list
    | If of var * label * label           (* on a bool *)
    | IfTag of var * int * label * label  (* whether var's constructor has the tag *)
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
     program is a function too, whose parameter is never used. *)
  type func = {id : int, name : string, params : var list, ncaptured : int, nvars : int, blocks : block list,
               pos : Source.span option}

  type program = func list

  fun succs (t : transfer) : label list =
    case t of
      Goto (l, _) => [l]
    | If (_, a, b) => [a, b]
    | IfTag (_, _, a, b) => [a, b]
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
    | Con (_, v) => [v]
    | Decon v => [v]
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
    | Return v => [v]
    | TailCall (f, a) => [f, a]
    | TailCallK (_, vs) => vs
    | Raise v => [v]

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
        | SetGlobal (y, x) => let val y = g y in "setglobal " ^ y ^ " " ^ v x end
        | Env i => "env " ^ Int.toString i
        | Self => "self"
        | Call (f, a) => "call " ^ vs [f, a]
        | CallK (f, xs) => "callk f" ^ Int.toString f ^ (if null xs then "" else " " ^ vs xs)
        | Prim (p, xs) => "prim " ^ p ^ " " ^ vs xs
        | Tuple xs => "tuple " ^ vs xs
        | Select (i, x) => "select " ^ Int.toString i ^ " " ^ v x
        | Con (t, x) => "con " ^ Int.toString t ^ " " ^ v x
        | Decon x => "decon " ^ v x
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
        | Return x => "    return " ^ v x
        | TailCall (f, a) => "    tailcall " ^ vs [f, a]
        | TailCallK (f, xs) => "    tailcallk f" ^ Int.toString f ^ (if null xs then "" else " " ^ vs xs)
        | Raise x => "    raise " ^ v x
      fun block ({label, params, instrs, transfer = t} : block) =
        let val head = "  " ^ l label ^ (if null params then "" else "(" ^ vs params ^ ")") ^ ":"
        in head :: List.filter (fn s => s <> "") (List.map instr instrs) @ [transfer t] end
      fun func ({id, name, params, ncaptured, blocks, ...} : func) =
        (restart ();
         "function f" ^ Int.toString id ^ " " ^ name ^ " (" ^ vs params ^ ", " ^ Int.toString ncaptured ^ " captured)")
        :: List.concat (List.map block blocks)
    in
      String.concatWith "\n" (List.concat (List.map func p))
    end
end
