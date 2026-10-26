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

  (* each local variable an expression is made to read, told to Translate
     (the slots of a record a functor's body sets are those read) *)
  val noteLocal : (int -> unit) ref = ref (fn _ => ())
  val () = CompilerState.cellRoot ("MatchComp.noteLocal", noteLocal)

  fun exnConExp (info : exninfo) =
    case #builtin info of
      SOME k => BuiltinExn k
    | NONE => if #isGlobal info then Global (#stamp info) else (!noteLocal (#stamp info); Var (#stamp info))

  fun sconConst sc =
    case sc of
      SInt i => CInt i
    | SWord w => CWord w
    | SReal r => CReal r
    | SString s => CString s
    | SWideString _ => Error.bug "sconConst: a string constant with a code point above 255"
    | SChar (c, _) => CChar c

  (* The type of a special constant: what elaboration found, where the
     constant is overloaded, else that of its kind. *)
  fun sconTy (sc, slot : Types.ty option ref) : Ty.ty =
    case !slot of
      SOME t => Ty.fromTypes t
    | NONE =>
        (case sc of
           SInt _ => Ty.int
         | SWord _ => Ty.con (#stamp Types.wordTycon, "word", [])
         | SReal _ => Ty.con (#stamp Types.realTycon, "real", [])
         | SChar _ => Ty.con (#stamp Types.charTycon, "char", [])
         | SString _ => Ty.string
         | SWideString _ => Ty.string)

  (* The wide constants made while a top-level declaration is translated:
     each a global and what sets it, which the declaration runs first
     (Translate.transProgram), so that a constant is made once and not where
     it is evaluated (the utf8 roadmap's M4, E8) *)
  val hoisted : (int * lexp) list ref = ref []
  val () = CompilerState.cellRoot ("MatchComp.hoisted", hoisted)

  (* A special constant at the type elaboration found for it: a constant, or
     for a type registered with `_overload ... via f` the application of f to
     the digits (the text, for a real constant): a global, made once, for a
     character or string constant (hoisted). *)
  fun sconExp (sc, slot : Types.ty option ref) : lexp =
    let
      val ty = sconTy (sc, slot)
      val once = case sc of SString _ => true | SWideString _ => true | SChar _ => true | _ => false
      fun via digits =
        case !slot of
          SOME t =>
            (case Types.resolve t of
               rt as Types.TCon (c, _) =>
                 (case Overload.literalOf c of
                    SOME (Overload.Via f) =>
                      let val make = App (Inst (Global f, Ty.arrow (Ty.string, ty)), Const (CString digits, Ty.string))
                      in
                        if not once then SOME make
                        else
                          let val g = Elaborate.freshStamp ()
                          in Ty.bindVar (g, rt); hoisted := (g, make) :: !hoisted; SOME (Global g) end
                      end
                  | _ => NONE)
             | _ => NONE)
        | NONE => NONE
      fun digits i = if IntInf.< (i, IntInf.fromInt 0) then "~" ^ IntInf.toString (IntInf.~ i) else IntInf.toString i
      fun const () = Const (constAt (sconConst sc, ty), ty)
    in
      case sc of
        SInt i => (case via (digits i) of SOME e => e | NONE => const ())
      | SWord w => (case via (digits w) of SOME e => e | NONE => const ())
      | SReal text => (case via text of SOME e => e | NONE => const ())
      | SChar (c, _) => (case via (Scon.escape c) of SOME e => e | NONE => const ())
      | SString s => (case via (Scon.text (List.map Char.ord (String.explode s))) of
                        SOME e => e
                      | NONE => const ())
      | SWideString (s, _) => (case via (Scon.text s) of SOME e => e | NONE => const ())
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

  fun eqTy t = Ty.arrow (Ty.tuple [t, t], Ty.bool)
  fun testEq (a, b, t, k) = If (Prim ("poly_eq", SOME (eqTy t), [a, b]), k, Fail)
  fun testTag (v, tag, k) =
    If (Prim ("poly_eq", SOME (eqTy Ty.int), [ConTag (Var v), Const (CInt (IntInf.fromInt tag), Ty.int)]), k, Fail)
  fun testExn (v, exncon, k) = If (Prim ("ptr_eq", SOME (eqTy Ty.exnCon), [ExnCon (Var v), exncon]), k, Fail)

  (* The type of an exception's payload. *)
  fun exnArgTy (info : exninfo) : Ty.ty =
    case IntTable.find (Ty.exnArgs, #stamp info) of
      SOME (SOME t) => Ty.fromTypes t
    | _ => Error.bug ("exception " ^ #name info ^ " has no payload")

  (* Can matching this pattern fail? *)
  fun refutable (p : pat) : bool =
    case p of
      PWild (_, _) => false
    | PScon _ => true
    | PVar (_, slot, sp, _) =>
        (case info (slot, sp) of
           PIVar _ => false
         | PICon i => #ncons i > 1
         | PIExn _ => true)
    | PRecord (fields, _, _, _, _) => List.exists (fn (_, p, _) => refutable p) fields
    | PTuple (ps, _, _) => List.exists refutable ps
    | PList _ => true
    | PApp (_, slot, arg, sp, _) =>
        (case info (slot, sp) of
           PICon i => (#ncons i > 1 andalso not (#isRef i)) orelse refutable arg
         | _ => true)
    | PTyped (p, _, _, _) => refutable p
    | PLayered (_, _, p, _, _, _) => refutable p
    | POr (ps, _, _) => List.all refutable ps

  (* compilePat (p, v, k): test/destructure the value in variable v against
     p, binding its variables, then continue with k. *)
  fun compilePat (p : pat, v : int, k : lexp) : lexp =
    case p of
      PWild (_, _) => k
    | PScon (sc, slot, _, _) => testEq (Var v, sconExp (sc, slot), sconTy (sc, slot), k)
    | PVar (_, slot, sp, _) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => bindVar (stamp, g, Var v, k)
         | PICon i => if #ncons i <= 1 then k else testTag (v, #tag i, k)
         | PIExn i => testExn (v, exnConExp i, k))
    | PRecord (fields, flex, slot, sp, _) =>
        let
          val fields = unlabel fields
          val labels = if flex then recordLabels (slot, sp) else List.map #1 (Types.sortFields fields)
          fun index lab =
            case Types.labelIndex (List.map (fn l => (l, ())) labels, lab) of
              SOME i => i
            | NONE => Error.bug ("record label " ^ lab ^ " missing")
        in
          compileFields (List.map (fn (l, p) => (index l, p)) fields, v, k)
        end
    | PTuple ([], _, _) => k
    | PTuple (ps, _, _) =>
        compileFields (ListPair.zip (List.tabulate (List.length ps, fn i => i), ps), v, k)
    | PList ([], _, _) => testTag (v, Types.nilTag (), k)
    | PList (p :: rest, sp, _) =>
        let
          val cell = freshVar ()
          val hd = freshVar ()
          val tl = freshVar ()
        in
          testTag (v, Types.consTag (),
            Let (cell, Decon (Types.consTag (), Var v),
              Let (hd, Select (0, Var cell),
                Let (tl, Select (1, Var cell),
                  compilePat (p, hd, compilePat (PList (rest, sp, noId), tl, k))))))
        end
    | PApp (_, slot, arg, sp, _) =>
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
    | PTyped (p, _, _, _) => compilePat (p, v, k)
    | PLayered (_, _, p, slot, sp, _) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => bindVar (stamp, g, Var v, compilePat (p, v, k))
         | _ => Error.bug "layered pattern annotated as constructor")
    | POr _ => Error.bug "an or-pattern matched rule by rule"

  and compileFields (fields : (int * pat) list, v : int, k : lexp) : lexp =
    case fields of
      [] => k
    | (i, p) :: rest =>
        (case p of
           PWild (_, _) => compileFields (rest, v, k)
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

  fun isWild (PWild (_, _)) = true
    | isWild _ = false

  (* p against the value in v, its variables taken off and bound to v *)
  fun strip (p : pat, v : int, binds : (int * bool * int) list) : pat * (int * bool * int) list =
    case p of
      PTyped (q, _, _, _) => strip (q, v, binds)
    | PLayered (_, _, q, slot, sp, _) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => strip (q, v, (stamp, g, v) :: binds)
         | _ => Error.bug "layered pattern annotated as constructor")
    | PVar (_, slot, sp, _) =>
        (case info (slot, sp) of
           PIVar (stamp, g) => (PWild (sp, noId), (stamp, g, v) :: binds)
         | PICon i => if #ncons i <= 1 then (PWild (sp, noId), binds) else (p, binds)
         | PIExn _ => (p, binds))
    | PTuple ([], sp, _) => (PWild (sp, noId), binds)
    | _ => (p, binds)

  fun stripRow (cols : int list) ({pats, binds, rule} : row) : row =
    let
      val (pats', binds') =
        ListPair.foldl (fn (p, v, (acc, bs)) => let val (p', bs') = strip (p, v, bs) in (p' :: acc, bs') end)
                       ([], binds) (pats, cols)
    in {pats = List.rev pats', binds = binds', rule = rule} end

  (* The local variables a rule binds, in order, with their types; with
     global, its global ones (a top-level val binding's) instead. *)
  fun boundVars (global : bool) (ps : pat list) : (int * Ty.ty) list =
    let
      fun ty stamp =
        case IntTable.find (Ty.binders, stamp) of
          SOME t => Ty.fromTypes t
        | NONE => Error.bug ("pattern variable v" ^ Int.toString stamp ^ " has no type")
      fun localVar (slot, sp, acc) =
        case info (slot, sp) of
          PIVar (stamp, g) => if g = global then (stamp, ty stamp) :: acc else acc
        | _ => acc
      fun go (p, acc) =
        case p of
          PWild (_, _) => acc
        | PScon _ => acc
        | PVar (_, slot, sp, _) => localVar (slot, sp, acc)
        | PRecord (fields, _, _, _, _) => List.foldl (fn ((_, p, _), acc) => go (p, acc)) acc fields
        | PTuple (ps, _, _) => List.foldl go acc ps
        | PList (ps, _, _) => List.foldl go acc ps
        | PApp (_, _, arg, _, _) => go (arg, acc)
        | PTyped (p, _, _, _) => go (p, acc)
        | PLayered (_, _, p, slot, sp, _) => go (p, localVar (slot, sp, acc))
        | POr (p :: _, _, _) => go (p, acc)       (* every alternative binds the same *)
        | POr ([], _, _) => acc
    in List.rev (List.foldl go [] ps) end

  val varsOf = boundVars false

  (* What a column's tests are, from a pattern of it that tests something. *)
  datatype kind =
      KProd of int                        (* a tuple or record of so many fields: no test *)
    | KRef                                (* ref p: no test *)
    | KCon of int * (string * bool) list  (* a datatype: its constructors, (name, has an argument) by tag *)
    | KExn
    | KConst

  (* the list's constructors by tag, as Types.tagNames numbers them *)
  fun listCons () = List.map (fn n => (n, n = "::")) (Types.listTagNames ())

  fun kind (p : pat) : kind =
    case p of
      PTuple (ps, _, _) => KProd (List.length ps)
    | PRecord (_, _, _, _, _) => KProd (List.length (fieldsOf p))
    | PList _ => KCon (2, listCons ())
    | PScon _ => KConst
    | PVar (_, slot, sp, _) =>
        (case info (slot, sp) of
           PICon i => KCon (#ncons i, #siblings i)
         | PIExn _ => KExn
         | PIVar _ => Error.bug "a variable where a test is")
    | PApp (_, slot, _, sp, _) =>
        (case info (slot, sp) of
           PICon i => if #isRef i then KRef else KCon (#ncons i, #siblings i)
         | PIExn _ => KExn
         | PIVar _ => Error.bug "constructor application pattern annotated as variable")
    | _ => Error.bug "a wild pattern where a test is"

  (* The fields of a record pattern, a pattern for each label of its type in
     order, wild where it names none. *)
  and fieldsOf (p : pat) : pat list =
    case p of
      PRecord (fields, flex, slot, sp, _) =>
        let val fields = unlabel fields
            val labels = if flex then recordLabels (slot, sp) else List.map #1 (Types.sortFields fields)
        in List.map (fn l => case List.find (fn (l', _) => l' = l) fields of SOME (_, q) => q | NONE => PWild (sp, noId)) labels end
    | _ => Error.bug "fields of what is no record pattern"

  (* The constructor a pattern tests for, by tag, and its argument's
     pattern; NONE for a wild one. *)
  fun conOf (p : pat) : (int * pat option) option =
    case p of
      PList ([], _, _) => SOME (Types.nilTag (), NONE)
    | PList (q :: rest, sp, _) => SOME (Types.consTag (), SOME (PTuple ([q, PList (rest, sp, noId)], sp, noId)))
    | PVar (_, slot, sp, _) => (case info (slot, sp) of PICon i => SOME (#tag i, NONE) | _ => NONE)
    | PApp (_, slot, arg, sp, _) => (case info (slot, sp) of PICon i => SOME (#tag i, SOME arg) | _ => NONE)
    | _ => NONE

  fun exnOf (p : pat) : (exninfo * pat option) option =
    case p of
      PVar (_, slot, sp, _) => (case info (slot, sp) of PIExn e => SOME (e, NONE) | _ => NONE)
    | PApp (_, slot, arg, sp, _) => (case info (slot, sp) of PIExn e => SOME (e, SOME arg) | _ => NONE)
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

  (* Which of the cases, each a string and its code, the string in v is,
     where they are many (stringSwitchMin): found by the string's length --
     tests of an int, which the code makes in line -- and then compared
     with each of that length in turn, or, where they are many
     (charSwitchMin), by a character where they differ most, and so on, and
     compared with one; deflt where it is none of them, which is small (a
     jump), since it is copied (performance M5, D7 B). Where there are many
     lengths or characters, a test of `<` halves them. The two thresholds
     are what the compiler compiling itself found best: a test of a
     character saves a comparison of strings, but the code grows, and the
     compiler takes longer over every node it makes. *)
  val stringSwitchMin = 6
  val charSwitchMin = 8

  fun stringSwitch (v : int, cases : (string * lexp) list, deflt : lexp) : lexp =
    let
      val charTy = Ty.con (#stamp Types.charTycon, "char", [])
      fun prim (p, dom, r, args) = Prim (p, SOME (Ty.arrow (dom, r)), args)
      fun pair t = Ty.tuple [t, t]
      fun sameString s = prim ("poly_eq", pair Ty.string, Ty.bool, [Var v, Const (CString s, Ty.string)])
      (* the groups of xs by key, in the order of their keys *)
      fun groupBy (key : 'a -> int) (xs : 'a list) : (int * 'a list) list =
        let
          fun insert (k, x, []) = [(k, [x])]
            | insert (k, x, (g as (k', ys)) :: rest) =
                if k = k' then (k', ys @ [x]) :: rest
                else if k < k' then (k, [x]) :: g :: rest
                else g :: insert (k, x, rest)
        in List.foldl (fn (x, gs) => insert (key x, x, gs)) [] xs end
      (* the code of each group by the key in w, of type ty: a test of
         equality for each of a few, else a halving by lt *)
      fun dispatch (w : int, ty : Ty.ty, lt : string, const : int -> lexp, groups : (int * lexp) list) : lexp =
        if List.length groups <= 3 then
          List.foldr (fn ((k, code), rest) => If (prim ("poly_eq", pair ty, Ty.bool, [Var w, const k]), code, rest))
                     deflt groups
        else
          let
            val half = List.length groups div 2
            val (low, high) = (List.take (groups, half), List.drop (groups, half))
          in
            If (prim (lt, pair ty, Ty.bool, [Var w, const (#1 (hd high))]),
                dispatch (w, ty, lt, const, low), dispatch (w, ty, lt, const, high))
          end
      (* the cases of one length: compared in turn, or, where they are
         many, told apart by the character at the place where they have the
         most different ones *)
      fun byChars (len : int, cs : (string * lexp) list) : lexp =
        if List.length cs < charSwitchMin then
          List.foldr (fn ((s, code), rest) => If (sameString s, code, rest)) deflt cs
        else
          let
            fun distinct i =
              List.length (groupBy (fn (s, _) => Char.ord (String.sub (s, i))) cs)
            fun best (i, (bi, bn)) =
              if i = len then bi
              else let val n = distinct i in best (i + 1, if n > bn then (i, n) else (bi, bn)) end
            val i = best (0, (0, 0))
            val w = freshVar ()
            val groups = groupBy (fn (s, _) => Char.ord (String.sub (s, i))) cs
          in
            Let (w, prim ("string_sub", Ty.tuple [Ty.string, Ty.int], charTy, [Var v, Const (CInt (IntInf.fromInt i), Ty.int)]),
                 dispatch (w, charTy, "char_lt", fn k => Const (CChar k, charTy),
                           List.map (fn (_, g) => (Char.ord (String.sub (#1 (hd g), i)), byChars (len, g))) groups))
          end
      val n = freshVar ()
      val groups = groupBy (fn (s, _) => String.size s) cases
    in
      Let (n, prim ("string_size", Ty.string, Ty.int, [Var v]),
           dispatch (n, Ty.int, "int_lt", fn k => Const (CInt (IntInf.fromInt k), Ty.int),
                     List.map (fn (len, g) => (len, byChars (len, g))) groups))
    end

  (* limit: a tree too big for the rules raises TooBig, for them to be
     matched rule by rule instead (which a match with an or-pattern cannot
     be: a rule of one is a row for each of its alternatives, which all jump
     to its body) *)
  fun trees (vars : int list, rules : (pat list * lexp) list, failure : lexp, limit : bool) : lexp =
    let
      (* A rule's join: its label, parameters and body, the stamps whose
         values a jump to it passes, and whether the leaf sets the rule's
         globals. A rule with an or-pattern has a leaf for each alternative,
         and a global is set once: its join takes the globals as parameters
         too, and its body sets them. *)
      fun join (pats, body) =
        if List.exists hasOr pats then
          let
            val locals = varsOf pats
            val globals = boundVars true pats
            val fresh = List.map (fn (_, t) => (freshVar (), t)) globals
            val body = ListPair.foldr (fn ((f, _), (g, _), k) => Seq (SetGlobal (g, Var f), k)) body (fresh, globals)
          in (freshVar (), locals @ fresh, body, List.map #1 (locals @ globals), false) end
        else let val params = varsOf pats in (freshVar (), params, body, List.map #1 params, true) end
      val joins = Vector.fromList (List.map join rules)
      val budget = ref (64 + 16 * List.length rules)
      fun spend () = if limit then (budget := !budget - 1; if !budget < 0 then raise TooBig else ()) else ()

      (* the rule of the first row matches: its globals set, and a jump to
         its body with the values of its variables *)
      fun leaf ({binds, rule, ...} : row) : lexp =
        let
          val (j, _, _, args, setGlobals) = Vector.sub (joins, rule)
          fun valueOf s =
            case List.find (fn (s', _, _) => s' = s) binds of
              SOME (_, _, w) => Var w
            | NONE => Error.bug "a variable of a rule not bound on the way to it"
          val jump = Jump (j, List.map valueOf args)
        in
          if setGlobals then List.foldl (fn ((s, true, w), k) => Seq (SetGlobal (s, Var w), k) | (_, k) => k) jump binds
          else jump
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
                    PTuple (ps, _, _) => ps
                  | PRecord _ => fieldsOf q
                  | _ => List.tabulate (arity, fn _ => PWild (sp, noId))
                val sub = tree (replace (cols, c, ws), List.map (fn r => put (r, fields (cell r))) rows)
              in
                #2 (List.foldr (fn (w, (i, k)) => (i - 1, Let (w, Select (i, Var v), k))) (arity - 1, sub) ws)
              end
          | KRef =>
              let
                val w = freshVar ()
                fun inner q = case q of PApp (_, _, arg, _, _) => arg | _ => PWild (sp, noId)
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
                        NONE => SOME (put (r, if hasArg then [PWild (sp, noId)] else []))
                      | SOME (t', arg) =>
                          if t' <> t then NONE
                          else SOME (put (r, if hasArg then [case arg of SOME a => a | NONE => PWild (sp, noId)] else []))
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
                      put (r, PWild (sp, noId) :: (if hasArg then [case exnOf q of SOME (_, SOME a) => a | _ => PWild (sp, noId)] else []))
                    else put (r, q :: (if hasArg then [PWild (sp, noId)] else []))
                  end
                val yes = tree (replace (cols, c, v :: (if hasArg then [w] else [])), List.map yesRow rows)
                val yes = if hasArg then Let (w, ExnArg (exnArgTy e, Var v), yes) else yes
                val no = tree (cols, List.filter (fn r => not (same (cell r))) rows)
              in
                If (Prim ("ptr_eq", SOME (eqTy Ty.exnCon), [ExnCon (Var v), exnConExp e]), yes, no)
              end
          | KConst =>
              let
                val (sc, slot) = case p of PScon (sc, slot, _, _) => (sc, slot) | _ => Error.bug "a constant pattern"
                fun same q =
                  case q of
                    PScon (sc', slot', _, _) =>
                      if literal (sc, slot) andalso literal (sc', slot') then sconConst sc = sconConst sc' else sc = sc'
                  | _ => false
                fun other q =
                  case q of
                    PScon (sc', slot', _, _) => literal (sc, slot) andalso literal (sc', slot') andalso sconConst sc <> sconConst sc'
                  | _ => false
                (* where the value is the constant, a row of another literal
                   cannot match; one of another constant is still tested *)
                fun oneConstant () =
                  let
                    val yes = tree (cols, List.mapPartial (fn r => let val q = cell r
                                                                   in
                                                                     if same q then SOME (put (r, [PWild (sp, noId)]))
                                                                     else if other q then NONE
                                                                     else SOME r
                                                                   end) rows)
                    val no = tree (cols, List.filter (fn r => not (same (cell r))) rows)
                    val t = sconTy (sc, slot)
                  in
                    If (Prim ("poly_eq", SOME (eqTy t), [Var v, sconExp (sc, slot)]), yes, no)
                  end
                (* a column of strings written as constants, where it names
                   many: split by every one at once, the value found among
                   them by stringSwitch, and the rows of none a join point
                   it jumps to (performance M5) *)
                fun stringOf q =
                  case q of
                    PScon (sc' as SString s, slot', _, _) => if literal (sc', slot') then SOME s else NONE
                  | _ => NONE
                val strings =
                  List.foldl (fn (r, acc) => case stringOf (cell r) of
                                               SOME s => if List.exists (fn s' => s' = s) acc then acc else acc @ [s]
                                             | NONE => acc) [] rows
                fun everyString () =
                  let
                    val rest = replace (cols, c, [])
                    fun branch s =
                      tree (rest, List.mapPartial (fn r => case stringOf (cell r) of
                                                             SOME s' => if s' = s then SOME (put (r, [])) else NONE
                                                           | NONE => SOME (put (r, []))) rows)
                    val none = tree (rest, List.mapPartial (fn r => if isWild (cell r) then SOME (put (r, [])) else NONE) rows)
                    val j = freshVar ()
                  in
                    Join (j, [], none, stringSwitch (v, List.map (fn s => (s, branch s)) strings, Jump (j, [])))
                  end
              in
                if List.length strings >= stringSwitchMin andalso Ty.equal (sconTy (sc, slot), Ty.string)
                   andalso List.all (fn r => isWild (cell r) orelse isSome (stringOf (cell r))) rows
                then everyString ()
                else oneConstant ()
              end
        end

      (* every choice of an element from each list, in order *)
      fun choices [] = [[]]
        | choices (xs :: rest) =
          let val tails = choices rest
          in List.concat (List.map (fn x => List.map (fn t => x :: t) tails) xs) end
      fun rowsOf (i, (pats, _)) =
        if List.exists hasOr pats then
          List.map (fn alt => {pats = alt, binds = [], rule = i}) (choices (List.map alternatives pats))
        else [{pats = pats, binds = [], rule = i}]
      val tree = tree (vars, List.concat (List.tabulate (Vector.length joins, fn i => rowsOf (i, List.nth (rules, i)))))
    in
      Vector.foldr (fn ((j, params, body, _, _), k) => Join (j, params, body, k)) tree joins
    end

  fun useTrees rules = List.length rules >= 2 andalso Pass.enabled ("trees", 1)

  (* A match with an or-pattern is a decision tree at every level. *)
  fun anyOr (rules : (pat list * lexp) list) = List.exists (fn (pats, _) => List.exists hasOr pats) rules

  (* Match the value in v against rules in order; `failure` runs if none matches. *)
  fun compileMatch (v : int, rules : (pat * lexp) list, failure : lexp) : lexp =
    let val clauses = List.map (fn (p, b) => ([p], b)) rules
    in
      if anyOr clauses then trees ([v], clauses, failure, false)
      else if useTrees rules then
        trees ([v], clauses, failure, true) handle TooBig => backtrack (v, rules, failure)
      else backtrack (v, rules, failure)
    end

  (* Multi-argument clauses (fun declarations): each clause has one pattern per parameter. *)
  fun compileClauses (vars : int list, clauses : (pat list * lexp) list, failure : lexp) : lexp =
    if anyOr clauses then trees (vars, clauses, failure, false)
    else if useTrees clauses then trees (vars, clauses, failure, true) handle TooBig => backtrackClauses (vars, clauses, failure)
    else backtrackClauses (vars, clauses, failure)
end
