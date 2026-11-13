(* Implements: HS_RENAME *)
structure HsRename :> HS_RENAME =
struct
  structure A = HsAst
  structure M = HsStringMap
  structure Mo = HsModules

  type fixity = A.fixity * int
  type renamed = {module : A.module, localFixities : fixity M.map, errors : (HsSource.span * string) list}

  (* ---- the state of a renaming ---- *)

  val errors : (HsSource.span * string) list ref = ref []
  val counter = ref 0
  val localFix : fixity M.map ref = ref M.empty
  val home = ref ""
  val theScope : Mo.scope ref = ref M.empty
  val theDefOf : (string -> Mo.def option) ref = ref (fn _ => NONE)

  fun err (span, msg) = errors := (span, msg) :: !errors

  fun fresh n = (counter := !counter + 1; n ^ "#" ^ Int.toString (!counter))

  fun nameOf (A.Name (_, {name, ...})) = name
  fun spanOf (A.Name ({span, ...}, _)) = span
  fun textOf (A.Name (_, q)) = A.nameText q

  fun builtin name = A.isSpecial {qual = "", name = name} orelse name = ":"

  (* a space as a read names it (HsUsage) *)
  fun spaceText Mo.Value = "v"
    | spaceText Mo.Type = "t"

  fun isConName name =
    size name > 0 andalso (Char.isUpper (String.sub (name, 0)) orelse String.sub (name, 0) = #":")

  fun what (space, name) =
    case space of
      Mo.Type => "the type or class"
    | Mo.Value => if isConName name then "the constructor" else "the variable"

  (* the arity of a constructor, where it is one *)
  fun arityOf (name, ent : Mo.entity option) =
    if name = "()" orelse name = "[]" then SOME 0
    else if name = ":" then SOME 2
    else if String.isPrefix "(," name then SOME (size name - 1)
    else
      case ent of
        SOME e => (case !theDefOf (Mo.key e) of SOME {sort = Mo.Con, arity, ...} => SOME arity | _ => NONE)
      | NONE => NONE

  (* ---- names ---- *)

  type env = string M.map

  (* A name in an expression, a pattern's head or a type: a local first,
     where it is an unqualified variable, then what the module's scope has. *)
  fun resolve (space, env : env, n as A.Name (a, q as {qual, name})) : A.name * Mo.entity option =
    if qual = "" andalso builtin name then (n, NONE)
    else
      case (if qual = "" andalso space = Mo.Value then M.find (env, name) else NONE) of
        SOME u => (A.Name (a, {qual = "", name = u}), NONE)
      | NONE =>
          case (HsUsage.read (HsUsage.Name {within = !home, space = spaceText space, qual = qual, name = name});
                Mo.lookup (!theScope, space, qual, name)) of
            [e] => (A.Name (a, {qual = #home e, name = #name e}), SOME e)
          | [] => (err (#span a, what (space, name) ^ " `" ^ A.nameText q ^ "` is not in scope"); (n, NONE))
          | es =>
              (err (#span a, "`" ^ A.nameText q ^ "` is ambiguous: it is " ^
                             String.concatWith " and " (List.map (fn e => Mo.moduleName (#home e) ^ "'s") es));
               (n, NONE))

  fun value (env, n) = #1 (resolve (Mo.Value, env, n))
  fun tyName n = #1 (resolve (Mo.Type, M.empty, n))

  fun qop env q =
    case q of
      A.VarOp n => A.VarOp (value (env, n))
    | A.ConOp n => A.ConOp (value (M.empty, n))

  (* a binder of the top level: its entity *)
  fun topName (A.Name (a, {name, ...})) = A.Name (a, {qual = !home, name = name})

  (* ---- types ---- *)

  fun ty (A.T (a, x)) =
    A.T (a,
      case x of
        A.TVar _ => x
      | A.TCon n => A.TCon (tyName n)
      | A.TApp (f, b) => A.TApp (ty f, ty b)
      | A.TFun (f, b) => A.TFun (ty f, ty b)
      | A.TList t => A.TList (ty t)
      | A.TTuple ts => A.TTuple (List.map ty ts)
      | A.TParen t => A.TParen (ty t))

  fun context c = Option.map ty c

  (* ---- patterns ---- *)

  (* the variables a pattern binds, in order *)
  fun binders (A.P (_, x)) =
    case x of
      A.PVar v => [v]
    | A.PCon (_, ps) => List.concat (List.map binders ps)
    | A.PRec (_, fs) => List.concat (List.map (fn (_, p) => binders p) fs)
    | A.PTuple ps => List.concat (List.map binders ps)
    | A.PList ps => List.concat (List.map binders ps)
    | A.PParen p => binders p
    | A.PAs (v, p) => v :: binders p
    | A.PLazy p => binders p
    | A.PNPlusK (v, _) => [v]
    | A.PSeq items => List.concat (List.map (fn A.PA p => binders p | A.PO _ => []) items)
    | A.PJux ps => List.concat (List.map binders ps)
    | _ => []

  (* names bound twice in one group *)
  fun linear (what, ns : A.name list) =
    let
      fun go ([], _) = ()
        | go (n :: rest, seen) =
            if M.member (seen, nameOf n) then
              (err (spanOf n, "`" ^ nameOf n ^ "` bound twice in " ^ what); go (rest, seen))
            else go (rest, M.insert (seen, nameOf n, ()))
    in
      go (ns, M.empty)
    end

  fun extend (env : env, ns : A.name list) =
    List.foldl (fn (n, e) => M.insert (e, nameOf n, fresh (nameOf n))) env ns

  fun localName env (A.Name (a, {name, ...})) =
    A.Name (a, {qual = "", name = getOpt (M.find (env, name), name)})

  fun checkArity (c, ent, given) =
    case arityOf (nameOf c, ent) of
      SOME n =>
        if n = given then ()
        else err (spanOf c, "the constructor `" ^ textOf c ^ "` takes " ^ Int.toString n ^
                            (if n = 1 then " argument" else " arguments") ^ ", but this pattern gives it " ^
                            Int.toString given)
    | NONE => ()

  fun field (env, n) = value (M.empty, n)

  (* `bind` renames a binder *)
  fun pat bind (A.P (a, x)) =
    A.P (a,
      case x of
        A.PVar v => A.PVar (bind v)
      | A.PCon (c, ps) =>
          let val (c', ent) = resolve (Mo.Value, M.empty, c)
          in checkArity (c, ent, length ps); A.PCon (c', List.map (pat bind) ps) end
      | A.PRec (c, fs) => A.PRec (value (M.empty, c), List.map (fn (f, p) => (field (M.empty, f), pat bind p)) fs)
      | A.PTuple ps => A.PTuple (List.map (pat bind) ps)
      | A.PList ps => A.PList (List.map (pat bind) ps)
      | A.PParen p => A.PParen (pat bind p)
      | A.PAs (v, p) => A.PAs (bind v, pat bind p)
      | A.PLazy p => A.PLazy (pat bind p)
      | A.PNPlusK (v, k) => A.PNPlusK (bind v, k)
      | A.PSeq items =>
          A.PSeq (List.map
            (fn A.PA p => A.PA (pat bind p)
              | A.PO (A.ConOp c) =>
                  let val (c', ent) = resolve (Mo.Value, M.empty, c)
                  in checkArity (c, ent, 2); A.PO (A.ConOp c') end
              | A.PO (A.VarOp v) => A.PO (A.VarOp (value (M.empty, v))))
            items)
      | A.PJux ps => A.PJux (List.map (pat bind) ps)
      | _ => x)

  (* patterns that bind locally, a lambda's or an alternative's *)
  fun localPats (env, what, ps) =
    let
      val bs = List.concat (List.map binders ps)
      val () = linear (what, bs)
      val env' = extend (env, bs)
    in
      (List.map (pat (localName env')) ps, env')
    end

  (* ---- expressions ---- *)

  fun exp env (A.E (a, x)) =
    A.E (a,
      case x of
        A.EVar n => A.EVar (value (env, n))
      | A.ECon n => A.ECon (value (M.empty, n))
      | A.ELit _ => x
      | A.EApp (f, b) => A.EApp (exp env f, exp env b)
      | A.ESeq items => A.ESeq (List.map (fn A.EA e => A.EA (exp env e) | A.EO q => A.EO (qop env q) | A.ENeg => A.ENeg) items)
      | A.ELam (ps, b) =>
          let val (ps', env') = localPats (env, "the patterns of a lambda", ps)
          in A.ELam (ps', exp env' b) end
      | A.ELet (ds, b) =>
          let val (ds', env') = localDecls (env, ds)
          in A.ELet (ds', exp env' b) end
      | A.EIf (c, t, e) => A.EIf (exp env c, exp env t, exp env e)
      | A.ECase (e, alts) => A.ECase (exp env e, List.map (alt env) alts)
      | A.EDo ss => A.EDo (#1 (stmts (env, ss)))
      | A.ETuple es => A.ETuple (List.map (exp env) es)
      | A.EParen e => A.EParen (exp env e)
      | A.EList es => A.EList (List.map (exp env) es)
      | A.EEnum (f, t, u) => A.EEnum (exp env f, Option.map (exp env) t, Option.map (exp env) u)
      | A.EComp (e, qs) =>
          let val (qs', env') = stmts (env, qs)
          in A.EComp (exp env' e, qs') end
      | A.ELeftSec (e, q) => A.ELeftSec (exp env e, qop env q)
      | A.ERightSec (q, e) => A.ERightSec (qop env q, exp env e)
      | A.ERecCon (c, fs) => A.ERecCon (value (M.empty, c), List.map (fn (f, e) => (field (env, f), exp env e)) fs)
      | A.ERecUpd (e, fs) => A.ERecUpd (exp env e, List.map (fn (f, e) => (field (env, f), exp env e)) fs)
      | A.ESig (e, c, t) => A.ESig (exp env e, context c, ty t))

  (* statements in order, each in the scope of those before it *)
  and stmts (env, ss) =
    let
      fun go (env, [], acc) = (List.rev acc, env)
        | go (env, A.S (a, s) :: rest, acc) =
            case s of
              A.SBind (p, e) =>
                let
                  val e' = exp env e
                  val (ps', env') = localPats (env, "a pattern", [p])
                in
                  go (env', rest, A.S (a, A.SBind (hd ps', e')) :: acc)
                end
            | A.SLet ds =>
                let val (ds', env') = localDecls (env, ds)
                in go (env', rest, A.S (a, A.SLet ds') :: acc) end
            | A.SExp e => go (env, rest, A.S (a, A.SExp (exp env e)) :: acc)
    in
      go (env, ss, [])
    end

  and alt env (A.Alt (a, p, r)) =
    let val (ps', env') = localPats (env, "a pattern", [p])
    in A.Alt (a, hd ps', rhs env' r) end

  and rhs env (A.Rhs (a, x)) =
    let
      fun wheres w =
        case w of
          NONE => (NONE, env)
        | SOME ds => let val (ds', env') = localDecls (env, ds) in (SOME ds', env') end
    in
      A.Rhs (a,
        case x of
          A.Plain (e, w) => let val (w', env') = wheres w in A.Plain (exp env' e, w') end
        | A.Guarded (gs, w) =>
            let val (w', env') = wheres w
            in A.Guarded (List.map (fn A.Guard (ga, g, e) => A.Guard (ga, exp env' g, exp env' e)) gs, w') end)
    end

  (* the arguments of an equation, and its right-hand side in their scope *)
  and equation (env, bindF : A.name -> A.name) (A.F (a, lhs), r) =
    let
      fun argsOf l =
        case l of
          A.FPrefix (_, ps) => ps
        | A.FInfix (p1, _, p2) => [p1, p2]
        | A.FParen (A.F (_, l'), ps) => argsOf l' @ ps
      val args = argsOf lhs
      val bs = List.concat (List.map binders args)
      val () = linear ("the arguments of an equation", bs)
      val env' = extend (env, bs)
      val p = pat (localName env')
      fun lhs' l =
        case l of
          A.FPrefix (f, ps) => A.FPrefix (bindF f, List.map p ps)
        | A.FInfix (p1, A.VarOp f, p2) => A.FInfix (p p1, A.VarOp (bindF f), p p2)
        | A.FInfix (p1, A.ConOp f, p2) => A.FInfix (p p1, A.ConOp (bindF f), p p2)
        | A.FParen (A.F (fa, l'), ps) => A.FParen (A.F (fa, lhs' l'), List.map p ps)
    in
      (A.F (a, lhs' lhs), rhs env' r)
    end

  (* A group of declarations, a `let`'s or a `where`'s: its binders made
     local and unique, then each declaration in their scope. *)
  and localDecls (env, ds) =
    let
      val bound = groupBinders ds
      val env' = extend (env, bound)
      val names = List.foldl (fn (n, s) => M.insert (s, nameOf n, ())) M.empty bound
      fun bindF n = localName env' n
      fun owned (n, whatFor) =
        if M.member (names, nameOf n) then localName env' n
        else (err (spanOf n, whatFor ^ " for `" ^ nameOf n ^ "`, which this group of bindings does not define"); n)
      fun one (A.D (a, x)) =
        A.D (a,
          case x of
            A.DFun (f, r) => let val (f', r') = equation (env', bindF) (f, r) in A.DFun (f', r') end
          | A.DPat (p, r) => A.DPat (pat bindF p, rhs env' r)
          | A.DSig (vs, c, t) => A.DSig (List.map (fn v => owned (v, "a type signature")) vs, context c, ty t)
          | A.DFixity (f, prec, ops) =>
              let
                val p = case prec of SOME (A.Lit (_, A.LInt (n, _))) => IntInf.toInt n | _ => 9
                fun opName (A.VarOp n) = A.VarOp (fixOwned (n, f, p))
                  | opName (A.ConOp n) = A.ConOp (fixOwned (n, f, p))
                and fixOwned (n, f, p) =
                  let val n' = owned (n, "a fixity declaration")
                  in localFix := M.insert (!localFix, nameOf n', (f, p)); n' end
              in
                A.DFixity (f, prec, List.map opName ops)
              end
          | _ => x)
    in
      checkSignatures ds;
      (List.map one ds, env')
    end

  (* The binders of a group of declarations, each once: a function's
     clauses must stand together, and no name is bound twice. *)
  and groupBinders ds =
    let
      (* the number of arguments of an equation *)
      fun argCount (A.F (_, x)) =
        case x of
          A.FPrefix (_, ps) => length ps
        | A.FInfix _ => 2
        | A.FParen (l, ps) => argCount l + length ps
      fun go ([], _, _, acc) = List.rev acc
        | go (A.D (_, x) :: rest, last, seen, acc) =
            case x of
              A.DFun (f, _) =>
                let
                  val n = funName f
                  val k = argCount f
                in
                  case last of
                    SOME (name, k') =>
                      if name = nameOf n then
                        (if k = k' then ()
                         else err (spanOf n, "the clauses of `" ^ nameOf n ^ "` have " ^ Int.toString k' ^ " and " ^
                                             Int.toString k ^ " arguments: every clause of a function has as many");
                         go (rest, last, seen, acc))
                      else fresh (n, SOME (nameOf n, k), rest, seen, acc)
                  | NONE => fresh (n, SOME (nameOf n, k), rest, seen, acc)
                end
            | A.DPat (p, _) =>
                let
                  fun bind ([], seen, acc) = (seen, acc)
                    | bind (v :: vs, seen, acc) =
                        if M.member (seen, nameOf v) then (conflict v; bind (vs, seen, acc))
                        else bind (vs, M.insert (seen, nameOf v, ()), v :: acc)
                  val (seen', acc') = bind (binders p, seen, acc)
                in
                  go (rest, NONE, seen', acc')
                end
            | _ => go (rest, NONE, seen, acc)
      and fresh (n, last, rest, seen, acc) =
        if M.member (seen, nameOf n) then (conflict n; go (rest, last, seen, acc))
        else go (rest, last, M.insert (seen, nameOf n, ()), n :: acc)
      and conflict n =
        err (spanOf n, "conflicting definitions of `" ^ nameOf n ^
                       "`: a name is bound once in a group, and the clauses of a function stand together")
    in
      go (ds, NONE, M.empty, [])
    end

  and funName (A.F (_, x)) =
    case x of
      A.FPrefix (v, _) => v
    | A.FInfix (_, A.VarOp v, _) => v
    | A.FInfix (_, A.ConOp v, _) => v
    | A.FParen (l, _) => funName l

  (* one signature and one fixity for a name in a group *)
  and checkSignatures ds =
    let
      fun go ([], _, _) = ()
        | go (A.D (_, x) :: rest, sigs, fixes) =
            case x of
              A.DSig (vs, _, _) =>
                let
                  val sigs' =
                    List.foldl (fn (v, s) =>
                                  if M.member (s, nameOf v) then
                                    (err (spanOf v, "two type signatures for `" ^ nameOf v ^ "`"); s)
                                  else M.insert (s, nameOf v, ()))
                      sigs vs
                in
                  go (rest, sigs', fixes)
                end
            | A.DFixity (_, _, ops) =>
                let
                  fun opName (A.VarOp n) = n | opName (A.ConOp n) = n
                  val fixes' =
                    List.foldl (fn (q, s) =>
                                  let val n = opName q
                                  in
                                    if M.member (s, nameOf n) then
                                      (err (spanOf n, "two fixity declarations for `" ^ nameOf n ^ "`"); s)
                                    else M.insert (s, nameOf n, ())
                                  end)
                      fixes ops
                in
                  go (rest, sigs, fixes')
                end
            | _ => go (rest, sigs, fixes)
    in
      go (ds, M.empty, M.empty)
    end

  (* ---- the top level ---- *)

  fun isDefined (space, n) = isSome (!theDefOf (Mo.key {space = space, home = !home, name = nameOf n}))

  fun topOwned (n, whatFor) =
    if isDefined (Mo.Value, n) then topName n
    else (err (spanOf n, whatFor ^ " for `" ^ nameOf n ^ "`, which the module does not define"); n)

  fun strict (b, t) = (b, ty t)

  fun constr (A.C (a, x)) =
    A.C (a,
      case x of
        A.CPlain (k, args) => A.CPlain (topName k, List.map strict args)
      | A.CInfix (l, k, r) => A.CInfix (strict l, topName k, strict r)
      | A.CRec (k, fs) => A.CRec (topName k, List.map (fn A.Field (fa, vs, b, t) => A.Field (fa, List.map topName vs, b, ty t)) fs))

  fun deriving d = Option.map (fn A.Deriv (a, p, cs) => A.Deriv (a, p, List.map tyName cs)) d

  (* the methods of a class, by its entity *)
  fun methodOf (cls : Mo.entity option, n) =
    case cls of
      NONE => n
    | SOME c =>
        let val e = {space = Mo.Value, home = #home c, name = nameOf n}
        in
          case !theDefOf (Mo.key e) of
            SOME {sort = Mo.Method, parent = SOME p, ...} =>
              if Mo.key p = Mo.key c then A.Name (let val A.Name (a, _) = n in a end, {qual = #home c, name = nameOf n})
              else (err (spanOf n, "`" ^ nameOf n ^ "` is no method of the class `" ^ #name c ^ "`"); n)
          | _ => (err (spanOf n, "`" ^ nameOf n ^ "` is no method of the class `" ^ #name c ^ "`"); n)
        end

  fun classBody (cls, ds) =
    let
      fun one (A.D (a, x)) =
        A.D (a,
          case x of
            A.DSig (vs, c, t) => A.DSig (List.map topName vs, context c, ty t)
          (* 4.3.1: a class's fixity declarations are of its methods *)
          | A.DFixity (f, p, ops) =>
              A.DFixity (f, p, List.map (fn A.VarOp n => (ignore (methodOf (cls, n)); A.VarOp (topName n))
                                          | A.ConOp n => (ignore (methodOf (cls, n)); A.ConOp (topName n))) ops)
          | A.DFun (f, r) => let val (f', r') = equation (M.empty, fn n => methodOf (cls, n)) (f, r) in A.DFun (f', r') end
          | A.DPat (p, r) => A.DPat (pat (fn n => methodOf (cls, n)) p, rhs M.empty r)
          | _ => x)
    in
      checkSignatures ds;
      List.map one ds
    end

  (* 4.3.2: an instance binds only the methods in scope, by whatever name *)
  fun inScopeMethod (cls : Mo.entity option, n) =
    (case cls of
       SOME c =>
         let val k = Mo.key {space = Mo.Value, home = #home c, name = nameOf n}
         in
           if M.foldl (fn (_, es, found) => found orelse List.exists (fn e => Mo.key e = k) es) false (!theScope) then ()
           else err (spanOf n, "the instance binds `" ^ nameOf n ^ "`, a method of the class `" ^ #name c ^
                               "` that is not in scope (4.3.2)")
         end
     | NONE => ();
     methodOf (cls, n))

  fun instanceBody (cls, ds) =
    let
      val _ = groupBinders ds
      fun one (A.D (a, x)) =
        A.D (a,
          case x of
            A.DFun (f, r) => let val (f', r') = equation (M.empty, fn n => inScopeMethod (cls, n)) (f, r) in A.DFun (f', r') end
          | A.DPat (p, r) => A.DPat (pat (fn n => inScopeMethod (cls, n)) p, rhs M.empty r)
          | _ => x)
    in
      List.map one ds
    end

  fun topDecl (A.D (a, x)) =
    A.D (a,
      case x of
        A.DSig (vs, c, t) => A.DSig (List.map (fn v => topOwned (v, "a type signature")) vs, context c, ty t)
      | A.DFixity (f, p, ops) =>
          A.DFixity (f, p, List.map (fn A.VarOp n => A.VarOp (topOwned (n, "a fixity declaration"))
                                      | A.ConOp n => A.ConOp (topOwned (n, "a fixity declaration"))) ops)
      | A.DFun (f, r) => let val (f', r') = equation (M.empty, topName) (f, r) in A.DFun (f', r') end
      | A.DPat (p, r) => A.DPat (pat topName p, rhs M.empty r)
      | A.DType (c, vs, t) => A.DType (topName c, vs, ty t)
      | A.DData (cx, c, vs, cs, d) => A.DData (context cx, topName c, vs, List.map constr cs, deriving d)
      | A.DNewtype (cx, c, vs, k, d) => A.DNewtype (context cx, topName c, vs, constr k, deriving d)
      | A.DClass (cx, c, v, body) =>
          let val cls = SOME {space = Mo.Type, home = !home, name = nameOf c}
          in A.DClass (context cx, topName c, v, Option.map (fn ds => classBody (cls, ds)) body) end
      | A.DInstance (cx, c, t, body) =>
          let val (c', cls) = resolve (Mo.Type, M.empty, c)
          in A.DInstance (context cx, c', ty t, Option.map (fn ds => instanceBody (cls, ds)) body) end
      | A.DDefault ts => A.DDefault (List.map ty ts))

  (* two top-level definitions of a name, in its space *)
  fun checkTop (decls : A.decl list) =
    let
      val vals = groupBinders decls
      val seenV = List.foldl (fn (n, s) => M.insert (s, nameOf n, ())) M.empty vals
      fun addV (s, n) =
        if M.member (s, nameOf n) then (err (spanOf n, "conflicting definitions of `" ^ nameOf n ^ "`"); s)
        else M.insert (s, nameOf n, ())
      fun conNames (A.C (_, x)) =
        case x of
          A.CPlain (k, _) => ([k], [])
        | A.CInfix (_, k, _) => ([k], [])
        | A.CRec (k, fs) => ([k], List.concat (List.map (fn A.Field (_, vs, _, _) => vs) fs))
      fun one (A.D (_, x), (sv, st)) =
        case x of
          A.DType (c, _, _) => (sv, addV (st, c))
        | A.DData (_, c, _, cs, _) => datas (sv, st, c, cs)
        | A.DNewtype (_, c, _, k, _) => datas (sv, st, c, [k])
        | A.DClass (_, c, _, body) =>
            let
              val ms = List.concat (List.map (fn A.D (_, A.DSig (vs, _, _)) => vs | _ => []) (getOpt (body, [])))
            in
              (List.foldl (fn (m, s) => addV (s, m)) sv ms, addV (st, c))
            end
        | _ => (sv, st)
      and datas (sv, st, c, cs) =
        let
          val parts = List.map conNames cs
          val ks = List.concat (List.map #1 parts)
          (* a field may stand in several constructors of its type *)
          val fs = List.foldl (fn (f, (acc, s)) => if M.member (s, nameOf f) then (acc, s) else (f :: acc, M.insert (s, nameOf f, ())))
                     ([], M.empty) (List.concat (List.map #2 parts))
        in
          (List.foldl (fn (n, s) => addV (s, n)) sv (ks @ List.rev (#1 fs)), addV (st, c))
        end
      (* 4.4.2: one fixity declaration for a name, a class's for its
         methods among them *)
      fun fixNames ds = List.concat (List.map (fn A.D (_, A.DFixity (_, _, ops)) =>
                                                    List.map (fn A.VarOp n => n | A.ConOp n => n) ops
                                                | _ => []) ds)
      val topFix = List.foldl (fn (n, s) => M.insert (s, nameOf n, ())) M.empty (fixNames decls)
      val _ =
        List.foldl
          (fn (A.D (_, A.DClass (_, _, _, SOME body)), s) =>
                List.foldl (fn (n, s) =>
                              if M.member (s, nameOf n) then (err (spanOf n, "two fixity declarations for `" ^ nameOf n ^ "`"); s)
                              else M.insert (s, nameOf n, ()))
                  s (fixNames body)
            | (_, s) => s)
          topFix decls
    in
      ignore (List.foldl one (seenV, M.empty) decls);
      checkSignatures decls
    end

  fun rename {id, scope, defOf} (A.Module (a, {name, exports, imports, decls})) : renamed =
    let
      val () = (errors := []; counter := 0; localFix := M.empty; home := id; theScope := scope; theDefOf := defOf)
      val () = checkTop decls
      val decls' = List.map topDecl decls
      val result = {module = A.Module (a, {name = name, exports = exports, imports = imports, decls = decls'}),
                    localFixities = !localFix,
                    errors = List.rev (!errors)}
    in
      errors := []; localFix := M.empty; theScope := M.empty; theDefOf := (fn _ => NONE);
      result
    end

  fun topFixities (id, A.Module (_, {decls, ...})) =
    let
      fun prec p = case p of SOME (A.Lit (_, A.LInt (n, _))) => IntInf.toInt n | _ => 9
      fun opKey (A.VarOp n) = Mo.key {space = Mo.Value, home = id, name = nameOf n}
        | opKey (A.ConOp n) = Mo.key {space = Mo.Value, home = id, name = nameOf n}
      fun one (A.D (_, x)) =
        case x of
          A.DFixity (f, p, ops) => List.map (fn q => (opKey q, (f, prec p))) ops
        | A.DClass (_, _, _, SOME body) =>
            List.concat (List.map (fn A.D (_, A.DFixity (f, p, ops)) => List.map (fn q => (opKey q, (f, prec p))) ops | _ => []) body)
        | _ => []
    in
      List.concat (List.map one decls)
    end
end
