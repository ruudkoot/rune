(* Implements: HS_DESUGAR *)
structure HsDesugar :> HS_DESUGAR =
struct
  structure A = HsAst
  structure M = HsStringMap
  structure T = HsTypes
  structure E = HsEvidence
  structure C = HsDsCore
  structure V = HsDsEnv
  structure Mt = HsMatch
  structure Mo = HsModules
  structure K = HsKinds

  type module_ = {id : string, ast : A.module, library : bool}

  val translationNames =
    List.map (fn n => ("v", "Prelude", n))
      ["fromInteger", "fromRational", "negate", "==", ">=", "-", "enumFrom", "enumFromThen", "enumFromTo",
       "enumFromThenTo", "concatMap", ">>=", ">>", "fail", "True", "False"]
    @ [("t", "Prelude", "Bool"), ("v", "Ratio", ":%"), ("t", "Ratio", "Ratio")]

  fun bug msg = raise Fail ("HsDesugar: " ^ msg)

  (* a type that cannot be worked out from the expression alone, and what
     it is of *)
  exception Untyped of string

  fun nameText (A.Name (_, {name, ...})) = name
  fun nameSpan (A.Name ({span, ...}, _)) = span

  val boolTy = Core.TCon "Bool"
  fun listTy t = Core.TApp (Core.TCon "[]", t)
  fun elemOf t = case C.lazyTy t of Core.TApp (Core.TCon "[]", e) => e | t' => raise Untyped ("a list of " ^ CoreText.showTy t')
  fun lazyOpt (SOME t) = SOME (C.lazyTy t) | lazyOpt NONE = NONE

  (* types and kinds of the foralls at a type's head *)
  fun peel (Core.TForall (a, k, b)) = let val (ks, body) = peel b in ((a, k) :: ks, body) end
    | peel t = ([], t)

  (* ---- Bindings as the checker groups them ---- *)

  datatype binding =
      FunB of {name : A.name, clauses : (A.funlhs * A.rhs) list}
    | PatB of {pat : A.pat, rhs : A.rhs, vars : A.name list}

  fun funName (A.F (_, x)) =
    case x of
      A.FPrefix (v, _) => v
    | A.FInfix (_, A.VarOp v, _) => v
    | A.FInfix (_, A.ConOp v, _) => v
    | A.FParen (l, _) => funName l

  fun funArgs (A.F (_, x)) =
    case x of
      A.FPrefix (_, ps) => ps
    | A.FInfix (p1, _, p2) => [p1, p2]
    | A.FParen (l, ps) => funArgs l @ ps

  fun collect ds =
    let
      fun go ([], acc) = List.rev acc
        | go (A.D (_, x) :: rest, acc) =
            case x of
              A.DFun (f, r) =>
                let val n = funName f
                in
                  case acc of
                    FunB {name, clauses} :: more =>
                      if V.valueKey name = V.valueKey n then go (rest, FunB {name = name, clauses = clauses @ [(f, r)]} :: more)
                      else go (rest, FunB {name = n, clauses = [(f, r)]} :: acc)
                  | _ => go (rest, FunB {name = n, clauses = [(f, r)]} :: acc)
                end
            | A.DPat (p, r) => go (rest, PatB {pat = p, rhs = r, vars = Mt.variables p} :: acc)
            | _ => go (rest, acc)
    in
      go (ds, [])
    end

  fun bindingNames b = case b of FunB {name, ...} => [name] | PatB {vars, ...} => vars

  fun simpleVar (A.P (_, A.PVar v)) = SOME v
    | simpleVar _ = NONE

  (* the variables an expression's bindings name, by key *)
  fun freeVars b =
    let
      val out = ref []
      fun n nm = out := V.valueKey nm :: !out
      fun e (A.E (_, x)) =
        case x of
          A.EVar v => n v
        | A.EApp (f, a) => (e f; e a)
        | A.ESeq items => List.app (fn A.EA x => e x | A.EO (A.VarOp v) => n v | _ => ()) items
        | A.ELam (_, b) => e b
        | A.ELet (ds, b) => (List.app d ds; e b)
        | A.EIf (a, b, c) => (e a; e b; e c)
        | A.ECase (x, alts) => (e x; List.app (fn A.Alt (_, _, r) => rh r) alts)
        | A.EDo ss => List.app st ss
        | A.ETuple es => List.app e es
        | A.EParen x => e x
        | A.EList es => List.app e es
        | A.EEnum (a, b, c) => (e a; Option.app e b; Option.app e c)
        | A.EComp (x, qs) => (e x; List.app st qs)
        | A.ELeftSec (x, q) => (e x; case q of A.VarOp v => n v | _ => ())
        | A.ERightSec (q, x) => ((case q of A.VarOp v => n v | _ => ()); e x)
        | A.ERecCon (_, fs) => List.app (fn (_, x) => e x) fs
        | A.ERecUpd (x, fs) => (e x; List.app (fn (_, y) => e y) fs)
        | A.ESig (x, _, _) => e x
        | _ => ()
      and st (A.S (_, s)) = case s of A.SBind (_, x) => e x | A.SLet ds => List.app d ds | A.SExp x => e x
      and rh (A.Rhs (_, x)) =
        case x of
          A.Plain (x, w) => (e x; Option.app (List.app d) w)
        | A.Guarded (gs, w) => (List.app (fn A.Guard (_, g, x) => (e g; e x)) gs; Option.app (List.app d) w)
      and d (A.D (_, x)) = case x of A.DFun (_, r) => rh r | A.DPat (_, r) => rh r | _ => ()
    in
      (case b of FunB {clauses, ...} => List.app (fn (_, r) => rh r) clauses | PatB {rhs = r, ...} => rh r);
      !out
    end

  (* ---- State of a program ---- *)

  (* the values of the leaves, primitives that no file holds *)
  val leafKeys : unit M.map ref = ref M.empty
  (* the constructors of each data type, by the Core name of the type *)
  val tyconCons : string list M.map ref = ref M.empty
  (* the methods that have a default, by key *)
  val defaults : unit M.map ref = ref M.empty
  (* the primitives no Core has, for a message *)
  val missing : string list ref = ref []

  (* what a part of a desugaring leaves the next: the library's, a
     program's (HsDsCore's and HsDsEnv's declarations, and these) *)
  type state = {core : C.saved, env : V.saved, leafKeys : unit M.map, tyconCons : string list M.map,
                defaults : unit M.map, missing : string list}

  fun saveState () : state =
    {core = C.save (), env = V.save (), leafKeys = !leafKeys, tyconCons = !tyconCons, defaults = !defaults,
     missing = !missing}

  fun restoreState (s : state) =
    (C.restore (#core s); V.restore (#env s); leafKeys := #leafKeys s; tyconCons := #tyconCons s;
     defaults := #defaults s; missing := #missing s)

  (* a value: its name, its type (`NONE` for the one its body has once
     made) and how its body is made *)
  type value_ = string * Core.ty option * (unit -> C.texp)

  type library = {state : state, types : Core.decl list, values : value_ list}

  (* a body made the first time it is wanted and kept, or what failed in
     its making, raised again *)
  datatype kept = Todo | Made of C.texp | Failed of exn

  fun once (mk : unit -> C.texp) : unit -> C.texp =
    let
      val r = ref Todo
    in
      fn () =>
        case !r of
          Made v => v
        | Failed e => raise e
        | Todo => (let val v = mk () in r := Made v; v end handle e => (r := Failed e; raise e))
    end

  (* ---- Types of patterns ---- *)

  (* the type of the value of a binder, by its record *)
  fun recordType (env, r) =
    case r of
      SOME (E.Mono t) => V.ty env t
    | SOME (E.Binding {scheme, ...}) => #1 (V.scheme env scheme)
    | _ => raise Untyped "a binder with no record"

  fun conType (env, c) =
    let
      val key = V.valueKey c
      val {tys, ...} = V.useOf (nameSpan c)
    in
      case C.conInfo (V.conName key) of
        SOME {tycon, ...} => Core.apply (Core.TCon tycon, List.map (V.ty env) tys)
      | NONE => raise Untyped ("the constructor " ^ key)
    end

  (* a pattern's variable's type: a generalised one's at its variables,
     which a pattern binding's value has in scope *)
  fun varMonoType (env, v) =
    case V.bindOf (nameSpan v) of
      SOME (E.Binding {scheme = {ty, ...}, ...}) => V.ty env ty
    | r => recordType (env, r)

  fun patType env (A.P ({span, ...}, x)) =
    case x of
      A.PVar v => varMonoType (env, v)
    | A.PAs (v, _) => varMonoType (env, v)
    | A.PNPlusK (v, _) => varMonoType (env, v)
    | A.PCon (c, _) => conType (env, c)
    | A.PRec (c, _) => conType (env, c)
    | A.PTuple ps => Core.apply (Core.TCon (T.tupleCon (length ps)), List.map (patType env) ps)
    | A.PList (p :: _) => listTy (patType env p)
    | A.PLit (A.Lit (_, A.LChar _)) => Core.TCon "Char"
    | A.PLit (A.Lit (_, A.LString _)) => listTy (Core.TCon "Char")
    | A.PLit (A.Lit ({span = ls, ...}, _)) => V.ty env (#1 (V.overloadedOf ("patlit", ls)))
    | A.PNegLit _ => V.ty env (#1 (V.overloadedOf ("patlit", span)))
    | A.PLazy p => patType env p
    | A.PParen p => patType env p
    | A.PSeq [A.PA _, A.PO (A.ConOp c), A.PA _] => conType (env, c)
    | _ => raise Untyped ("a pattern at " ^ #file span ^ ":" ^ Int.toString (#start span))

  (* ---- Expressions ---- *)

  fun exp (env, want) (e as A.E ({span, ...}, x)) : C.texp =
    case x of
      A.EVar n => variable (env, n)
    | A.ECon n => constructor (env, n)
    | A.ELit l => literal (env, l)
    | A.EApp _ => application (env, want, e)
    | A.ESeq [A.EA l, A.EO (A.ConOp c), A.EA r] => conApp (env, c, [l, r])
    | A.ESeq [A.EA l, A.EO (A.VarOp n), A.EA r] => applyTo (env, variable (env, n), [l, r])
    | A.ESeq [A.ENeg, A.EA a] =>
        let
          val (t, ds) = V.overloadedOf ("neg", span)
          val ct = V.ty env t
        in
          C.appAtoms (V.method env (V.prelude ("v", "negate"), [ct], [V.dict env (#2 (hd ds))]), [exp (env, SOME ct) a])
        end
    | A.ESeq _ => bug "a sequence fixity did not resolve"
    | A.ELam (ps, b) =>
        (case want of
           SOME t =>
             let val (ptys, r) = C.params (t, length ps)
             in lambda (env, ptys, SOME r, ps, b) end
         | NONE => lambda (env, List.map (patType env) ps, NONE, ps, b))
    | A.ELet (ds, b) => localBindings (env, ds, fn env' => exp (env', want) b)
    | A.EIf (c, t, f) => C.ifBool (exp (env, SOME boolTy) c, exp (env, want) t, exp (env, want) f)
    | A.ECase (s, alts) => caseOf (env, want, s, alts)
    | A.EDo ss => doBlock (env, want, span, ss)
    | A.ETuple es =>
        let
          val wants =
            case want of
              SOME t => (case Core.spine t of (_, args) => if length args = length es then List.map SOME args else List.map (fn _ => NONE) es)
            | NONE => List.map (fn _ => NONE) es
          val xs = ListPair.map (fn (a, w) => exp (env, w) a) (es, wants)
        in
          C.con (T.tupleCon (length es), List.map (C.lazyTy o #2) xs, xs)
        end
    | A.EParen a => exp (env, want) a
    | A.EList es =>
        let
          val elemWant = case want of SOME t => (SOME (elemOf t) handle Untyped _ => NONE) | NONE => NONE
          val xs = List.map (exp (env, elemWant)) es
          val et = case (elemWant, xs) of
                     (SOME t, _) => t
                   | (NONE, (_, t) :: _) => C.lazyTy t
                   | (NONE, []) => raise Untyped ("an empty list at " ^ #file span ^ ":" ^ Int.toString (#start span))
          fun build [] = C.con ("[]", [et], [])
            | build (y :: rest) = C.con (":", [et], [y, build rest])
        in
          build xs
        end
    | A.EEnum (a, b, c) =>
        let
          val (t, ds) = V.overloadedOf ("enum", span)
          val ct = V.ty env t
          val (name, args) =
            case (b, c) of
              (NONE, NONE) => ("enumFrom", [a])
            | (SOME b, NONE) => ("enumFromThen", [a, b])
            | (NONE, SOME c) => ("enumFromTo", [a, c])
            | (SOME b, SOME c) => ("enumFromThenTo", [a, b, c])
        in
          C.appAtoms (V.method env (V.prelude ("v", name), [ct], [V.dict env (#2 (hd ds))]), List.map (exp (env, SOME ct)) args)
        end
    | A.EComp (a, qs) =>
        comprehension (env, case want of SOME t => (SOME (elemOf t) handle Untyped _ => NONE) | NONE => NONE, a, qs)
    | A.ELeftSec (a, q) =>
        (* (e op) = \x -> e op x, e bound once outside (3.5) *)
        C.atom (operator (env, q), fn (fa, ft) =>
          let val (ps, _) = C.params (ft, 2)
          in
            C.atom (exp (env, SOME (C.lazyTy (hd ps))) a, fn (va, vt) =>
              let val y = C.fresh "s" val yt = C.lazyTy (List.nth (ps, 1))
              in C.lam ([Core.ValBinder (y, yt)], C.appAtoms ((Core.Atom fa, ft), [(Core.Atom va, vt), C.var (y, yt)])) end)
          end)
    | A.ERightSec (q, a) =>
        (* (op e) = \x -> x op e *)
        C.atom (operator (env, q), fn (fa, ft) =>
          let val (ps, _) = C.params (ft, 2)
          in
            C.atom (exp (env, SOME (C.lazyTy (List.nth (ps, 1)))) a, fn (va, vt) =>
              let val y = C.fresh "s" val yt = C.lazyTy (hd ps)
              in C.lam ([Core.ValBinder (y, yt)], C.appAtoms ((Core.Atom fa, ft), [C.var (y, yt), (Core.Atom va, vt)])) end)
          end)
    | A.ERecCon (c, fs) => recordCon (env, c, fs)
    | A.ERecUpd (a, fs) => recordUpdate (env, a, fs)
    | A.ESig (a, _, _) =>
        let
          val {tys, dicts} = V.useOf span
        in
          case V.records ("sig", span) of
            E.Binding {scheme = {vars = [], ctx = [], ty}, ...} :: _ => exp (env, SOME (V.ty env ty)) a
          | (r as E.Binding _) :: _ =>
              let
                val v = C.fresh "sig"
                val (t, body) = withScheme (env, SOME r, fn (env', mono) => exp (env', SOME mono) a)
              in
                C.let_ (v, t, body, V.instantiate env (C.var (v, t), tys, dicts))
              end
          | _ => bug "an expression's signature with no record"
        end

  and variable (env, n as A.Name ({span, ...}, {qual, name})) =
    let val {tys, dicts} = V.useOf span
    in
      if qual = "" then
        case V.lookup (env, name) of
          SOME (a, t) => V.instantiate env ((Core.Atom a, t), tys, dicts)
        | NONE => constructor (env, n)
      else
        let val key = V.valueKey n
        in
          if M.member (!leafKeys, key) then leaf (env, key, tys)
          else V.instantiate env (V.global key, tys, dicts)
        end
    end

  (* a value of a leaf, whose Haskell type is forall a. a: at the type of
     its use, by its own type in Haskell's form *)
  and leaf (env, key, tys) =
    let
      val f = V.global key
      val (ks, body) = peel (#2 f)
    in
      if null ks then f
      else
        case (tys, V.matchType (body, List.map #1 ks, case tys of [t] => V.ty env t | _ => C.unitTy)) of
          ([_], SOME args) => C.app (f, List.map Core.TyArg args)
        | _ => bug ("the primitive " ^ V.coreName key ^ " used at a type of no instance of its own")
    end

  and constructor (env, n) =
    let
      val key = V.valueKey n
      val {tys, ...} = V.useOf (nameSpan n)
      val ctys = List.map (V.ty env) tys
      val cname = V.conName key
    in
      case C.conInfo cname of
        SOME {fields = [], ...} => C.con (cname, ctys, [])
      | SOME _ => C.app (V.global key, List.map Core.TyArg ctys)
      | NONE => bug ("the constructor " ^ cname ^ " is not declared")
    end

  and operator (env, q) =
    case q of
      A.VarOp n => variable (env, n)
    | A.ConOp n => constructor (env, n)

  and literal (env, A.Lit ({span, ...}, l)) =
    case l of
      A.LInt (i, _) => let val (t, ds) = V.overloadedOf ("lit", span) in V.integerLit env (i, t, #2 (hd ds)) end
    | A.LFloat text => let val (t, ds) = V.overloadedOf ("lit", span) in V.rationalLit env (text, t, #2 (hd ds)) end
    | A.LChar (c, _) => (Core.Atom (Core.Lit (Core.LChar c)), Core.TEval (Core.TCon "Char"))
    | A.LString (cs, _) => V.stringLit cs

  (* a function applied: its parameters' types are wanted of its arguments *)
  and applyTo (env, f, args) =
    let val (ptys, _) = C.params (#2 f, length args)
    in C.appAtoms (f, ListPair.map (fn (a, p) => exp (env, SOME (C.lazyTy p)) a) (args, ptys)) end

  and application (env, want, e) =
    let
      fun spine (A.E (_, A.EApp (f, a)), args) = spine (f, a :: args)
        | spine (A.E (_, A.EParen f), args) = spine (f, args)
        | spine (f, args) = (f, args)
      val (head, args) = spine (e, [])
    in
      case head of
        A.E (_, A.ECon c) => conApp (env, c, args)
      | A.E (_, A.ELam (ps, b)) =>
          (* a lambda applied: its parameters' types are its arguments' *)
          let
            val xs = List.map (exp (env, NONE)) args
            val n = Int.min (length ps, length xs)
            val f = lambda (env, List.map (C.lazyTy o #2) (List.take (xs, n)) @ List.map (patType env) (List.drop (ps, n)),
                            NONE, ps, b)
          in
            C.appAtoms (f, xs)
          end
      | _ => applyTo (env, exp (env, NONE) head, args)
    end

  (* a constructor applied: saturated and with no strict field, the
     constructor itself; a newtype's, a cast; otherwise its function *)
  and conApp (env, c, args) =
    let
      val key = V.valueKey c
      val cname = V.conName key
      val {tys, ...} = V.useOf (nameSpan c)
      val ctys = List.map (V.ty env) tys
    in
      case C.conInfo cname of
        SOME {fields, tycon, ...} =>
          let
            val newtype = case C.tycon tycon of SOME (_, C.NewS _) => true | _ => false
            val fts = C.fieldsAt (cname, ctys)
          in
            if newtype andalso length args = 1 then
              C.cast (exp (env, SOME (hd fts)) (hd args), Core.apply (Core.TCon tycon, ctys))
            else if length args = length fields andalso not (List.exists Core.isEval fields) then
              C.con (cname, ctys, ListPair.map (fn (a, f) => exp (env, SOME (C.lazyTy f)) a) (args, fts))
            else applyTo (env, constructor (env, c), args)
          end
      | NONE => bug ("the constructor " ^ cname ^ " is not declared")
    end

  and lambda (env, ptys, rwant, ps, b) =
    let
      val names = List.map (fn _ => C.fresh "p") ps
      val ptys = List.map C.lazyTy ptys
      val occs = ListPair.map (fn (n, t) => (Core.Var n, t)) (names, ptys)
      val m = Mt.clauses (env, occs, [(ps, fn (env', _) => exp (env', rwant) b)],
                          fn t => C.fail ("exn_pattern", "no match in a lambda", t))
    in
      C.lam (ListPair.map Core.ValBinder (names, ptys), m)
    end

  and caseOf (env, want, s, alts) =
    let
      val scrut =
        exp (env, NONE) s
        handle Untyped _ =>
          (case List.mapPartial (fn A.Alt (_, p, _) => (SOME (patType env p) handle Untyped _ => NONE)) alts of
             t :: _ => exp (env, SOME t) s
           | [] => raise Untyped ("a case's scrutinee at " ^ #file (A.spanOfExp s) ^ ":" ^ Int.toString (#start (A.spanOfExp s))))
    in
      C.atom (scrut, fn (a, t) =>
        Mt.clauses (env, [(a, C.lazyTy t)], List.map (fn A.Alt (_, p, r) => ([p], fn (env', fl) => rhs (env', want, r, fl))) alts,
                    fn t => C.fail ("exn_pattern", "no match in a case", t)))
    end

  and rhs (env, want, A.Rhs (_, x), fl) =
    case x of
      A.Plain (e, w) => withWhere (env, w, fn env' => exp (env', want) e)
    | A.Guarded (gs, w) => withWhere (env, w, fn env' => guards (env', want, gs, fl))

  and guards (env, want, gs, fl) =
    case gs of
      [] => fl
    | A.Guard (_, g, e) :: rest => C.ifBool (exp (env, SOME boolTy) g, exp (env, want) e, guards (env, want, rest, fl))

  and withWhere (env, NONE, k) = k env
    | withWhere (env, SOME ds, k) = localBindings (env, ds, k)

  (* 3.14 *)
  and doBlock (env, want, span, ss) =
    let
      val monad =
        case V.records ("do", span) of
          E.Overloaded {ty, dicts = (_, d) :: _} :: _ => SOME (ty, d)
        | _ => NONE
      fun monadOf () = case monad of SOME m => m | NONE => bug "a do with no Monad"
      fun argOf t = case C.lazyTy t of Core.TApp (_, a) => a | t' => bug ("an action of " ^ CoreText.showTy t')
      fun go (env, ss) =
        case ss of
          [A.S (_, A.SExp e)] => exp (env, want) e
        | A.S (_, A.SExp e) :: rest =>
            let
              val (m, d) = monadOf ()
              val cm = V.ty env m
              val x = exp (env, NONE) e
              val y = go (env, rest)
            in
              C.appAtoms (V.method env (V.prelude ("v", ">>"), [cm, argOf (#2 x), argOf (#2 y)], [V.dict env d]), [x, y])
            end
        | A.S (_, A.SBind (p, e)) :: rest =>
            let
              val (m, d) = monadOf ()
              val cm = V.ty env m
              val x = exp (env, NONE) e handle Untyped _ => exp (env, SOME (Core.TApp (cm, patType env p))) e
              val a = argOf (#2 x)
              val y = C.fresh "ok"
              val ok =
                C.lam ([Core.ValBinder (y, a)],
                       Mt.clauses (env, [(Core.Var y, a)], [([p], fn (env', _) => go (env', rest))],
                                   fn t => C.appAtoms (V.method env (V.prelude ("v", "fail"), [cm, argOf t], [V.dict env d]),
                                                       [V.stringLit (List.map Char.ord (explode "pattern match failure in do expression"))])))
              val b = argOf (#2 (C.app (ok, [Core.ValArg (Core.Var y)])))
            in
              C.appAtoms (V.method env (V.prelude ("v", ">>="), [cm, a, b], [V.dict env d]), [x, ok])
            end
        | A.S (_, A.SLet ds) :: rest => localBindings (env, ds, fn env' => go (env', rest))
        | [] => bug "a do whose last statement is no expression"
    in
      go (env, ss)
    end

  (* 3.11 *)
  and comprehension (env, elemWant, e, qs) =
    case qs of
      [] =>
        let
          val x = exp (env, elemWant) e
          val t = C.lazyTy (#2 x)
        in
          C.con (":", [t], [x, C.con ("[]", [t], [])])
        end
    | A.S (_, A.SExp b) :: rest =>
        let val t = comprehension (env, elemWant, e, rest)
        in C.ifBool (exp (env, SOME boolTy) b, t, C.con ("[]", [elemOf (#2 t)], [])) end
    | A.S (_, A.SLet ds) :: rest => localBindings (env, ds, fn env' => comprehension (env', elemWant, e, rest))
    | A.S (_, A.SBind (p, l)) :: rest =>
        let
          val lx = exp (env, NONE) l handle Untyped _ => exp (env, SOME (listTy (patType env p))) l
          val a = elemOf (#2 lx)
          val y = C.fresh "ok"
          val ok =
            C.lam ([Core.ValBinder (y, a)],
                   Mt.clauses (env, [(Core.Var y, a)], [([p], fn (env', _) => comprehension (env', elemWant, e, rest))],
                               fn t => C.con ("[]", [elemOf t], [])))
          val (_, okTy) = ok
          val b = elemOf (#2 (C.app (ok, [Core.ValArg (Core.Var y)])))
          val cm = V.global (V.prelude ("v", "concatMap"))
          val (ks, body) = peel (#2 cm)
          val inst =
            case V.matchType (body, List.map #1 ks, Core.TFun (okTy, Core.TFun (listTy a, listTy b))) of
              SOME tys => tys
            | NONE => bug "the Prelude's concatMap is of another type"
        in
          C.appAtoms (C.app (cm, List.map Core.TyArg inst), [ok, lx])
        end

  (* 3.15.2: C {bs}, a field not given undefined *)
  and recordCon (env, c, fs) =
    let
      val key = V.valueKey c
      val cname = V.conName key
      val {tys, ...} = V.useOf (nameSpan c)
      val ctys = List.map (V.ty env) tys
      val fts = C.fieldsAt (cname, ctys)
      val fieldKeys = V.fieldsOf key
      val values =
        ListPair.map
          (fn (fk, ft) =>
             case List.find (fn (f, _) => fk <> "" andalso V.valueKey f = fk) fs of
               SOME (_, e) => exp (env, SOME (C.lazyTy ft)) e
             | NONE => C.fail ("exn_error", "missing field in a record's construction", C.lazyTy ft))
          (fieldKeys, fts)
      val tycon = case C.conInfo cname of SOME {tycon, ...} => tycon | NONE => bug "a record's constructor"
    in
      case C.tycon tycon of
        SOME (_, C.NewS _) => C.cast (hd values, Core.apply (Core.TCon tycon, ctys))
      | _ =>
          if List.exists Core.isEval (#fields (valOf (C.conInfo cname))) then C.appAtoms (constructor (env, c), values)
          else C.con (cname, ctys, values)
    end

  (* 3.15.3: e {bs} *)
  and recordUpdate (env, a, fs) =
    let
      val x = exp (env, NONE) a
      val (tycon, tin) = case C.dataArgs (#2 x) of SOME r => r | NONE => bug "an update of no record"
    in
      case (C.unfold (#2 x), fs) of
        (* a newtype's field updated: the new value cast, since matching the
           old one forces nothing (3.15.3, rules (k), (l)) *)
        (SOME _, [(_, e)]) =>
          let
            val v = exp (env, NONE) e
            val k = case getOpt (M.find (!tyconCons, tycon), []) of k :: _ => k | [] => bug "a newtype's constructor"
            val {params, fields, ...} = valOf (C.conInfo (V.conName k))
            val names = List.map #1 params
            val inField = Core.freeTyVars (hd fields)
            val tout =
              case V.matchType (hd fields, names, C.lazyTy (#2 v)) of
                SOME ts => ListPair.map (fn ((n, u), w) => if List.exists (fn m => m = n) inField then u else w)
                                        (ListPair.zip (names, ts), tin)
              | NONE => tin
          in
            C.cast (v, Core.apply (Core.TCon tycon, tout))
          end
      | _ => recordUpdateData (env, x, tycon, tin, fs)
    end

  and recordUpdateData (env, x, tycon, tin, fs) =
    let
      val updated = List.map (fn (f, _) => V.valueKey f) fs
      val values = List.map (fn (_, e) => exp (env, NONE) e) fs
      val cons = getOpt (M.find (!tyconCons, tycon), [])
      val candidates = List.filter (fn k => List.all (fn u => List.exists (fn f => f = u) (V.fieldsOf k)) updated) cons
      val (params, _) = case C.tycon tycon of SOME p => p | NONE => bug "a record's type"
      val pnames = List.map #1 params
      (* a parameter that a field not updated has keeps its type *)
      fun keptIn k =
        let
          val {fields, ...} = valOf (C.conInfo (V.conName k))
        in
          List.concat (ListPair.map (fn (fk, ft) => if List.exists (fn u => u = fk) updated then [] else Core.freeTyVars ft)
                         (V.fieldsOf k, fields))
        end
      val kept = List.concat (List.map keptIn candidates)
      fun fromUpdates p =
        List.foldl
          (fn ((u, (_, vt)), found) =>
             case found of
               SOME t => SOME t
             | NONE =>
                 case List.find (fn k => List.exists (fn f => f = u) (V.fieldsOf k)) candidates of
                   SOME k =>
                     let
                       val {fields, ...} = valOf (C.conInfo (V.conName k))
                       val i = #2 (valOf (List.find (fn (f, _) => f = u) (ListPair.zip (V.fieldsOf k, List.tabulate (length fields, fn i => i)))))
                     in
                       case V.matchType (List.nth (fields, i), [p], C.lazyTy vt) of
                         SOME [t] => SOME t
                       | _ => NONE
                     end
                 | NONE => NONE)
          NONE (ListPair.zip (updated, values))
      val tout =
        ListPair.map (fn (p, t) => if List.exists (fn q => q = p) kept then t else getOpt (fromUpdates p, t)) (pnames, tin)
      val resultTy = Core.apply (Core.TCon tycon, tout)
    in
      C.atom (x, fn (xa, xt) =>
        C.atoms (values, fn vs =>
          C.caseCon (xa, xt,
                     List.map (fn k =>
                                 (V.conName k,
                                  fn fields =>
                                    C.con (V.conName k, tout,
                                           ListPair.map (fn (fk, (f, ft)) =>
                                                           case List.find (fn (u, _) => u = fk) (ListPair.zip (updated, vs)) of
                                                             SOME (_, (va, vt)) => (Core.Atom va, vt)
                                                           | NONE => C.var (f, ft))
                                             (V.fieldsOf k, fields))))
                       candidates,
                     SOME (C.fail ("exn_error", "Update error", resultTy)))))
    end

  (* ---- Bindings ---- *)

  (* a binding's value: a type lambda over its scheme's variables and a
     lambda over its dictionaries, the body made at its monotype *)
  and withScheme (env, r, mk : V.env * Core.ty -> C.texp) : Core.ty * C.texp =
    case r of
      SOME (E.Binding {scheme, params}) =>
        let
          val (t, ks) = V.scheme env scheme
          val env1 = V.bindTypes (env, ks)
          val dts = List.map (V.predTy env1) (#ctx scheme)
          val () = if length dts = length params then () else bug "a binding's dictionaries and its context differ"
          val env2 = ListPair.foldl (fn (p, dt, e) => V.bind (e, p, Core.Var p, dt)) env1 (params, dts)
          val mono = V.ty env1 (#ty scheme)
          val body = mk (env2, mono)
        in
          (t, C.lam (List.map Core.TyBinder ks @ ListPair.map Core.ValBinder (params, dts), body))
        end
    | SOME (E.Mono t) => let val ct = V.ty env t in (ct, mk (env, ct)) end
    | _ => bug "a binder with no record"

  (* a function's clauses: one lambda, its parameters matched (4.4.3.1) *)
  and functionBody (env, fty, clauses, what) =
    let
      val k = length (funArgs (#1 (hd clauses)))
      val (ptys, rty) = C.params (fty, k)
      val ptys = List.map C.lazyTy ptys
      val names = List.map (fn _ => C.fresh "a") ptys
      val occs = ListPair.map (fn (n, t) => (Core.Var n, t)) (names, ptys)
      val rows = List.map (fn (lhs, r) => (funArgs lhs, fn (env', fl) => rhs (env', SOME rty, r, fl))) clauses
      val m = Mt.clauses (env, occs, rows, fn t => C.fail ("exn_pattern", "no match in " ^ what, t))
    in
      C.lam (ListPair.map Core.ValBinder (names, ptys), m)
    end

  (* the definitions of a binding: each name of Core it binds, its type,
     `NONE` for the type its value has once made, and how its value is made
     in a scope; with the Haskell names it binds and what they are in
     Core *)
  and definitions (env, b, coreOf) = definitionsWith (env, b, coreOf, fn r => r)

  (* the same, a binder's record changed by `adjust` *)
  and definitionsWith (env, b, coreOf : A.name -> string, adjust : E.record option -> E.record option) =
    case b of
      FunB {name, clauses} =>
        let
          val r = adjust (V.bindOf (nameSpan name))
          val t = recordType (env, r)
          val x = coreOf name
        in
          ([(x, SOME t, fn env' => #2 (withScheme (env', r, fn (env'', mono) => functionBody (env'', mono, clauses, nameText name))))],
           [(name, x, t)])
        end
    | PatB {pat, rhs = r, ...} =>
        case simpleVar pat of
          SOME v =>
            let
              val rec_ = adjust (V.bindOf (nameSpan v))
              val t = recordType (env, rec_)
              val x = coreOf v
            in
              ([(x, SOME t, fn env' => #2 (withScheme (env', rec_, fn (env'', mono) =>
                                                         rhs (env'', SOME mono, r,
                                                              C.fail ("exn_pattern", "unmatched pattern", mono)))))],
               [(v, x, t)])
            end
        | NONE => patternBinding (env, pat, r, coreOf)

  (* a pattern binding that is not simple: the value once, and each
     variable a lazy match of the pattern against it (3.12, rule (d)); the
     variables the checker generalised, by a type lambda over the
     variables of all of them. The value's type is its right-hand side's,
     since a wildcard of the pattern says nothing of it, and is known once
     the value is made, before its variables are *)
  and patternBinding (env, pat, r, coreOf) =
    let
      val vars = Mt.variables pat
      val records = List.map (fn v => V.bindOf (nameSpan v)) vars
      val gvars =
        List.foldl (fn (E.Binding {scheme = {vars, ...}, ...}, acc) => acc @ List.filter (fn a => not (List.exists (fn b => b = a) acc)) vars
                     | (_, acc) => acc) [] (List.mapPartial (fn x => x) records)
      (* the value's name, after its first variable's: so that one of the
         top level is named the same whatever was made before it *)
      val tname = case vars of v :: _ => "%pat:" ^ coreOf v | [] => C.fresh "pat"
      val made : Core.ty option ref = ref NONE
      val value : C.texp option ref = ref NONE
      fun valueDef env' =
        case !value of
          SOME v => v
        | NONE => let val v = makeValue env' in value := SOME v; v end
      and makeValue env' =
        let
          val envG = V.bindTypes (env', List.map (fn a => (a, Core.Star)) gvars)
          val want = SOME (patType envG pat) handle Untyped _ => NONE
          val f = C.fresh "fail"
          val (body, bt) = rhs (envG, want, r, (Core.Atom (Core.Var f), C.unitTy))
          val pt = C.lazyTy bt
          val value =
            if C.mentions (f, body) then C.let_ (f, pt, C.fail ("exn_pattern", "unmatched pattern", pt), (body, bt))
            else (body, bt)
          val ks = C.inferKinds (gvars, fn _ => NONE, [pt])
        in
          made := SOME (List.foldr (fn ((a, k), t) => Core.TForall (a, k, t)) pt ks);
          C.lam (List.map Core.TyBinder ks, value)
        end
      fun varDef (v, rec_) =
        let
          val t = recordType (env, rec_)
          val x = coreOf v
          fun mk env' =
            #2 (withScheme (env', rec_, fn (env'', mono) =>
              let
                (* the value made first, where a variable is reached first *)
                val tt = case !made of
                           SOME tt => tt
                         | NONE => (ignore (valueDef env'); valOf (!made))
                val inst = List.map (fn a => V.ty env'' (T.TRigid {id = 0, name = a})) gvars
                val value = C.app (C.var (tname, tt), List.map Core.TyArg inst)
              in
                C.atom (value, fn occ =>
                  C.atom (C.fail ("exn_pattern", "irrefutable pattern failed", mono), fn (fa, ft) =>
                    Mt.pattern (env'', occ, pat,
                                fn env3 => (case V.lookup (env3, nameText v) of
                                              SOME (a, at) => (Core.Atom a, at)
                                            | NONE => bug "a pattern binding's variable"),
                                (Core.Atom fa, ft))))
              end))
        in
          ((x, SOME t, mk), (v, x, t))
        end
      val vs = ListPair.map varDef (vars, records)
    in
      ((tname, NONE, valueDef) :: List.map #1 vs, List.map #2 vs)
    end

  (* a group of local declarations (3.12, 4.5.1): by dependency, a `let`
     for each binding that names none of its group, a `letrec` for each
     group that does *)
  and localBindings (env, ds, k) =
    let
      val bs = List.filter (fn b => not (null (bindingNames b))) (collect ds)
      val byKey = List.foldl (fn (b, m) => List.foldl (fn (n, m) => M.insert (m, V.valueKey n, b)) m (bindingNames b)) M.empty bs
      fun first b = V.valueKey (hd (bindingNames b))
      val keys = List.map first bs
      fun deps key =
        case M.find (byKey, key) of
          SOME b => List.mapPartial (fn v => Option.map first (M.find (byKey, v))) (freeVars b)
        | NONE => []
      val groups = HsScc.sccs (keys, deps)
      fun bindGroup (env, g, k) =
        let
          val members = List.map (fn key => valOf (M.find (byKey, key))) g
          val recursive = length g > 1 orelse List.exists (fn d => d = hd g) (deps (hd g))
          val parts = List.map (fn b => definitions (env, b, nameText)) members
          val defs = List.concat (List.map #1 parts)
          val binds = List.concat (List.map #2 parts)
          val envB = List.foldl (fn ((n, x, t), e) => V.bind (e, nameText n, Core.Var x, t)) env binds
          (* a pattern binding's own value is a name of Core's alone *)
          val envR = if recursive then envB else env
          val body = k envB
          (* in order: a pattern binding's value before its variables *)
          fun made scope = List.map (fn (x, t, mk) => let val e = mk scope in (x, getOpt (t, C.lazyTy (#2 e)), e) end) defs
        in
          if recursive then C.letrec (made envR, body)
          else List.foldr (fn ((x, t, e), b) => C.let_ (x, t, e, b)) body (made env)
        end
      fun go ([], env) = k env
        | go (g :: gs, env) = bindGroup (env, g, fn env' => go (gs, env'))
    in
      go (groups, env)
    end

  (* ---- The program ---- *)

  fun isPrimData (name, cs) =
    null cs
    orelse (case cs of
              [A.C (_, A.CPlain (k, []))] => nameText k = "Prim" ^ nameText name
            | _ => false)

  fun primCoreName n = case n of "IOError" => "Exn" | _ => n

  (* a constructor's parts: its name, its fields' strictness and names *)
  fun constrParts (A.C (_, x)) =
    case x of
      A.CPlain (n, args) => (n, List.map #1 args, List.map (fn _ => "") args)
    | A.CInfix ((s1, _), n, (s2, _)) => (n, [s1, s2], ["", ""])
    | A.CRec (n, fs) =>
        let val each = List.concat (List.map (fn A.Field (_, vs, s, _) => List.map (fn v => (s, V.valueKey v)) vs) fs)
        in (n, List.map #1 each, List.map #2 each) end

  (* the arguments of a function's type, and its result *)
  fun arrows t =
    case T.spine t of
      (T.TCon c, [a, b]) => if c = T.arrowCon then let val (args, r) = arrows b in (a :: args, r) end else ([], t)
    | _ => ([], t)

  (* a primitive as a function of Core: its type lambda and parameters,
     applied *)
  fun primFunction (name, ty) =
    let
      val (ks, body) = peel ty
      fun params (Core.TFun (p, r)) = let val (ps, res) = params r in (p :: ps, res) end
        | params t = ([], t)
      val (ps, res) = params body
      val xs = List.map (fn _ => C.fresh "x") ps
      val call = (Core.Prim (name, List.map (Core.TVar o #1) ks, List.map Core.Var xs), res)
    in
      if null ks andalso null ps then call
      else C.lam (List.map Core.TyBinder ks @ ListPair.map Core.ValBinder (xs, ps), call)
    end

  (* a value of the type `want`, a primitive's of Core or of the runtime
     named `name`, made a function of Haskell's types; one that Core has
     not, an error where it is used *)
  fun primitive (name, want) =
    let
      fun stub why =
        let
          val () = missing := name :: !missing
          val (ks, body) = peel want
        in
          C.lam (List.map Core.TyBinder ks, C.fail ("exn_error", "rhc has no primitive " ^ name ^ why, body))
        end
    in
      (* the runtime's value first: where both have a name, the runtime's
         is the primitive made IO-shaped *)
      case C.valueType name of
        SOME t => (V.toHaskell (C.var (name, t), want) handle Fail msg => stub (": " ^ msg))
      | NONE =>
          case CorePrim.find name of
            SOME {ty, ...} => (V.toHaskell (primFunction (name, ty), want) handle Fail msg => stub (": " ^ msg))
          | NONE => stub ""
    end

  (* the type constructors a type names *)
  fun tycons (t, acc) =
    case t of
      Core.TCon c => c :: acc
    | Core.TApp (f, a) => tycons (f, tycons (a, acc))
    | Core.TFun (a, b) => tycons (a, tycons (b, acc))
    | Core.TForall (_, _, b) => tycons (b, acc)
    | Core.TEval u => tycons (u, acc)
    | Core.TUTuple ts => List.foldl tycons acc ts
    | Core.TVar _ => acc

  (* the types an expression is written with *)
  fun typesOf (e, acc) =
    case e of
      Core.Atom _ => acc
    | Core.App (f, args) => List.foldl (fn (Core.TyArg t, acc) => t :: acc | (_, acc) => acc) (typesOf (f, acc)) args
    | Core.Lam (bs, b) => List.foldl (fn (Core.ValBinder (_, t), acc) => t :: acc | (_, acc) => acc) (typesOf (b, acc)) bs
    | Core.Let (_, t, r, b) => t :: typesOf (r, typesOf (b, acc))
    | Core.LetRec (bs, b) => List.foldl (fn ((_, t, r), acc) => t :: typesOf (r, acc)) (typesOf (b, acc)) bs
    | Core.Case (s, _, alts) =>
        List.foldl (fn (Core.AltCon (_, _, b), acc) => typesOf (b, acc)
                     | (Core.AltLit (_, b), acc) => typesOf (b, acc)
                     | (Core.AltUTuple (_, b), acc) => typesOf (b, acc)
                     | (Core.AltDefault b, acc) => typesOf (b, acc)) (typesOf (s, acc)) alts
    | Core.Con (_, ts, _) => ts @ acc
    | Core.Prim (_, ts, _) => ts @ acc
    | Core.UTuple _ => acc
    | Core.Cast (b, t) => t :: typesOf (b, acc)

  (* the data types and newtypes the values name, through the fields of
     those they name, and a tuple no declaration of `types` has (3.8: of
     arbitrary length), after them *)
  fun reachableTypes (types : Core.decl list, vals : Core.decl list) =
    let
      val table = List.foldl (fn (d as Core.Data (t, _, _), m) => M.insert (m, t, d)
                               | (d as Core.Newtype (t, _, _, _), m) => M.insert (m, t, d)
                               | (_, m) => m) M.empty types
      val conOf = List.foldl (fn (Core.Data (t, _, cs), m) => List.foldl (fn ((c, _), m) => M.insert (m, c, t)) m cs
                               | (Core.Newtype (t, _, c, _), m) => M.insert (m, c, t)
                               | (_, m) => m) M.empty types
      val seen = ref M.empty
      val tuples : Core.decl list ref = ref []
      fun visit c =
        if M.member (!seen, c) then ()
        else
          (seen := M.insert (!seen, c, ());
           case M.find (table, c) of
             SOME (Core.Data (_, _, cs)) => List.app visit (List.foldl (fn ((_, fs), acc) => List.foldl tycons acc fs) [] cs)
           | SOME (Core.Newtype (_, _, _, f)) => List.app visit (tycons (f, []))
           | _ => (case C.tupleArity c of SOME n => tuples := C.tupleData n :: !tuples | NONE => ()))
      val () =
        List.app (fn Core.Val (_, t, e) =>
                       (List.app visit (List.foldl tycons [] (t :: typesOf (e, [])));
                        List.app (fn n => case M.find (conOf, n) of
                                            SOME t => visit t
                                          | NONE => if isSome (C.tupleArity n) then visit n else ())
                          (C.names e))
                   | _ => ())
          vals
    in
      List.filter (fn Core.Data (t, _, _) => M.member (!seen, t) | Core.Newtype (t, _, _, _) => M.member (!seen, t) | _ => true)
        types
      @ List.rev (!tuples)
    end

  (* what is reached from main: the values, by name, each made when it is
     first reached, in the order of `vals` *)
  fun reachable (vals : (string * Core.ty option * (unit -> C.texp)) list) =
    let
      val table = List.foldl (fn ((x, t, mk), m) => M.insert (m, x, (t, mk))) M.empty vals
      val made : Core.decl M.map ref = ref M.empty
      (* a tuple's constructor as a function, of a tuple of no declaration
         (3.8), made where it is reached *)
      val tuples : string list ref = ref []
      fun tupleFunction (x, n) =
        let
          val ps = List.tabulate (n, fn i => "a" ^ Int.toString (i + 1))
          val xs = List.tabulate (n, fn i => "%x" ^ Int.toString (i + 1))
        in
          Core.Val (x, valOf (C.valueType x),
                    Core.Lam (List.map (fn a => Core.TyBinder (a, Core.Star)) ps
                              @ ListPair.map (fn (y, a) => Core.ValBinder (y, Core.TVar a)) (xs, ps),
                              Core.Con (x, List.map Core.TVar ps, List.map Core.Var xs)))
        end
      fun visit x =
        if M.member (!made, x) then ()
        else
          case M.find (table, x) of
            SOME (t, mk) =>
              let
                val (e, et) = mk () handle Untyped what => bug ("the type of " ^ what ^ ", in " ^ x)
              in
                made := M.insert (!made, x, Core.Val (x, getOpt (t, C.lazyTy et), e));
                List.app visit (C.names e)
              end
          | NONE =>
              (case C.tupleArity x of
                 SOME n => (made := M.insert (!made, x, tupleFunction (x, n)); tuples := x :: !tuples)
               | NONE => ())
    in
      visit "main";
      List.mapPartial (fn (x, _, _) => M.find (!made, x)) vals @ List.mapPartial (fn x => M.find (!made, x)) (List.rev (!tuples))
    end

  (* ---- The program's declarations ---- *)

  (* the type constructor at the head of an instance's type, by key *)
  fun headKey (A.T (_, x)) =
    case x of
      A.TCon n => SOME (K.keyOf n)
    | A.TApp (f, _) => headKey f
    | A.TParen t => headKey t
    | A.TList _ => SOME T.listCon
    | A.TTuple ts => SOME (T.tupleCon (length ts))
    | A.TFun _ => SOME T.arrowCon
    | A.TVar _ => NONE

  fun foralls (ks, t) = List.foldr (fn ((a, k), r) => Core.TForall (a, k, r)) t ks

  fun coreKind k =
    case T.defaultKind k of
      T.KFun (a, b) => Core.Arrow (coreKind a, coreKind b)
    | _ => Core.Star

  (* the declarations of a part of the program, the library's (`first`, with
     Core's own types and the leaves') or a program's, after the library's:
     the types they declare and the values they define, in order, and, in a
     program's, main. `ownsInstance home` is whether an instance of the
     module `home` is this part's. *)
  fun part {first : bool, modules : module_ list, derived, leaves, entity, main : string option,
            ownsInstance : string -> bool} : Core.decl list * value_ list =
    let
      val derivedMethods = derived
      val decls = List.concat (List.map (fn {id, ast = A.Module (_, {decls, ...}), library} =>
                                            List.map (fn d => (id, library, d)) decls) modules)
      (* the type constructors the parts before declared *)
      val earlier = !tyconCons
      val types : Core.decl list ref = ref []
      fun emitType d = (C.declare d; types := d :: !types)
      (* each value: its name, its type and how its body is made, its names
         numbered from the first (HsDsCore.canonical), so that it is the
         same whatever was made before it *)
      val values : value_ list ref = ref []
      (* a value whose type is the one its body has once made, `NONE`, is
         known by no other's body *)
      fun valueOpt (x, t, mk) =
        (C.declare (Core.Val (x, getOpt (t, C.unitTy), Core.Atom (Core.Var x)));
         values := (x, t, fn () => let val (e, et) = mk () in (C.canonical e, et) end) :: !values)
      fun value (x, t, mk) = valueOpt (x, SOME t, mk)
      (* what raises the exceptions of a match that fails and of an error *)
      val () = if first then List.app (fn Core.Val (x, t, e) => value (x, t, fn () => (e, t)) | _ => ()) C.raisers else ()

      (* ---- Types ---- *)

      (* Core's own types, which the library declares with no constructor;
         the Prelude's Bool, Core's *)
      val () =
        List.app (fn (_, true, A.D (_, A.DData (_, name, _, cs, _))) =>
                       if isPrimData (name, cs) then V.primType (K.keyOf name, primCoreName (nameText name)) else ()
                   | _ => ())
          decls
      val world = Core.TCon "World"
      fun builtins () =
        let
          val () = V.primType (V.prelude ("t", "Bool"), "Bool")
          val () = V.builtinCon (V.prelude ("v", "True"), "True")
          val () = V.builtinCon (V.prelude ("v", "False"), "False")

          (* IO, a newtype over the state token's function (D25), so that a
             class may be at it *)
          val () = emitType (Core.Newtype ("IO", [("a", Core.Star)], "IO", Core.TFun (world, Core.TUTuple [world, Core.TVar "a"])))

          (* the unit and the list as the runtime has them, and the tuples *)
          val () = emitType (Core.Data ("()", [], [("()", [])]))
          val () = emitType (Core.Data ("[]", [("a", Core.Star)],
                                        [("[]", []), (":", [Core.TVar "a", Core.TApp (Core.TCon "[]", Core.TVar "a")])]))
          val () = V.setFields (":", ["", ""])
          val () = tyconCons := M.insert (!tyconCons, "[]", ["[]", ":"])
        in
          List.app (fn n =>
                      let
                        val name = T.tupleCon n
                        val ps = List.tabulate (n, fn i => ("a" ^ Int.toString (i + 1), Core.Star))
                      in
                        emitType (Core.Data (name, ps, [(name, List.map (Core.TVar o #1) ps)]));
                        V.setFields (name, List.tabulate (n, fn _ => ""));
                        tyconCons := M.insert (!tyconCons, name, [name])
                      end)
            (List.tabulate (14, fn i => i + 2))
        end
      val () = if first then builtins () else ()

      (* the program's data types and newtypes, their kinds worked out
         together: each type, its parameters, its constructors (key, Core
         name, fields) and whether it is a newtype *)
      val dataDecls =
        List.mapPartial
          (fn (_, _, A.D (_, x)) =>
             let
               val parts =
                 case x of
                   A.DData (_, name, vs, cs, _) => SOME (name, vs, cs, false)
                 | A.DNewtype (_, name, vs, k, _) => SOME (name, vs, [k], true)
                 | _ => NONE
             in
               case parts of
                 NONE => NONE
               | SOME (name, vs, cs, newtype) =>
                   if V.isPrimType (K.keyOf name) then NONE
                   else
                     let
                       val tname = V.tyconName (K.keyOf name)
                       val params = List.map nameText vs
                       val gens = List.map Core.TVar params
                       fun one c =
                         let
                           val (n, stricts, fields) = constrParts c
                           val key = V.valueKey n
                           val fts =
                             case V.valueScheme key of
                               SOME {ty, ...} => List.map (V.tyGen (V.empty, gens)) (#1 (arrows ty))
                             | NONE => bug ("the constructor " ^ V.coreName key ^ " has no type")
                         in
                           V.setFields (key, fields);
                           (key, V.conName key, ListPair.map (fn (s, t) => if s then Core.TEval t else t) (stricts, fts))
                         end
                       val cons = List.map one cs
                     in
                       tyconCons := M.insert (!tyconCons, tname, List.map #1 cons);
                       SOME (tname, params, cons, newtype)
                     end
             end)
          decls
      fun dataDecl (tname, cons, newtype, ks) =
        if newtype then
          case cons of
            [(_, c, [f])] => Core.Newtype (tname, ks, c, C.lazyTy f)
          | _ => bug ("the newtype " ^ tname)
        else Core.Data (tname, ks, List.map (fn (_, c, fs) => (c, fs)) cons)
      val () = List.app (fn (t, ps, cs, n) => C.declare (dataDecl (t, cs, n, List.map (fn p => (p, Core.Star)) ps))) dataDecls
      fun kindRound () =
        List.foldl
          (fn ((t, ps, cs, n), changed) =>
             let
               val ks = C.inferKinds (ps, fn _ => NONE, List.concat (List.map (fn (_, _, fs) => List.map C.lazyTy fs) cs))
               val old = case C.tycon t of SOME (p, _) => p | NONE => []
             in
               if old = ks then changed else (C.declare (dataDecl (t, cs, n, ks)); true)
             end)
          false dataDecls
      fun kinds 0 = ()
        | kinds n = if kindRound () then kinds (n - 1) else ()
      val () = kinds 20
      val () =
        List.app (fn (t, _, cs, n) => case C.tycon t of
                                         SOME (ks, _) => types := dataDecl (t, cs, n, ks) :: !types
                                       | NONE => ())
          dataDecls

      (* ---- Classes: their dictionaries' types and selectors ---- *)

      val classInfo =
        List.mapPartial (fn (_, _, A.D (_, A.DClass (_, c, _, _))) =>
                              Option.map (fn i => (K.keyOf c, i)) (HsClasses.findClass (V.classes (), K.keyOf c))
                          | _ => NONE)
          decls
      val () =
        List.app (fn (k, {kind, ...} : HsClasses.class) => C.declare (Core.Data (V.tyconName k, [("c", coreKind kind)], [])))
          classInfo
      (* a method's type in its class's dictionary: its own scheme, the
         class's variable `c` *)
      fun methodField (classKind, m) =
        case V.valueScheme m of
          SOME {vars, ctx, ty} =>
            let
              val own = List.tabulate (vars - 1, fn i => "m" ^ Int.toString (i + 1))
              val gens = List.map Core.TVar ("c" :: own)
              val dts = List.map (fn {cls, ty} => Core.TApp (Core.TCon (V.tyconName cls), V.tyGen (V.empty, gens) ty))
                          (List.drop (ctx, 1))
              val body = V.tyGen (V.empty, gens) ty
              val ks = C.inferKinds (own, fn a => if a = "c" then SOME classKind else NONE, dts @ [body])
            in
              foralls (ks, List.foldr Core.TFun body dts)
            end
        | NONE => bug ("the method " ^ V.coreName m ^ " has no type")
      val () =
        List.app (fn (k, {kind, supers, methods, ...} : HsClasses.class) =>
                    let
                      val ck = coreKind kind
                      val fields = List.map (fn s => Core.TApp (Core.TCon (V.tyconName s), Core.TVar "c")) supers
                                   @ List.map (fn m => methodField (ck, m)) methods
                    in
                      emitType (Core.Data (V.tyconName k, [("c", ck)], [(V.dictCon k, fields)]))
                    end)
          classInfo
      (* a selector: the field `index` of a dictionary of `k`, at the type
         `ty`, given the types and dictionaries of the field's own scheme *)
      fun selector (k, name, ty, index, ownDicts) =
        let
          val (ks, body) = peel ty
          val (ps, _) = C.params (body, 1 + ownDicts)
          val xs = List.map (fn _ => C.fresh "d") ps
          fun mk () =
            C.lam (List.map Core.TyBinder ks @ ListPair.map Core.ValBinder (xs, ps),
                   C.caseCon (Core.Var (hd xs), hd ps,
                              [(V.dictCon k, fn fields =>
                                               let val (f, ft) = List.nth (fields, index)
                                               in
                                                 C.appAtoms (C.app (C.var (f, ft), List.map (Core.TyArg o Core.TVar o #1) (tl ks)),
                                                             List.map C.var (tl (ListPair.zip (xs, ps))))
                                               end)],
                              NONE))
        in
          value (name, ty, mk)
        end
      val () =
        List.app
          (fn (k, {supers, methods, kind, ...} : HsClasses.class) =>
             let val dictTy = fn a => Core.TApp (Core.TCon (V.tyconName k), a)
             in
               List.app (fn (i, s) =>
                           selector (k, V.superName (k, s),
                                     Core.TForall ("g1", coreKind kind,
                                                   Core.TFun (dictTy (Core.TVar "g1"), Core.TApp (Core.TCon (V.tyconName s), Core.TVar "g1"))),
                                     i, 0))
                 (ListPair.zip (List.tabulate (length supers, fn i => i), supers));
               List.app (fn (i, m) =>
                           let val s = valOf (V.valueScheme m)
                           in selector (k, V.coreName m, V.genScheme s, length supers + i, length (#ctx s) - 1) end)
                 (ListPair.zip (List.tabulate (length methods, fn i => i), methods))
             end)
          classInfo

      (* ---- The values' types, before any body is made ---- *)

      fun topName n = V.coreName (V.valueKey n)
      val primElided = entity ("v", "PreludeBuiltin", "primElided")
      (* a binding of the library to primElided: the primitive of its name *)
      fun primBinding (library, b) =
        if not library then NONE
        else
          case b of
            PatB {pat, rhs = A.Rhs (_, A.Plain (A.E (_, A.EVar n), NONE)), ...} =>
              (case simpleVar pat of
                 SOME v => if V.valueKey n = primElided then SOME v else NONE
               | NONE => NONE)
          | _ => NONE
      val topBindings =
        List.concat (List.map (fn {id, ast = A.Module (_, {decls, ...}), library} => List.map (fn b => (library, b)) (collect decls))
                       modules)
      val () =
        List.app (fn (library, b) =>
                    case primBinding (library, b) of
                      SOME v =>
                        let val t = recordType (V.empty, V.bindOf (nameSpan v))
                        in value (topName v, t, fn () => primitive (V.nameOf (V.valueKey v), t)) end
                    | NONE => List.app (fn (x, t, mk) => valueOpt (x, t, fn () => mk V.empty)) (#1 (definitions (V.empty, b, topName))))
          topBindings
      (* a signature of the library with no binding: a primitive *)
      val bound = List.foldl (fn ((_, b), m) => List.foldl (fn (n, m) => M.insert (m, V.valueKey n, ())) m (bindingNames b))
                    M.empty topBindings
      val () =
        List.app (fn (_, true, A.D (_, A.DSig (vs, _, _))) =>
                       List.app (fn v =>
                                   let val key = V.valueKey v
                                   in
                                     if M.member (bound, key) then ()
                                     else
                                       case V.valueScheme key of
                                         SOME s => let val t = V.genScheme s in value (V.coreName key, t, fn () => primitive (V.nameOf key, t)) end
                                       | NONE => ()
                                   end) vs
                   | _ => ())
          decls
      (* the leaves' values, of their own types as Haskell sees them *)
      val () =
        List.app (fn (id, names) =>
                    List.app (fn n =>
                                let
                                  val key = Mo.key {space = Mo.Value, home = id, name = n}
                                  val t =
                                    case CorePrim.find n of
                                      SOME {ty, ...} => V.haskellForm ty
                                    | NONE => (case C.valueType n of
                                                 SOME ct => V.haskellForm ct
                                               | NONE => Core.TForall ("a", Core.Star, Core.TVar "a"))
                                in
                                  leafKeys := M.insert (!leafKeys, key, ());
                                  value (V.coreName key, t, fn () => primitive (n, t))
                                end)
                      names)
          leaves
      (* the classes' default methods: a default's record has its class's
         dictionary first among its parameters, which its context does not
         name; it is named here *)
      val defaultBindings =
        List.concat (List.map (fn (_, _, A.D (_, A.DClass (_, c, _, SOME body))) => List.map (fn b => (K.keyOf c, b)) (collect body)
                                | _ => [])
                       decls)
      val () =
        List.app (fn (cls, b) =>
                    let
                      fun withClass r =
                        case r of
                          SOME (E.Binding {scheme = {vars = cv :: own, ctx, ty}, params}) =>
                            if length params = length ctx + 1 then
                              SOME (E.Binding {scheme = {vars = cv :: own, ctx = {cls = cls, ty = T.TRigid {id = 0, name = cv}} :: ctx,
                                                         ty = ty},
                                               params = params})
                            else r
                        | _ => r
                    in
                      List.app (fn n => defaults := M.insert (!defaults, V.valueKey n, ())) (bindingNames b);
                      List.app (fn (x, t, mk) => valueOpt (x, t, fn () => mk V.empty))
                        (#1 (definitionsWith (V.empty, b, fn n => V.defaultName (V.valueKey n), withClass)))
                    end)
          defaultBindings

      (* constructors as functions: a strict field forced, the last first
         (4.2.1); a newtype's a cast *)
      val () =
        List.app
          (fn k =>
             case C.conInfo k of
               SOME {tycon, params, fields = fields as _ :: _} =>
                 let
                   val ft = List.map C.lazyTy fields
                   val result = Core.apply (Core.TCon tycon, List.map (Core.TVar o #1) params)
                   val ty = foralls (params, List.foldr Core.TFun result ft)
                   val xs = List.map (fn _ => C.fresh "x") ft
                   fun body () =
                     case C.tycon tycon of
                       SOME (_, C.NewS _) => C.cast (C.var (hd xs, hd ft), result)
                     | _ =>
                         let
                           fun go ([], acc) = C.con (k, List.map (Core.TVar o #1) params, List.map C.var acc)
                             | go ((x, f, t) :: rest, acc) =
                                 if Core.isEval f then C.force (C.var (x, t), fn (v, vt) => go (rest, (v, vt) :: acc))
                                 else go (rest, (x, t) :: acc)
                           val triples = ListPair.map (fn ((x, f), t) => (x, f, t)) (ListPair.zip (xs, fields), ft)
                         in
                           go (List.rev triples, [])
                         end
                 in
                   value (k, ty, fn () => C.lam (List.map Core.TyBinder params @ ListPair.map Core.ValBinder (xs, ft), body ()))
                 end
             | _ => ())
          (* this part's data types' *)
          (List.map V.conName (List.concat (List.mapPartial (fn (t, cs) => if M.member (earlier, t) then NONE else SOME cs)
                                                              (M.listItems (!tyconCons)))))

      (* fields' selectors (3.15.1): the constructors that have the field,
         and a match that fails for the others *)
      val fieldKeys =
        List.foldl (fn (k, acc) => if k = "" orelse List.exists (fn x => x = k) acc then acc else acc @ [k]) []
          (List.concat (List.map (fn (_, _, cs, _) => List.concat (List.map (fn (key, _, _) => V.fieldsOf key) cs)) dataDecls))
      val () =
        List.app
          (fn fk =>
             case V.valueScheme fk of
               SOME s =>
                 let
                   val ty = V.genScheme s
                   val (ks, body) = peel ty
                   val (ps, _) = C.params (body, 1)
                   val r = C.fresh "r"
                   val tycon = case C.dataArgs (hd ps) of SOME (t, _) => t | NONE => bug "a field of no data type"
                   val holders = List.filter (fn k => List.exists (fn f => f = fk) (V.fieldsOf k)) (getOpt (M.find (!tyconCons, tycon), []))
                   fun index k = #2 (valOf (List.find (fn (f, _) => f = fk) (ListPair.zip (V.fieldsOf k, List.tabulate (length (V.fieldsOf k), fn i => i)))))
                   fun mk () =
                     C.lam (List.map Core.TyBinder ks @ [Core.ValBinder (r, hd ps)],
                            case C.unfold (hd ps) of
                              (* a newtype's field: a cast, which forces nothing *)
                              SOME rep => C.cast (C.var (r, hd ps), rep)
                            | NONE =>
                            C.caseCon (Core.Var r, hd ps,
                                       List.map (fn k => (V.conName k, fn fields => let val (f, t) = List.nth (fields, index k) in C.var (f, t) end))
                                         holders,
                                       SOME (C.fail ("exn_pattern", "no match in the field " ^ V.nameOf fk, C.lazyTy (#2 (C.params (body, 1)))))))
                 in
                   value (V.coreName fk, ty, mk)
                 end
             | NONE => ())
          fieldKeys

      (* ---- Instances ---- *)

      val instances = List.filter (fn (i : HsClasses.instance) => ownsInstance (#home i)) (HsClasses.instances (V.classes ()))
      (* an instance's head, its type constructor at its variables: `->` Core's
         function type *)
      fun headType (tycon, args) =
        case (tycon = T.arrowCon, args) of
          (true, [a, b]) => Core.TFun (a, b)
        | _ => Core.apply (Core.TCon (V.tyconName tycon), args)
      fun dfunType (i : HsClasses.instance) =
        let
          val names = List.tabulate (#vars i, fn j => "a" ^ Int.toString (j + 1))
          val gens = List.map Core.TVar names
          val head = headType (#tycon i, gens)
          val dts = List.map (fn {cls, ty} => Core.TApp (Core.TCon (V.tyconName cls), V.tyGen (V.empty, gens) ty)) (#ctx i)
          val result = Core.TApp (Core.TCon (V.tyconName (#cls i)), head)
          val ks = C.inferKinds (names, fn _ => NONE, dts @ [result])
        in
          foralls (ks, List.foldr Core.TFun result dts)
        end
      (* an instance's declaration: its record, whether it is written (or
         made as written, as deriving will make it, M14), and the bindings
         of its body *)
      fun instanceSource (i : HsClasses.instance) =
        let
          fun written (id, _, A.D ({span, ...}, A.DInstance (_, c, t, body))) =
                if id = #home i andalso K.keyOf c = #cls i andalso headKey t = SOME (#tycon i) then
                  SOME (V.records ("instance", span), true, collect (getOpt (body, [])))
                else NONE
            | written (id, _, A.D (_, x)) =
                let
                  val derived =
                    case x of
                      A.DData (_, name, _, _, SOME (A.Deriv (_, _, cs))) => SOME (name, cs)
                    | A.DNewtype (_, name, _, _, SOME (A.Deriv (_, _, cs))) => SOME (name, cs)
                    | _ => NONE
                in
                  case derived of
                    SOME (name, cs) =>
                      if id = #home i andalso K.keyOf name = #tycon i then
                        Option.map (fn c => case List.find (fn (_, inst, _) => inst = #id i) derivedMethods of
                                              (* the methods deriving made, desugared as a written instance's *)
                                              SOME (_, _, ds) => (V.records ("instance", nameSpan c), true, collect ds)
                                            | NONE => (V.records ("instance", nameSpan c), false, []))
                          (List.find (fn c => K.keyOf c = #cls i) cs)
                      else NONE
                  | NONE => NONE
                end
        in
          (* a written one first: deriving's, made as written, beside the
             clause that asks for it *)
          case (List.filter #2 (List.mapPartial written decls), List.mapPartial written decls) of
            ((rs, w, bs) :: _, _) => (List.find (fn E.Instance _ => true | _ => false) rs, w, bs)
          | ([], (rs, w, bs) :: _) => (List.find (fn E.Instance _ => true | _ => false) rs, w, bs)
          | ([], []) => (NONE, false, [])
        end
      val () =
        List.app
          (fn (i : HsClasses.instance) =>
             let
               val name = V.dfunName (#id i)
               val ty = dfunType i
               fun mk () =
                 let
                   val (ks, body) = peel ty
                   val (dts0, _) = C.params (body, length (#ctx i))
                   val (record, isWritten, bindings) = instanceSource i
                   val (vars, params, supers) =
                     case record of
                       SOME (E.Instance {vars, params, supers, ...}) => (vars, params, SOME supers)
                     | _ => (List.map #1 ks, List.map (fn _ => C.fresh "d") dts0, NONE)
                   val tks = ListPair.map (fn (v, (_, k)) => (v, k)) (vars, ks)
                   val subst = ListPair.map (fn ((a, _), v) => (a, Core.TVar v)) (ks, vars)
                   val dts = List.map (fn t => Core.substTy (subst, t)) dts0
                   val env1 = V.bindTypes (V.empty, tks)
                   val env2 = ListPair.foldl (fn (p, t, e) => V.bind (e, p, Core.Var p, t)) env1 (params, dts)
                   val headTy = headType (#tycon i, List.map (Core.TVar o #1) tks)
                   val dictTy = Core.TApp (Core.TCon (V.tyconName (#cls i)), headTy)
                   val {supers = superClasses, methods, ...} =
                     case HsClasses.findClass (V.classes (), #cls i) of
                       SOME c => c
                     | NONE => bug ("the class of " ^ name)
                   val fields = C.fieldsAt (V.dictCon (#cls i), [headTy])
                   val selfName = C.fresh "self"
                   val self = C.var (selfName, dictTy)
                   val selfValue = C.appAtoms (C.app (C.var (name, ty), List.map (Core.TyArg o Core.TVar o #1) tks),
                                               List.map (fn (p, t) => C.var (p, t)) (ListPair.zip (params, dts)))
                   val superValues =
                     case supers of
                       SOME ds => List.map (V.dict env2) ds
                     | NONE => List.map (fn t => C.fail ("exn_error", "no instance of a superclass", t)) (List.take (fields, length superClasses))
                   fun methodValue (m, ft) =
                     case List.find (fn b => List.exists (fn n => V.valueKey n = m) (bindingNames b)) bindings of
                       SOME b =>
                         (case #1 (definitions (env2, b, fn _ => C.fresh "m")) of
                            [(_, _, mkm)] => mkm env2
                          | _ => bug "an instance's method of a pattern")
                     | NONE =>
                         let
                           val (oks, obody) = peel ft
                           (* the field's own dictionaries, after its own types *)
                           val ownCount = length (#ctx (valOf (V.valueScheme m))) - 1
                           val (ownPs, _) = C.params (obody, ownCount)
                         in
                           if M.member (!defaults, m) andalso isSome record andalso isWritten then
                             (* the class's default, at this instance (4.3.2) *)
                             let
                               val dm = V.defaultName m
                               val dmTy = valOf (C.valueType dm)
                               val ys = List.map (fn _ => C.fresh "d") ownPs
                             in
                               C.lam (List.map Core.TyBinder oks @ ListPair.map Core.ValBinder (ys, ownPs),
                                      C.appAtoms (C.app (C.var (dm, dmTy), List.map Core.TyArg (headTy :: List.map (Core.TVar o #1) oks)),
                                                  self :: List.map C.var (ListPair.zip (ys, ownPs))))
                             end
                           else
                             C.lam (List.map Core.TyBinder oks,
                                    C.fail ("exn_error", "no method " ^ V.nameOf m ^ " in the instance " ^ HsClasses.showInstance (#id i)
                                                         ^ (if isWritten then "" else ", which deriving is to make (M14)"),
                                            obody))
                         end
                   val methodValues =
                     ListPair.map methodValue (methods, List.drop (fields, length superClasses))
                   val dict = C.con (V.dictCon (#cls i), [headTy], superValues @ methodValues)
                 in
                   C.lam (List.map Core.TyBinder tks @ ListPair.map Core.ValBinder (params, dts),
                          if C.mentions (selfName, #1 dict) then C.let_ (selfName, dictTy, selfValue, dict) else dict)
                 end
             in
               value (name, ty, mk)
             end)
          instances

      (* ---- main ---- *)

      fun mainOf main =
        let val mainName = V.coreName main
        in
          case C.valueType mainName of
            SOME mt =>
              let
                val (ks, mbody) = peel mt
                val inst = List.map (fn _ => C.unitTy) ks
                val io = C.instantiate (mt, inst)
                val t = case io of Core.TApp (Core.TCon "IO", t) => t | _ => bug ("main is of type " ^ CoreText.showTy mbody)
                val rep = Core.TFun (world, Core.TUTuple [world, t])
                val w = C.fresh "w"
              in
                value ("main", rep,
                       fn () => C.lam ([Core.ValBinder (w, world)],
                                       C.app (C.cast (C.app (C.var (mainName, mt), List.map Core.TyArg inst), rep),
                                              [Core.ValArg (Core.Var w)])))
              end
          | NONE => bug "the program has no main"
        end
      val () = Option.app mainOf main
    in
      (List.rev (!types), List.rev (!values))
    end

  (* ---- The library's part, once, and a program's ---- *)

  fun idsOf (ms : module_ list) = List.foldl (fn ({id, ...} : module_, m) => M.insert (m, id, ())) M.empty ms
  fun isLibrary (m : module_) = #library m

  (* the library's part, whose instances are those of every module but the
     program's, `others` *)
  fun libraryWith ({modules : module_ list, infer, evidence, derived, prelude, entity, runtime, leaves}, others) : library =
    let
      val () = C.reset ()
      val () = leafKeys := M.empty
      val () = tyconCons := M.empty
      val () = defaults := M.empty
      val () = missing := []
      val own = List.filter isLibrary modules
      val ids = idsOf own
      val () = V.start {infer = infer, evidence = evidence, prelude = prelude, library = fn id => M.member (ids, id),
                        entity = entity}
      val () = List.app C.declare runtime
      val (types, values) =
        part {first = true, modules = own, derived = derived, leaves = leaves, entity = entity, main = NONE,
              ownsInstance = fn h => not (M.member (others, h))}
    in
      {state = saveState (), types = types, values = List.map (fn (x, t, mk) => (x, t, once mk)) values}
    end

  fun library args = libraryWith (args, M.empty)

  fun prepare (lib : library) =
    (restoreState (#state lib);
     List.app (fn (_, _, mk) => ignore (mk ()) handle _ => ()) (#values lib);
     restoreState (#state lib))

  fun programOn (lib : library, {modules : module_ list, infer, evidence, derived, prelude, entity, main}) =
    let
      val () = restoreState (#state lib)
      val libraryIds = idsOf (List.filter isLibrary modules)
      val () = V.continue {infer = infer, evidence = evidence, prelude = prelude, library = fn id => M.member (libraryIds, id),
                           entity = entity}
      val own = List.filter (not o isLibrary) modules
      val ids = idsOf own
      val (types, values) =
        part {first = false, modules = own, derived = derived, leaves = [], entity = entity, main = SOME main,
              ownsInstance = fn h => M.member (ids, h)}
      (* ---- The bodies ---- *)
      val vals = reachable (#values lib @ values)
    in
      reachableTypes (#types lib @ types, vals) @ vals
    end

  fun program {modules : module_ list, infer, evidence, derived, prelude, entity, runtime, leaves, main} =
    let
      val lib = libraryWith ({modules = modules, infer = infer, evidence = evidence, derived = derived, prelude = prelude,
                              entity = entity, runtime = runtime, leaves = leaves},
                             idsOf (List.filter (not o isLibrary) modules))
    in
      programOn (lib, {modules = modules, infer = infer, evidence = evidence, derived = derived, prelude = prelude,
                       entity = entity, main = main})
    end

  fun missingPrimitives () = List.rev (!missing)
end
