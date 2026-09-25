(* Pattern match compilation, two ways:
   * rule by rule (backtracking): rules are tried in order; each pattern
     test that fails executes Fail, which transfers control to the
     enclosing Try's fallback (the next rule) -- at -O0, for a match of one
     rule, and where a tree would grow too big;
   * as a decision tree (M9, from -O1, the optional pass "trees"): see
     `trees` below. *)
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
    | SWideString _ => Error.bug "sconConst: a string constant with a code point above 255"
    | SChar c => CChar c

  (* The type of a special constant: what elaboration found, where the
     constant is overloaded, else that of its kind. *)
  fun sconTy (sc, slot : Types.ty option ref) : Ty.ty =
    case !slot of
      SOME t => Ty.fromTypes t
    | NONE =>
        (case sc of
           SInt _ => Ty.int
         | SWord _ => Ty.Con (#stamp Types.wordTycon, "word", [])
         | SReal _ => Ty.Con (#stamp Types.realTycon, "real", [])
         | SChar _ => Ty.Con (#stamp Types.charTycon, "char", [])
         | SString _ => Ty.string
         | SWideString _ => Ty.string)

  (* A special constant at the type elaboration found for it: a constant, or
     for a type registered with `_overload ... via f` the application of f to
     the digits (the text, for a real constant). *)
  fun sconExp (sc, slot : Types.ty option ref) : lexp =
    let
      val ty = sconTy (sc, slot)
      fun via digits =
        case !slot of
          SOME t =>
            (case Types.resolve t of
               Types.TCon (c, _) =>
                 (case Overload.literalOf c of
                    SOME (Overload.Via f) => SOME (App (Inst (Global f, Ty.Arrow (Ty.string, ty)), Const (CString digits, Ty.string)))
                  | _ => NONE)
             | _ => NONE)
        | NONE => NONE
      fun digits i = if IntInf.< (i, IntInf.fromInt 0) then "~" ^ IntInf.toString (IntInf.~ i) else IntInf.toString i
      fun const () = Const (sconConst sc, ty)
    in
      case sc of
        SInt i => (case via (digits i) of SOME e => e | NONE => const ())
      | SWord w => (case via (digits w) of SOME e => e | NONE => const ())
      | SReal text => (case via text of SOME e => e | NONE => const ())
      | SChar c => (case via (Scon.escape c) of SOME e => e | NONE => const ())
      | SString s => (case via (Scon.text (List.map Char.ord (String.explode s))) of
                        SOME e => e
                      | NONE => const ())
      | SWideString s => (case via (Scon.text s) of SOME e => e | NONE => const ())
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

  fun eqTy t = Ty.Arrow (Ty.Tuple [t, t], Ty.bool)
  fun testEq (a, b, t, k) = If (Prim ("poly_eq", SOME (eqTy t), [a, b]), k, Fail)
  fun testTag (v, tag, k) =
    If (Prim ("poly_eq", SOME (eqTy Ty.int), [ConTag (Var v), Const (CInt (IntInf.fromInt tag), Ty.int)]), k, Fail)
  fun testExn (v, exncon, k) = If (Prim ("ptr_eq", SOME (eqTy Ty.ExnCon), [ExnCon (Var v), exncon]), k, Fail)

  (* The type of an exception's payload. *)
  fun exnArgTy (info : exninfo) : Ty.ty =
    case IntMap.find (!Ty.exnArgs, #stamp info) of
      SOME (SOME t) => Ty.fromTypes t
    | _ => Error.bug ("exception " ^ #name info ^ " has no payload")

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
    | PScon (sc, slot, _) => testEq (Var v, sconExp (sc, slot), sconTy (sc, slot), k)
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
            Let (cell, Decon (1, Var v),
              Let (hd, Select (0, Var cell),
                Let (tl, Select (1, Var cell),
                  compilePat (p, hd, compilePat (PList (rest, sp), tl, k))))))
        end
    | PApp (_, slot, arg, sp) =>
        (case info (slot, sp) of
           PICon i =>
             let val w = freshVar ()
             in
               if #isRef i then Let (w, Prim ("ref_get", NONE, [Var v]), compilePat (arg, w, k))
               else
                 let val inner = Let (w, Decon (#tag i, Var v), compilePat (arg, w, k))
                 in if #ncons i <= 1 then inner else testTag (v, #tag i, inner) end
             end
         | PIExn i =>
             let val w = freshVar ()
             in testExn (v, exnConExp i, Let (w, ExnArg (exnArgTy i, Var v), compilePat (arg, w, k))) end
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

  (* Match the value in v against rules in order; `failure` runs if none
     matches. *)
  fun backtrack (v : int, rules : (pat * lexp) list, failure : lexp) : lexp =
    case rules of
      [] => failure
    | (p, body) :: rest =>
        if refutable p then Try (compilePat (p, v, body), backtrack (v, rest, failure))
        else compilePat (p, v, body)

  (* Multi-argument clauses (fun declarations): each clause has one pattern
     per parameter. *)
  fun backtrackClauses (vars : int list, clauses : (pat list * lexp) list, failure : lexp) : lexp =
    case clauses of
      [] => failure
    | (pats, body) :: rest =>
        let
          val canFail = List.exists refutable pats
          val matched = ListPair.foldr (fn (p, v, k) => compilePat (p, v, k)) body (pats, vars)
        in
          if canFail then Try (matched, backtrackClauses (vars, rest, failure)) else matched
        end

  (* ---- decision trees (docs/plans/middle-end.md, M9) ---- *)

  (* A match of several rules as a decision tree (Maranget, "Compiling
     pattern matching to good decision trees", 2008): the rules are a
     matrix, a row of patterns for each, against the values in hand (the
     columns). The first row's first pattern that tests something picks the
     column; the rows are split by what the test finds; and a row whose
     patterns are all wild -- the first -- is the rule that matches. So no
     value is tested twice on a way through, a test is made only where the
     rules still in play differ, and where the rules name every constructor
     of a datatype the last is what is left, untested (D14). Each rule's
     body is a join point whose parameters are its variables, so that a
     body reached on several ways is not copied. *)

  exception TooBig

  (* A row: its patterns, the variables bound so far (stamp, global?, the
     variable holding the value) and its rule. *)
  type row = {pats : pat list, binds : (int * bool * int) list, rule : int}

  fun isWild (PWild _) = true
    | isWild _ = false

  (* p against the value in v, its variables taken off and bound to v *)
  fun strip (p : pat, v : int, binds : (int * bool * int) list) : pat * (int * bool * int) list =
    case p of
      PTyped (q, _, _) => strip (q, v, binds)
    | PLayered (_, _, q, slot, sp) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => strip (q, v, (stamp, g, v) :: binds)
         | _ => Error.bug "layered pattern annotated as constructor")
    | PVar (_, slot, sp) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => (PWild sp, (stamp, g, v) :: binds)
         | PICon i => if #ncons i <= 1 then (PWild sp, binds) else (p, binds)
         | PIExn _ => (p, binds))
    | PTuple ([], sp) => (PWild sp, binds)
    | _ => (p, binds)

  fun stripRow (cols : int list) ({pats, binds, rule} : row) : row =
    let
      val (pats', binds') =
        ListPair.foldl (fn (p, v, (acc, bs)) => let val (p', bs') = strip (p, v, bs) in (p' :: acc, bs') end)
                       ([], binds) (pats, cols)
    in {pats = List.rev pats', binds = binds', rule = rule} end

  (* The local variables a rule binds, in order, with their types. *)
  fun varsOf (ps : pat list) : (int * Ty.ty) list =
    let
      fun ty stamp =
        case IntMap.find (!Ty.binders, stamp) of
          SOME t => Ty.fromTypes t
        | NONE => Error.bug ("pattern variable v" ^ Int.toString stamp ^ " has no type")
      fun localVar (slot, sp, acc) =
        case info (slot, sp) of
          PIVar (stamp, false) => (stamp, ty stamp) :: acc
        | _ => acc
      fun go (p, acc) =
        case p of
          PWild _ => acc
        | PScon _ => acc
        | PVar (_, slot, sp) => localVar (slot, sp, acc)
        | PRecord (fields, _, _, _) => List.foldl (fn ((_, p), acc) => go (p, acc)) acc fields
        | PTuple (ps, _) => List.foldl go acc ps
        | PList (ps, _) => List.foldl go acc ps
        | PApp (_, _, arg, _) => go (arg, acc)
        | PTyped (p, _, _) => go (p, acc)
        | PLayered (_, _, p, slot, sp) => go (p, localVar (slot, sp, acc))
    in List.rev (List.foldl go [] ps) end

  (* What a column's tests are, from a pattern of it that tests something. *)
  datatype kind =
      KProd of int                        (* a tuple or record of so many fields: no test *)
    | KRef                                (* ref p: no test *)
    | KCon of int * (string * bool) list  (* a datatype: its constructors, (name, has an argument) by tag *)
    | KExn
    | KConst

  val listCons = [("nil", false), ("::", true)]

  fun kind (p : pat) : kind =
    case p of
      PTuple (ps, _) => KProd (List.length ps)
    | PRecord (_, _, _, _) => KProd (List.length (fieldsOf p))
    | PList _ => KCon (2, listCons)
    | PScon _ => KConst
    | PVar (_, slot, sp) =>
        (case info (slot, sp) of
           PICon i => KCon (#ncons i, #siblings i)
         | PIExn _ => KExn
         | PIVar _ => Error.bug "a variable where a test is")
    | PApp (_, slot, _, sp) =>
        (case info (slot, sp) of
           PICon i => if #isRef i then KRef else KCon (#ncons i, #siblings i)
         | PIExn _ => KExn
         | PIVar _ => Error.bug "constructor application pattern annotated as variable")
    | _ => Error.bug "a wild pattern where a test is"

  (* The fields of a record pattern, a pattern for each label of its type in
     order, wild where it names none. *)
  and fieldsOf (p : pat) : pat list =
    case p of
      PRecord (fields, flex, slot, sp) =>
        let val labels = if flex then recordLabels (slot, sp) else List.map #1 (Types.sortFields fields)
        in List.map (fn l => case List.find (fn (l', _) => l' = l) fields of SOME (_, q) => q | NONE => PWild sp) labels end
    | _ => Error.bug "fields of what is no record pattern"

  (* The constructor a pattern tests for, by tag, and its argument's
     pattern; NONE for a wild one. *)
  fun conOf (p : pat) : (int * pat option) option =
    case p of
      PList ([], _) => SOME (0, NONE)
    | PList (q :: rest, sp) => SOME (1, SOME (PTuple ([q, PList (rest, sp)], sp)))
    | PVar (_, slot, sp) => (case info (slot, sp) of PICon i => SOME (#tag i, NONE) | _ => NONE)
    | PApp (_, slot, arg, sp) => (case info (slot, sp) of PICon i => SOME (#tag i, SOME arg) | _ => NONE)
    | _ => NONE

  fun exnOf (p : pat) : (exninfo * pat option) option =
    case p of
      PVar (_, slot, sp) => (case info (slot, sp) of PIExn e => SOME (e, NONE) | _ => NONE)
    | PApp (_, slot, arg, sp) => (case info (slot, sp) of PIExn e => SOME (e, SOME arg) | _ => NONE)
    | _ => NONE

  fun sameExn (a : exninfo, b : exninfo) = #stamp a = #stamp b andalso #builtin a = #builtin b

  (* A constant written as one, where two different ones cannot both match
     a value; one of a type whose literals go through a function (_overload
     ... via) is only known to match where it is the same one. *)
  fun literal (sc, slot) = case sconExp (sc, slot) of Const _ => true | _ => false

  fun replace (xs : 'a list, c : int, new : 'a list) : 'a list = List.take (xs, c) @ new @ List.drop (xs, c + 1)

  fun firstIndex (pred : 'a -> bool) (xs : 'a list) : int option =
    let fun go (_, []) = NONE | go (i, x :: rest) = if pred x then SOME i else go (i + 1, rest)
    in go (0, xs) end

  fun ifTag (v : int, tag : int, yes : lexp, no : lexp) : lexp =
    If (Prim ("poly_eq", SOME (eqTy Ty.int), [ConTag (Var v), Const (CInt (IntInf.fromInt tag), Ty.int)]), yes, no)

  fun trees (vars : int list, rules : (pat list * lexp) list, failure : lexp) : lexp =
    let
      val joins = Vector.fromList (List.map (fn (pats, body) => (freshVar (), varsOf pats, body)) rules)
      (* a tree too big for the rules is made rule by rule instead *)
      val budget = ref (64 + 16 * List.length rules)
      fun spend () = (budget := !budget - 1; if !budget < 0 then raise TooBig else ())

      (* the rule of the first row matches: its globals set, and a jump to
         its body with the values of its variables *)
      fun leaf ({binds, rule, ...} : row) : lexp =
        let
          val (j, params, _) = Vector.sub (joins, rule)
          fun valueOf s =
            case List.find (fn (s', _, _) => s' = s) binds of
              SOME (_, _, w) => Var w
            | NONE => Error.bug "a variable of a rule not bound on the way to it"
        in
          List.foldl (fn ((s, true, w), k) => Seq (SetGlobal (s, Var w), k) | (_, k) => k)
                     (Jump (j, List.map (fn (s, _) => valueOf s) params)) binds
        end

      fun tree (cols : int list, rows : row list) : lexp =
        case List.map (stripRow cols) rows of
          [] => failure
        | rows as first :: _ =>
            (case firstIndex (not o isWild) (#pats first) of
               NONE => leaf first
             | SOME c => (spend (); column (c, cols, rows)))

      and column (c : int, cols : int list, rows : row list) : lexp =
        let
          val v = List.nth (cols, c)
          val p = List.nth (#pats (hd rows), c)
          val sp = spanOfPat p
          fun cell (r : row) = List.nth (#pats r, c)
          fun put (r : row, new) : row = {pats = replace (#pats r, c, new), binds = #binds r, rule = #rule r}
          fun fresh n = List.tabulate (n, fn _ => freshVar ())
        in
          case kind p of
            KProd arity =>
              let
                val ws = fresh arity
                fun fields q =
                  case q of
                    PTuple (ps, _) => ps
                  | PRecord _ => fieldsOf q
                  | _ => List.tabulate (arity, fn _ => PWild sp)
                val sub = tree (replace (cols, c, ws), List.map (fn r => put (r, fields (cell r))) rows)
              in
                #2 (List.foldr (fn (w, (i, k)) => (i - 1, Let (w, Select (i, Var v), k))) (arity - 1, sub) ws)
              end
          | KRef =>
              let
                val w = freshVar ()
                fun inner q = case q of PApp (_, _, arg, _) => arg | _ => PWild sp
              in
                Let (w, Prim ("ref_get", NONE, [Var v]), tree (replace (cols, c, [w]), List.map (fn r => put (r, [inner (cell r)])) rows))
              end
          | KCon (ncons, cons) =>
              let
                (* the constructors the column names, in the order it first does *)
                val tags = List.foldl (fn (r, ts) => case conOf (cell r) of
                                                       SOME (t, _) => if List.exists (fn t' => t' = t) ts then ts else ts @ [t]
                                                     | NONE => ts) [] rows
                fun branch t =
                  let
                    val hasArg = #2 (List.nth (cons, t))
                    val w = freshVar ()
                    fun rowFor r =
                      case conOf (cell r) of
                        NONE => SOME (put (r, if hasArg then [PWild sp] else []))
                      | SOME (t', arg) =>
                          if t' <> t then NONE
                          else SOME (put (r, if hasArg then [case arg of SOME a => a | NONE => PWild sp] else []))
                    val sub = tree (replace (cols, c, if hasArg then [w] else []), List.mapPartial rowFor rows)
                  in
                    if hasArg then Let (w, Decon (t, Var v), sub) else sub
                  end
                (* the rows that name no constructor, where one not named is found *)
                val default =
                  if List.length tags >= ncons then NONE
                  else SOME (tree (replace (cols, c, []),
                                   List.mapPartial (fn r => if isWild (cell r) then SOME (put (r, [])) else NONE) rows))
                fun chain [] = Error.bug "a test of no constructor"
                  | chain [t] = (case default of NONE => branch t | SOME d => ifTag (v, t, branch t, d))
                  | chain (t :: rest) = ifTag (v, t, branch t, chain rest)
              in
                chain tags
              end
          | KExn =>
              let
                val (e, _) = valOf (exnOf p)
                val hasArg = #hasArg e
                val w = freshVar ()
                fun same q = case exnOf q of SOME (e', _) => sameExn (e, e') | NONE => false
                (* where the value's constructor is e: its argument is had; a
                   row of another constructor, which may be e by another
                   name, is still tested *)
                fun yesRow r =
                  let val q = cell r
                  in
                    if same q then
                      put (r, PWild sp :: (if hasArg then [case exnOf q of SOME (_, SOME a) => a | _ => PWild sp] else []))
                    else put (r, q :: (if hasArg then [PWild sp] else []))
                  end
                val yes = tree (replace (cols, c, v :: (if hasArg then [w] else [])), List.map yesRow rows)
                val yes = if hasArg then Let (w, ExnArg (exnArgTy e, Var v), yes) else yes
                val no = tree (cols, List.filter (fn r => not (same (cell r))) rows)
              in
                If (Prim ("ptr_eq", SOME (eqTy Ty.ExnCon), [ExnCon (Var v), exnConExp e]), yes, no)
              end
          | KConst =>
              let
                val (sc, slot) = case p of PScon (sc, slot, _) => (sc, slot) | _ => Error.bug "a constant pattern"
                fun same q =
                  case q of
                    PScon (sc', slot', _) =>
                      if literal (sc, slot) andalso literal (sc', slot') then sconConst sc = sconConst sc' else sc = sc'
                  | _ => false
                fun other q =
                  case q of
                    PScon (sc', slot', _) => literal (sc, slot) andalso literal (sc', slot') andalso sconConst sc <> sconConst sc'
                  | _ => false
                (* where the value is the constant, a row of another literal
                   cannot match; one of another constant is still tested *)
                val yes = tree (cols, List.mapPartial (fn r => let val q = cell r
                                                               in
                                                                 if same q then SOME (put (r, [PWild sp]))
                                                                 else if other q then NONE
                                                                 else SOME r
                                                               end) rows)
                val no = tree (cols, List.filter (fn r => not (same (cell r))) rows)
                val t = sconTy (sc, slot)
              in
                If (Prim ("poly_eq", SOME (eqTy t), [Var v, sconExp (sc, slot)]), yes, no)
              end
        end

      val tree = tree (vars, List.tabulate (Vector.length joins, fn i => {pats = #1 (List.nth (rules, i)), binds = [], rule = i}))
    in
      Vector.foldr (fn ((j, params, body), k) => Join (j, params, body, k)) tree joins
    end

  fun useTrees rules = List.length rules >= 2 andalso Pass.enabled ("trees", 1)

  (* Match the value in v against rules in order; `failure` runs if none matches. *)
  fun compileMatch (v : int, rules : (pat * lexp) list, failure : lexp) : lexp =
    if useTrees rules then
      trees ([v], List.map (fn (p, b) => ([p], b)) rules, failure) handle TooBig => backtrack (v, rules, failure)
    else backtrack (v, rules, failure)

  (* Multi-argument clauses (fun declarations): each clause has one pattern per parameter. *)
  fun compileClauses (vars : int list, clauses : (pat list * lexp) list, failure : lexp) : lexp =
    if useTrees clauses then trees (vars, clauses, failure) handle TooBig => backtrackClauses (vars, clauses, failure)
    else backtrackClauses (vars, clauses, failure)
end
