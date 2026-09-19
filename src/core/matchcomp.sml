(* Pattern match compilation. Rules are tried in order; each pattern test that
   fails executes Fail, which transfers control to the enclosing Try's
   fallback (the next rule). *)
structure MatchComp =
struct
  open Ast Lambda

  fun freshVar () = Elaborate.freshStamp ()

  fun bindVar (stamp, isGlobal, value, k) =
    if isGlobal then Seq (SetGlobal (stamp, value), k) else Let (stamp, value, k)

  fun exnConExp (info : exninfo) =
    case #builtin info of
      SOME k => BuiltinExn k
    | NONE => if #isGlobal info then Global (#stamp info) else Var (#stamp info)

  fun sconConst sc =
    case sc of
      SInt i => CInt i
    | SWord w => CWord w
    | SReal r => CReal r
    | SString s => CString s
    | SChar c => CChar (Char.ord c)

  (* A special constant at the type elaboration found for it: a constant, or
     for a type registered with `_overload ... via f` the application of f to
     the digits (the text, for a real constant). *)
  fun sconExp (sc, slot : Types.ty option ref) : lexp =
    let
      fun via digits =
        case !slot of
          SOME t =>
            (case Types.resolve t of
               Types.TCon (c, _) =>
                 (case Overload.literalOf c of
                    SOME (Overload.Via f) => SOME (App (Global f, Const (CString digits)))
                  | _ => NONE)
             | _ => NONE)
        | NONE => NONE
      fun digits i = if IntInf.< (i, IntInf.fromInt 0) then "~" ^ IntInf.toString (IntInf.~ i) else IntInf.toString i
    in
      case sc of
        SInt i => (case via (digits i) of SOME e => e | NONE => Const (sconConst sc))
      | SWord w => (case via (digits w) of SOME e => e | NONE => Const (sconConst sc))
      | SReal text => (case via text of SOME e => e | NONE => Const (sconConst sc))
      | _ => Const (sconConst sc)
    end

  fun info (slot : patinfo option ref, sp) =
    case !slot of
      SOME i => i
    | NONE => Error.bug ("pattern not annotated at " ^ Source.describe sp)

  (* Sorted labels of the record type a flexible record pattern resolved to. *)
  fun recordLabels (slot : Types.ty option ref, sp) : string list =
    case !slot of
      SOME t =>
        (case Types.resolve t of
           Types.TRecord fields => List.map #1 fields
         | _ => Error.bug ("flexible record pattern did not resolve to a record at " ^ Source.describe sp))
    | NONE => Error.bug "flexible record pattern not annotated"

  fun testEq (a, b, k) = If (Prim ("poly_eq", [a, b]), k, Fail)
  fun testTag (v, tag, k) = If (Prim ("poly_eq", [ConTag (Var v), Const (CInt (IntInf.fromInt tag))]), k, Fail)
  fun testExn (v, exncon, k) = If (Prim ("ptr_eq", [ExnCon (Var v), exncon]), k, Fail)

  (* Can matching this pattern fail? *)
  fun refutable (p : pat) : bool =
    case p of
      PWild _ => false
    | PScon _ => true
    | PVar (_, slot, sp) =>
        (case info (slot, sp) of
           PIVar _ => false
         | PICon i => #ncons i > 1
         | PIExn _ => true)
    | PRecord (fields, _, _, _) => List.exists (fn (_, p) => refutable p) fields
    | PTuple (ps, _) => List.exists refutable ps
    | PList _ => true
    | PApp (_, slot, arg, sp) =>
        (case info (slot, sp) of
           PICon i => (#ncons i > 1 andalso not (#isRef i)) orelse refutable arg
         | _ => true)
    | PTyped (p, _, _) => refutable p
    | PLayered (_, _, p, _, _) => refutable p

  (* compilePat (p, v, k): test/destructure the value in variable v against
     p, binding its variables, then continue with k. *)
  fun compilePat (p : pat, v : int, k : lexp) : lexp =
    case p of
      PWild _ => k
    | PScon (sc, slot, _) => testEq (Var v, sconExp (sc, slot), k)
    | PVar (_, slot, sp) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => bindVar (stamp, g, Var v, k)
         | PICon i => if #ncons i <= 1 then k else testTag (v, #tag i, k)
         | PIExn i => testExn (v, exnConExp i, k))
    | PRecord (fields, flex, slot, sp) =>
        let
          val labels = if flex then recordLabels (slot, sp) else List.map #1 (Types.sortFields fields)
          fun index lab =
            case Types.labelIndex (List.map (fn l => (l, ())) labels, lab) of
              SOME i => i
            | NONE => Error.bug ("record label " ^ lab ^ " missing")
        in
          compileFields (List.map (fn (l, p) => (index l, p)) fields, v, k)
        end
    | PTuple ([], _) => k
    | PTuple (ps, _) =>
        compileFields (ListPair.zip (List.tabulate (List.length ps, fn i => i), ps), v, k)
    | PList ([], _) => testTag (v, 0, k)
    | PList (p :: rest, sp) =>
        let
          val cell = freshVar ()
          val hd = freshVar ()
          val tl = freshVar ()
        in
          testTag (v, 1,
            Let (cell, Decon (Var v),
              Let (hd, Select (0, Var cell),
                Let (tl, Select (1, Var cell),
                  compilePat (p, hd, compilePat (PList (rest, sp), tl, k))))))
        end
    | PApp (_, slot, arg, sp) =>
        (case info (slot, sp) of
           PICon i =>
             let val w = freshVar ()
             in
               if #isRef i then Let (w, Prim ("ref_get", [Var v]), compilePat (arg, w, k))
               else
                 let val inner = Let (w, Decon (Var v), compilePat (arg, w, k))
                 in if #ncons i <= 1 then inner else testTag (v, #tag i, inner) end
             end
         | PIExn i =>
             let val w = freshVar ()
             in testExn (v, exnConExp i, Let (w, ExnArg (Var v), compilePat (arg, w, k))) end
         | PIVar _ => Error.bug "constructor application pattern annotated as variable")
    | PTyped (p, _, _) => compilePat (p, v, k)
    | PLayered (_, _, p, slot, sp) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => bindVar (stamp, g, Var v, compilePat (p, v, k))
         | _ => Error.bug "layered pattern annotated as constructor")

  and compileFields (fields : (int * pat) list, v : int, k : lexp) : lexp =
    case fields of
      [] => k
    | (i, p) :: rest =>
        (case p of
           PWild _ => compileFields (rest, v, k)
         | _ =>
           let val w = freshVar ()
           in Let (w, Select (i, Var v), compilePat (p, w, compileFields (rest, v, k))) end)

  (* Match the value in v against rules in order; `failure` runs if none matches. *)
  fun compileMatch (v : int, rules : (pat * lexp) list, failure : lexp) : lexp =
    case rules of
      [] => failure
    | (p, body) :: rest =>
        if refutable p then Try (compilePat (p, v, body), compileMatch (v, rest, failure))
        else compilePat (p, v, body)

  (* Multi-argument clauses (fun declarations): each clause has one pattern per parameter. *)
  fun compileClauses (vars : int list, clauses : (pat list * lexp) list, failure : lexp) : lexp =
    case clauses of
      [] => failure
    | (pats, body) :: rest =>
        let
          val canFail = List.exists refutable pats
          val matched = ListPair.foldr (fn (p, v, k) => compilePat (p, v, k)) body (pats, vars)
        in
          if canFail then Try (matched, compileClauses (vars, rest, failure)) else matched
        end
end
