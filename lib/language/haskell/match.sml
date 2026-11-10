(* Implements: HS_MATCH *)
structure HsMatch :> HS_MATCH =
struct
  structure A = HsAst
  structure C = HsDsCore
  structure V = HsDsEnv

  datatype order = Report | Sestoft

  val order = ref Report

  type occurrence = Core.atom * Core.ty

  type clause = A.pat list * (V.env * C.texp -> C.texp)

  fun nameText (A.Name (_, {name, ...})) = name
  fun nameSpan (A.Name ({span, ...}, _)) = span

  fun conPat (c, ps) = A.P (A.noAnn, A.PCon (c, ps))
  fun builtinName n = A.Name (A.noAnn, {qual = "", name = n})

  (* a list pattern as the constructors it abbreviates *)
  fun listPat ps =
    List.foldr (fn (p, rest) => conPat (builtinName ":", [p, rest])) (conPat (builtinName "[]", [])) ps

  fun charPat c = A.P (A.noAnn, A.PLit (A.Lit (A.noAnn, A.LChar (c, ""))))

  fun variables (A.P (_, x)) =
    case x of
      A.PVar v => [v]
    | A.PCon (_, ps) => List.concat (List.map variables ps)
    | A.PRec (_, fs) => List.concat (List.map (fn (_, p) => variables p) fs)
    | A.PTuple ps => List.concat (List.map variables ps)
    | A.PList ps => List.concat (List.map variables ps)
    | A.PParen p => variables p
    | A.PAs (v, p) => v :: variables p
    | A.PLazy p => variables p
    | A.PNPlusK (v, _) => [v]
    | A.PSeq items => List.concat (List.map (fn A.PA p => variables p | _ => []) items)
    | A.PJux ps => List.concat (List.map variables ps)
    | _ => []

  fun lazy (A.P (_, x)) =
    case x of
      A.PVar _ => true
    | A.PWild => true
    | A.PLazy _ => true
    | A.PParen p => lazy p
    | A.PAs (_, p) => lazy p
    | _ => false

  (* a constructor's fields, as a case binds them, matched *)
  fun occurrences fields = List.map (fn (x, t) => (Core.Var x, t)) fields

  (* the type of a pattern's variable, by its binder's record *)
  fun varType (env, v) =
    case V.bindOf (nameSpan v) of
      SOME (HsEvidence.Mono t) => V.ty env t
    | SOME (HsEvidence.Binding {scheme, ...}) => #1 (V.scheme env scheme)
    | _ => raise Fail ("HsMatch: no record of the binder " ^ nameText v)

  (* whether the constructor of key k is a newtype's *)
  fun newtypeOf k =
    case C.conInfo (V.conName k) of
      SOME {tycon, ...} => (case C.tycon tycon of SOME (_, C.NewS _) => true | _ => false)
    | NONE => false

  (* ---- The Report's order ---- *)

  fun pattern (env, occ as (a, t), p as A.P ({span, ...}, x), success, failure) : C.texp =
    case x of
      A.PVar v => success (V.bind (env, nameText v, a, t))
    | A.PWild => success env
    | A.PParen q => pattern (env, occ, q, success, failure)
    | A.PAs (v, q) => pattern (V.bind (env, nameText v, a, t), occ, q, success, failure)
    | A.PLazy q =>
        if lazy q then pattern (env, occ, q, success, failure)
        else
          (* rule (d): each variable a match of its own, made when forced *)
          let
            fun bindVar (v, k) =
              let
                val vt = varType (env, v)
                val x = C.fresh "z"
                fun found env' =
                  case V.lookup (env', nameText v) of
                    SOME (a', t') => (Core.Atom a', t')
                  | NONE => raise Fail "HsMatch: a variable of a lazy pattern"
                val m = C.atom (C.fail ("exn_pattern", "irrefutable pattern failed", vt),
                                fn (fa, ft) => pattern (env, occ, q, found, (Core.Atom fa, ft)))
              in
                C.let_ (x, vt, m, k (Core.Var x, vt))
              end
            fun go ([], env') = success env'
              | go (v :: rest, env') = bindVar (v, fn (xa, xt) => go (rest, V.bind (env', nameText v, xa, xt)))
          in
            go (variables q, env)
          end
    | A.PTuple ps => pattern (env, occ, conPat (builtinName (HsTypes.tupleCon (length ps)), ps), success, failure)
    | A.PList ps => pattern (env, occ, listPat ps, success, failure)
    | A.PSeq [A.PA l, A.PO (A.ConOp c), A.PA r] => pattern (env, occ, conPat (c, [l, r]), success, failure)
    | A.PCon (c, ps) =>
        let val k = V.valueKey c
        in
          if newtypeOf k then
            (* rules (k), (l): a newtype's pattern forces nothing *)
            case C.unfold t of
              SOME rep => C.atom (C.cast ((Core.Atom a, t), rep),
                                  fn occ' => pattern (env, occ', hd ps, success, failure))
            | NONE => raise Fail ("HsMatch: a newtype's pattern on " ^ CoreText.showTy t)
          else
            (* rule (g): the constructor tested, its fields left to right *)
            C.caseCon (a, t, [(V.conName k, fn fields => patterns (env, occurrences fields, ps, success, failure))], SOME failure)
        end
    | A.PRec (c, fs) =>
        let
          val k = V.valueKey c
          val names = V.fieldsOf k
          fun index f =
            let
              val fk = V.valueKey f
              fun go (i, n :: rest) = if n = fk then i else go (i + 1, rest)
                | go (_, []) = raise Fail ("HsMatch: no field " ^ nameText f ^ " of " ^ nameText c)
            in
              go (0, names)
            end
          (* rules (m), (n), (o): the fields in the pattern's order *)
          fun matchFields (env, fields) =
            patterns (env, List.map (fn (f, _) => List.nth (occurrences fields, index f)) fs, List.map #2 fs, success, failure)
        in
          if newtypeOf k then
            case (C.unfold t, fs) of
              (SOME rep, [(_, q)]) => C.atom (C.cast ((Core.Atom a, t), rep), fn occ' => pattern (env, occ', q, success, failure))
            | (SOME _, _) => success env
            | (NONE, _) => raise Fail ("HsMatch: a newtype's pattern on " ^ CoreText.showTy t)
          else C.caseCon (a, t, [(V.conName k, fn fields => matchFields (env, fields))], SOME failure)
        end
    | A.PLit (A.Lit (_, A.LChar (c, _))) =>
        let val (s, st) = success env
        in
          (Core.Case (Core.Atom a, C.fresh "c", [Core.AltLit (Core.LChar c, s), Core.AltDefault (#1 failure)]), C.lazyTy st)
        end
    | A.PLit (A.Lit (_, A.LString (cs, _))) => pattern (env, occ, listPat (List.map charPat cs), success, failure)
    | A.PLit (A.Lit ({span = ls, ...}, l)) => equals (env, occ, ls, l, false, success, failure)
    | A.PNegLit (A.Lit (_, l)) => equals (env, occ, span, l, true, success, failure)
    | A.PNPlusK (v, A.Lit (_, A.LInt (k, _))) =>
        (* rule (s): v >= k, and n bound to v - k *)
        let
          val (hty, dicts) = V.overloadedOf ("npk", span)
          val integral = case dicts of (_, d) :: _ => d | [] => raise Fail "HsMatch: an n+k pattern with no dictionary"
          val cls = case dicts of (c, _) :: _ => c | [] => ""
          val ord = V.superDict env (integral, cls, V.prelude ("t", "Ord"))
          val num = V.superDict env (integral, cls, V.prelude ("t", "Num"))
          val ct = V.ty env hty
          val lit = V.integerLit env (k, hty, num)
          val test = C.appAtoms (V.method env (V.prelude ("v", ">="), [ct], [V.dict env ord]), [(Core.Atom a, t), lit])
          val n = C.fresh "n"
          val minus = C.appAtoms (V.method env (V.prelude ("v", "-"), [ct], [V.dict env num]), [(Core.Atom a, t), lit])
        in
          C.ifBool (test, C.let_ (n, ct, minus, success (V.bind (env, nameText v, Core.Var n, ct))), failure)
        end
    | A.PNPlusK _ => raise Fail "HsMatch: an n+k pattern whose k is no integer"
    | A.PSeq _ => raise Fail "HsMatch: a sequence of patterns fixity did not resolve"
    | A.PJux _ => raise Fail "HsMatch: juxtaposed patterns"

  (* rule (h): a numeric literal, compared by == at its type *)
  and equals (env, (a, t), span, l, negative, success, failure) =
    let
      val (hty, dicts) = V.overloadedOf ("patlit", span)
      fun dictOf name =
        case List.find (fn (c, _) => c = V.prelude ("t", name)) dicts of
          SOME (_, d) => d
        | NONE => raise Fail ("HsMatch: a literal pattern with no " ^ name ^ " dictionary")
      val ct = V.ty env hty
      val eq = dictOf "Eq"
      val value =
        case l of
          A.LInt (i, _) =>
            let val num = dictOf "Num"
            in
              if negative then C.appAtoms (V.method env (V.prelude ("v", "negate"), [ct], [V.dict env num]),
                                           [V.integerLit env (i, hty, num)])
              else V.integerLit env (i, hty, num)
            end
        | A.LFloat text =>
            let
              val frac = dictOf "Fractional"
              val num = V.superDict env (frac, V.prelude ("t", "Fractional"), V.prelude ("t", "Num"))
              val r = V.rationalLit env (text, hty, frac)
            in
              if negative then C.appAtoms (V.method env (V.prelude ("v", "negate"), [ct], [V.dict env num]), [r]) else r
            end
        | _ => raise Fail "HsMatch: a literal pattern of no number"
      val test = C.appAtoms (V.method env (V.prelude ("v", "=="), [ct], [V.dict env eq]), [(Core.Atom a, t), value])
    in
      C.ifBool (test, success env, failure)
    end

  and patterns (env, occs, ps, success, failure) =
    case (occs, ps) of
      ([], []) => success env
    | (oc :: ocs, p :: rest) => pattern (env, oc, p, fn env' => patterns (env', ocs, rest, success, failure), failure)
    | _ => raise Fail "HsMatch: patterns and what they match differ in number"

  (* Each clause is made before what follows it, so that the type of the
     match is its right-hand side's; what follows is bound by a lazy `let`
     to the variable the clause falls to, and left out where the clause
     cannot fall. The variable's type is not read while the clause is
     made: a test's first alternative is the one that matches. *)
  fun report (env, occs, rows, failure) =
    let
      fun row ((ps, rhs), rest) =
        let
          val f = C.fresh "fail"
          val fl = (Core.Atom (Core.Var f), C.unitTy)
          val (e, t) = patterns (env, occs, ps, fn env' => rhs (env', fl), fl)
        in
          if C.mentions (f, e) then
            C.let_ (f, t, case rest of [] => failure t | r :: more => row (r, more), (e, t))
          else (e, t)
        end
    in
      case rows of
        [] => raise Fail "HsMatch: a match of no clause"
      | r :: more => row (r, more)
    end

  (* ---- Sestoft's order ---- *)

  (* what the tests made so far say of an occurrence: its constructor and
     fields, or the constructors it is not *)
  datatype knowledge = Pos of string * occurrence list | Neg of string list

  (* a pattern the tree takes apart: variables, wildcards, `x@p`, and a data
     type's constructors *)
  fun treeable (A.P (_, x)) =
    case x of
      A.PVar _ => true
    | A.PWild => true
    | A.PParen p => treeable p
    | A.PAs (_, p) => treeable p
    | A.PTuple ps => List.all treeable ps
    | A.PList ps => List.all treeable ps
    | A.PCon (c, ps) => not (newtypeOf (V.valueKey c)) andalso List.all treeable ps
    | A.PSeq [A.PA l, A.PO (A.ConOp c), A.PA r] => treeable (conPat (c, [l, r]))
    | _ => false

  fun varName (Core.Var x) = x
    | varName (Core.Lit _) = ""

  (* The tree is made twice: first to count the leaves of each clause, then
     for good. A clause with one leaf has its right-hand side made there; one
     with several has it bound once outside the tree, a function of its
     variables and of what its guards fall to, so that none is copied. What
     a clause falls to is bound once its type is known, as in the Report's
     order; the match that fails at the end, once the match's is. *)
  fun sestoft (env, occs, rows, failure) =
    let
      val indexed = ListPair.zip (List.tabulate (length rows, fn i => i), rows)
      (* `tree (leaf, fails)`: the tree, a clause `i` matched being
         `leaf (i, var, rest)`, `var` what each variable is bound to and
         `rest` what follows the clause, and a match that fails `fails ()` *)
      fun tree (leaf, fails) =
        let
          fun compile (know, rows) =
            case rows of
              [] => fails ()
            | (i, (ps, _)) :: rest =>
                if List.all treeable ps then work (know, ListPair.zip (occs, ps), [], i, rest)
                else
                  (* the Report's order for this clause, what was known forgotten *)
                  let
                    val f = C.fresh "fail"
                    val fl = (Core.Atom (Core.Var f), C.unitTy)
                    val (e, t) =
                      patterns (env, occs, ps,
                                fn env' => leaf (i, fn x => valOf (V.lookup (env', x)), fn () => fl), fl)
                  in
                    if C.mentions (f, e) then C.let_ (f, t, compile (know, rest), (e, t)) else (e, t)
                  end
          and work (know, todo, bound, i, rest) =
            case todo of
              [] =>
                leaf (i, fn x => case List.find (fn (n, _) => n = x) bound of
                                   SOME (_, occ) => occ
                                 | NONE => raise Fail "HsMatch: a variable the tree did not bind",
                      fn () => compile (know, rest))
            | ((a, t), A.P (_, x)) :: more =>
                case x of
                  A.PVar v => work (know, more, (nameText v, (a, t)) :: bound, i, rest)
                | A.PWild => work (know, more, bound, i, rest)
                | A.PParen q => work (know, ((a, t), q) :: more, bound, i, rest)
                | A.PAs (v, q) => work (know, ((a, t), q) :: more, (nameText v, (a, t)) :: bound, i, rest)
                | A.PTuple ps => work (know, ((a, t), conPat (builtinName (HsTypes.tupleCon (length ps)), ps)) :: more, bound, i, rest)
                | A.PList ps => work (know, ((a, t), listPat ps) :: more, bound, i, rest)
                | A.PSeq [A.PA l, A.PO (A.ConOp c), A.PA r] => work (know, ((a, t), conPat (c, [l, r])) :: more, bound, i, rest)
                | A.PCon (c, ps) =>
                    let
                      val k = V.conName (V.valueKey c)
                      val key = varName a
                      fun matched (know', fields) = work (know', ListPair.zip (fields, ps) @ more, bound, i, rest)
                    in
                      case HsStringMap.find (know, key) of
                        SOME (Pos (k', fields)) => if k = k' then matched (know, fields) else compile (know, rest)
                      | known =>
                          let val nots = case known of SOME (Neg ks) => ks | _ => []
                          in
                            if List.exists (fn n => n = k) nots then compile (know, rest)
                            else
                              C.caseCon (a, t,
                                         [(k, fn fields =>
                                                let val fs = occurrences fields
                                                in matched (HsStringMap.insert (know, key, Pos (k, fs)), fs) end)],
                                         SOME (compile (HsStringMap.insert (know, key, Neg (k :: nots)), rest)))
                          end
                    end
                | _ => raise Fail "HsMatch: a pattern the tree does not take apart"
        in
          compile (HsStringMap.empty, indexed)
        end

      (* the leaves of each clause, counted *)
      val counts = Array.array (length rows, 0)
      val _ = tree (fn (i, _, _) => (Array.update (counts, i, Array.sub (counts, i) + 1); C.unitVal ()), C.unitVal)

      val result : Core.ty option ref = ref NONE
      fun typed t = case !result of NONE => result := SOME (C.lazyTy t) | SOME _ => ()
      (* a clause's right-hand side in the scope of its variables, bound by
         `var`, and what its guards fall to *)
      fun made ((ps, rhs), var) =
        let
          val vars = List.concat (List.map variables ps)
          val env' = List.foldl (fn (v, e) => let val (a, t) = var v in V.bind (e, nameText v, a, t) end) env vars
          val fl = C.fresh "fail"
          val (body, bt) = rhs (env', (Core.Atom (Core.Var fl), C.unitTy))
        in
          typed bt; (fl, (body, bt))
        end
      (* each clause of several leaves, a function bound outside the tree *)
      val lifted =
        List.map
          (fn (i, row as (ps, _)) =>
             if Array.sub (counts, i) <= 1 then NONE
             else
               let
                 val vars = List.concat (List.map variables ps)
                 val vtys = List.map (fn v => varType (env, v)) vars
                 val names = List.map (fn _ => C.fresh "v") vars
                 val (fl, (body, bt)) =
                   made (row, fn v => let val (n, t) = valOf (List.find (fn (w, _) => nameText w = nameText v) (ListPair.zip (vars, ListPair.zip (names, vtys))))
                                      in (Core.Var (#1 t), #2 t) end handle Option => raise Fail "HsMatch: a clause's variable")
                 val falls = C.mentions (fl, body)
                 val binders = ListPair.map Core.ValBinder (names, vtys) @ (if falls then [Core.ValBinder (fl, C.lazyTy bt)] else [])
               in
                 SOME {name = C.fresh "rhs", value = C.lam (binders, (body, bt)), vars = vars, falls = falls}
               end)
          indexed
      val ff = C.fresh "fail"
      fun leaf (i, var, rest) =
        case List.nth (lifted, i) of
          SOME {name, value, vars, falls} =>
            let
              val f = C.var (name, #2 value)
              val args = List.map (fn v => let val (a, t) = var (nameText v) in (Core.Atom a, t) end) vars
              val r = valOf (!result)
            in
              if falls then
                let val x = C.fresh "fail"
                in C.let_ (x, r, rest (), C.appAtoms (f, args @ [C.var (x, r)])) end
              else C.appAtoms (f, args)
            end
        | NONE =>
            let val (fl, (body, bt)) = made (List.nth (rows, i), fn v => var (nameText v))
            in if C.mentions (fl, body) then C.let_ (fl, C.lazyTy bt, rest (), (body, bt)) else (body, bt) end
      val (body, _) = tree (leaf, fn () => (Core.Atom (Core.Var ff), C.unitTy))
      val r =
        case !result of
          SOME r => r
        | NONE =>
            (* no clause can match: the first's type, made only for it *)
            (case rows of
               (ps, rhs) :: _ =>
                 let val vars = List.concat (List.map variables ps)
                 in #2 (#2 (made ((ps, rhs), fn v => (Core.Var (C.fresh "unreached"), varType (env, v))))) end
             | [] => raise Fail "HsMatch: a match of no clause")
      val r = C.lazyTy r
      val whole = if C.mentions (ff, body) then C.let_ (ff, r, failure r, (body, r)) else (body, r)
    in
      List.foldr (fn (SOME {name, value, ...}, b) => C.let_ (name, #2 value, value, b) | (NONE, b) => b) whole lifted
    end

  fun clauses (env, occs, rows, failure) =
    case !order of
      Report => report (env, occs, rows, failure)
    | Sestoft => sestoft (env, occs, rows, failure)
end
