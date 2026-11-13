(* HsLint's second inference (the haskell98 roadmap's M16, D54): a
   transliteration of Typing Haskell in Haskell (Jones 1999) over the
   renamed tree, in the form its 11.6.3 calls conformant: each declaration
   group of 4.5.1, which a signature does not cut, has its implicitly
   typed bindings inferred as one list (`tiImpls`) and its explicitly
   typed ones checked against their signatures after (`tiExpl`), and a
   restricted group's explicitly typed bindings may have no predicates.

   Where it departs from the paper, each for the Report as D32 reads it:

   - restriction is Rule 1's over the whole group, with 4.5.5's simple
     pattern binding, one variable, guards allowed, `(x)` and `~x` not
     simple (R18), not the paper's test of the implicit bindings alone;
   - a pattern binding is inferred as it stands, not by the paper's
     translation to a variable and selectors, and a signed variable of one
     is held to its signature as an explicitly typed binding is;
   - in a restricted group `split` takes every variable of the group's
     types as known, so a constrained variable one type mentions is
     deferred to the module's end (R20), where the paper's takes the
     variables common to all and defaults the others at once;
   - a variable `split` defaults is bound to its default, where the paper
     leaves it in the types it quantifies;
   - each use of a signed variable has its signature's type (R21(c)), the
     signatures of one group have contexts identical up to renaming
     (R21(b)), and defaulting keeps 4.3.4's conditions (R22), a numeric
     class being `Num` or a subclass of it and a standard one the Report's
     library's;
   - Rule 2 closes where each module is inferred, by its own `default`
     (D30): over a cycle a monomorphic variable of one module's binding is
     not fixed by another's code, and two modules whose defaults differ do
     not both constrain one variable; under `--cycle-default=scc` the
     cycle closes as one, with one `default`.

   Its substitution is held in the type variables (HsLintTypes), so the
   paper's `apply s` is `zonk`. It shares only the renamer with the
   checker (D54): its unifier, its kinds and its context reduction are
   HsLintTypes', HsLintKinds' and HsLintClasses'. A refusal is
   `HsLintTypes.Refuse`, with where and why, the why naming the
   conformance table's row where one is for it. *)
structure HsLintInfer =
struct
  structure A = HsAst
  structure T = HsLintTypes
  structure C = HsLintClasses
  structure E = HsLintEnv
  structure M = HsStringMap

  fun refuse (span, msg) = raise T.Refuse (span, msg)

  (* a refusal whose text shows types: their variables named afresh *)
  fun refuseWith (span, f) = raise T.Refuse (span, T.message f)

  fun nameOf (A.Name (_, q)) = q
  fun spanOfName (A.Name ({span, ...}, _)) = span
  (* a name as the source writes it: a local's without the renamer's `#n` *)
  fun plain ({name, ...} : T.id) =
    case CharVector.findi (fn (i, c) => c = #"#" andalso i > 0) name of
      SOME (i, _) => String.substring (name, 0, i)
    | NONE => name
  fun key n = T.idKey (nameOf n)

  (* ---- the state of an inference ---- *)

  (* the predicates of what is being inferred, which a binding group
     collects for itself (the paper's lists of predicates) *)
  val preds : T.pred list ref = ref []
  fun push ps = preds := ps @ !preds

  fun collecting f =
    let
      val saved = !preds
      val () = preds := []
      val r = f () handle e => (preds := saved; raise e)
      val ps = !preds
    in
      preds := saved; (r, ps)
    end

  (* the top level: the schemes inferred or declared so far, and the types
     of the monomorphic bindings, whose variables are fixed *)
  val tops : T.scheme M.map ref = ref M.empty
  val topMono : T.ty list ref = ref []
  (* the module whose bindings are inferred, for its defaults *)
  val current = ref ""
  val inLibrary = ref false

  (* A default the inference chose: where, the predicates and the type,
     and whether Rule 2 chose it, where the module was inferred. *)
  type default = {module : string, span : HsSource.span, preds : T.pred list, choice : T.ty, ruleTwo : bool}
  val chosen : default list ref = ref []

  (* A binding of the top level as the inference left it, and whether its
     group is restricted (Rule 1). *)
  type binding = {module : string, id : T.id, scheme : T.scheme, signed : bool, restricted : bool, span : HsSource.span}
  val bindings : binding list ref = ref []

  fun reset () = (preds := []; tops := M.empty; topMono := []; current := ""; inLibrary := false; chosen := [];
                  bindings := []; T.ruleTwo := "")

  (* What the inference of some modules leaves for the modules after them:
     the types of the top level, its monomorphic variables, the defaults
     chosen and the bindings found *)
  type saved = {tops : T.scheme M.map, topMono : T.ty list, chosen : default list, bindings : binding list}

  fun save () : saved = {tops = !tops, topMono = !topMono, chosen = !chosen, bindings = !bindings}

  fun restore (s : saved) =
    (reset (); tops := #tops s; topMono := #topMono s; chosen := #chosen s; bindings := #bindings s)

  (* an environment of locals: their schemes, and the types of those that
     are monomorphic, whose variables are fixed (`tv (apply s as)`) *)
  type env = {vals : T.scheme M.map, mono : T.ty list}

  val empty : env = {vals = M.empty, mono = []}

  fun extend ({vals, mono} : env, binds : (string * T.scheme) list) : env =
    {vals = List.foldl (fn ((k, sc), m) => M.insert (m, k, sc)) vals binds,
     mono = List.foldl (fn ((_, sc), acc) => List.map T.TVar (T.schemeTvs sc) @ acc) mono binds}

  fun extendMono (env : env, binds : (string * T.ty) list) =
    extend (env, List.map (fn (k, t) => (k, T.toScheme t)) binds)

  fun fixedVars ({mono, ...} : env) = T.tvsList (List.map T.zonk (mono @ !topMono))

  fun unify (span, what, a, b) =
    T.unify (a, b)
    handle T.Unify why =>
      refuseWith (span, fn () => what ^ ": " ^ T.showTy (T.zonk a) ^ " against " ^ T.showTy (T.zonk b) ^ " (" ^ why ^ ")")

  fun instantiate sc = let val (ps, t) = T.freshInst sc in push ps; t end

  fun member (v, vs) = List.exists (fn w => T.tvEq (v, w)) vs
  fun minus (vs, ws) = List.filter (fn v => not (member (v, ws))) vs
  fun union vss = List.foldl (fn (vs, acc) => acc @ minus (vs, acc)) [] vss
  fun intersect [] = []
    | intersect (vs :: vss) = List.filter (fn v => List.all (fn ws => member (v, ws)) vss) vs

  (* ---- the Prelude's types and classes, which the translations name ---- *)

  fun cls name = E.preludeId name
  fun tBool () = E.preludeTy "Bool"
  fun tChar () = E.preludeTy "Char"

  (* ---- names ---- *)

  (* a variable's scheme: a local's, the top level's, a method's, a
     field's; a primitive of rhc's library, which has no binding to give it
     a type, or a name the library leaves unresolved (until M17's overlay),
     is `forall a. a` *)
  val anything = T.Forall ([T.Star], ([], T.TGen 0))

  fun lookup (env : env, n as A.Name ({span, ...}, q)) : T.scheme =
    let val k = T.idKey q
    in
      case M.find (#vals env, k) of
        SOME sc => sc
      | NONE =>
          case M.find (!tops, k) of
            SOME sc => sc
          | NONE =>
              case M.find (!E.methods, k) of
                SOME {scheme, ...} => scheme
              | NONE =>
                  case M.find (!E.fields, k) of
                    SOME {scheme, ...} => scheme
                  | NONE =>
                      if #qual q <> "" andalso not (M.member (!E.programModules, #qual q)) then anything
                      else if !inLibrary then anything
                      else refuse (span, "hslint has no type for `" ^ A.nameText q ^ "`")
    end

  (* a constructor's instance: its arguments, its result and its context,
     at fresh variables for its type's parameters *)
  (* a constructor the library names and does not define, until M17's
     overlay: its arguments are what they are given *)
  val unknown = {args = [], result = T.TGen ~1, con = NONE}

  fun conInst (A.Name ({span, ...}, q)) : {args : T.ty list, result : T.ty, con : E.con option} =
    case (#qual q, #name q) of
      ("", "()") => {args = [], result = T.tUnit, con = NONE}
    | ("", "[]") => {args = [], result = T.list (T.newTVar T.Star), con = NONE}
    | ("", ":") => let val a = T.newTVar T.Star in {args = [a, T.list a], result = T.list a, con = NONE} end
    | ("", n) =>
        if String.isPrefix "(," n then
          let val ts = List.tabulate (size n - 1, fn _ => T.newTVar T.Star)
          in {args = ts, result = T.tuple ts, con = NONE} end
        else if !inLibrary then unknown
        else refuse (span, "`" ^ n ^ "` is not a constructor")
    | _ =>
        case M.find (!E.cons, T.idKey q) of
          SOME (c as {tycon, args, context, ...}) =>
            let
              val kind = getOpt (E.tyconKind tycon, T.Star)
              val vs = Vector.fromList (List.map T.newTVar (E.argKinds kind))
              val result = Vector.foldl (fn (v, f) => T.TAp (f, v)) (T.TCon {id = tycon, kind = kind}) vs
            in
              push (List.map (T.instPred vs) context);
              {args = List.map (T.inst vs) args, result = result, con = SOME c}
            end
        | NONE =>
            if !inLibrary orelse not (M.member (!E.programModules, #qual q)) then unknown
            else refuse (span, "hslint has no constructor `" ^ A.nameText q ^ "`")

  fun conType n =
    case conInst n of
      {result = T.TGen ~1, ...} => T.newTVar T.Star
    | {args, result, ...} => T.fnMany (args, result)

  (* ---- literals ---- *)

  fun tiLit (A.Lit (_, l)) =
    case l of
      A.LInt _ => let val a = T.newTVar T.Star in push [T.IsIn (cls "Num", a)]; a end
    | A.LFloat _ => let val a = T.newTVar T.Star in push [T.IsIn (cls "Fractional", a)]; a end
    | A.LChar _ => tChar ()
    | A.LString _ => T.list (tChar ())

  (* ---- patterns (11.2) ---- *)

  fun tiPat (A.P ({span, ...}, x)) : (string * T.ty) list * T.ty =
    case x of
      A.PVar n => let val t = T.newTVar T.Star in ([(key n, t)], t) end
    | A.PWild => ([], T.newTVar T.Star)
    | A.PLit l => ([], tiLit l)
    | A.PNegLit l => ([], tiLit l)
    | A.PCon (c, ps) => conPat (span, c, ps)
    | A.PRec (c, fps) =>
        let
          val {args, result, con} =
            case conInst c of {result = T.TGen ~1, ...} => {args = [], result = T.newTVar T.Star, con = NONE} | r => r
          val fs = case con of SOME {fields, ...} => fields | NONE => []
          fun position (f, i, []) =
                refuse (spanOfName f, "the field `" ^ #name (nameOf f) ^ "` is not one of the constructor's " ^
                                      "(pat.m.label.declared)")
            | position (f, i, SOME g :: rest) = if T.idEq (nameOf f, g) then i else position (f, i + 1, rest)
            | position (f, i, NONE :: rest) = position (f, i + 1, rest)
          fun go ([], _, binds) = binds
            | go ((f, p) :: rest, seen, binds) =
                let
                  val i = position (f, 0, fs)
                  val () = if List.exists (fn j => j = i) seen then
                             refuse (spanOfName f, "the field `" ^ #name (nameOf f) ^ "` twice in a pattern " ^
                                                   "(pat.m.label.twice)")
                           else ()
                  val (bs, t) = tiPat p
                in
                  unify (A.spanOfPat p, "a field's pattern", t, List.nth (args, i));
                  go (rest, i :: seen, binds @ bs)
                end
        in
          (go (fps, [], []), result)
        end
    | A.PTuple ps =>
        let val (bss, ts) = ListPair.unzip (List.map tiPat ps)
        in (List.concat bss, T.tuple ts) end
    | A.PList ps =>
        let
          val a = T.newTVar T.Star
          val bss = List.map (fn p => let val (bs, t) = tiPat p in unify (A.spanOfPat p, "an element of a list pattern", t, a); bs end) ps
        in
          (List.concat bss, T.list a)
        end
    | A.PParen p => tiPat p
    | A.PAs (n, p) => let val (bs, t) = tiPat p in ((key n, t) :: bs, t) end
    | A.PLazy p => tiPat p
    | A.PNPlusK (n, _) =>
        let val a = T.newTVar T.Star in push [T.IsIn (cls "Integral", a)]; ([(key n, a)], a) end
    | A.PSeq [A.PA l, A.PO (A.ConOp c), A.PA r] => conPat (span, c, [l, r])
    | _ => refuse (span, "hslint: a pattern of a form it does not know")

  and conPat (span, c, ps) =
    let
      val {args, result, ...} =
        case conInst c of
          {result = T.TGen ~1, ...} => {args = List.map (fn _ => T.newTVar T.Star) ps, result = T.newTVar T.Star, con = NONE}
        | r => r
      val () = if length args = length ps then ()
               else refuse (span, "the constructor `" ^ #name (nameOf c) ^ "` takes " ^ Int.toString (length args) ^
                                  " arguments (pat.con.arity)")
      val bss = ListPair.map (fn (p, a) => let val (bs, t) = tiPat p in unify (A.spanOfPat p, "a constructor's argument", t, a); bs end)
                  (ps, args)
    in
      (List.concat bss, result)
    end

  fun tiPats ps = let val (bss, ts) = ListPair.unzip (List.map tiPat ps) in (List.concat bss, ts) end

  (* ---- the bindings of a declaration list ---- *)

  datatype bind =
      Fun of {id : T.id, clauses : (A.pat list * A.rhs) list, span : HsSource.span}
    | Pat of {pat : A.pat, rhs : A.rhs, vars : T.id list, simple : bool, span : HsSource.span}

  fun binders (A.P (_, x)) =
    case x of
      A.PVar n => [nameOf n]
    | A.PCon (_, ps) => List.concat (List.map binders ps)
    | A.PRec (_, fs) => List.concat (List.map (fn (_, p) => binders p) fs)
    | A.PTuple ps => List.concat (List.map binders ps)
    | A.PList ps => List.concat (List.map binders ps)
    | A.PParen p => binders p
    | A.PAs (n, p) => nameOf n :: binders p
    | A.PLazy p => binders p
    | A.PNPlusK (n, _) => [nameOf n]
    | A.PSeq items => List.concat (List.map (fn A.PA p => binders p | A.PO _ => []) items)
    | _ => []

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

  fun bindsOf (decls : A.decl list) : bind list =
    let
      fun go ([], acc) = List.rev acc
        | go (A.D ({span, ...}, x) :: rest, acc) =
            case x of
              A.DFun (f, r) =>
                let val id = nameOf (funName f)
                in
                  case acc of
                    Fun {id = id', clauses, span = sp} :: acc' =>
                      if T.idEq (id, id') then go (rest, Fun {id = id, clauses = clauses @ [(funArgs f, r)], span = sp} :: acc')
                      else go (rest, Fun {id = id, clauses = [(funArgs f, r)], span = span} :: acc)
                  | _ => go (rest, Fun {id = id, clauses = [(funArgs f, r)], span = span} :: acc)
                end
            | A.DPat (p as A.P (_, px), r) =>
                let
                  val simple = case px of A.PVar _ => true | _ => false
                in
                  go (rest, Pat {pat = p, rhs = r, vars = binders p, simple = simple, span = span} :: acc)
                end
            | _ => go (rest, acc)
    in
      go (decls, [])
    end

  fun bound (Fun {id, ...}) = [id]
    | bound (Pat {vars, ...}) = vars

  fun bindSpan (Fun {span, ...}) = span
    | bindSpan (Pat {span, ...}) = span

  (* the signatures of a declaration list, by the key of the name *)
  fun sigsOf (decls : A.decl list) =
    List.foldl (fn (A.D ({span, ...}, A.DSig (vs, cx, t)), m) =>
                     let val sc = E.sigScheme {context = cx, ty = t, span = span}
                     in List.foldl (fn (v, m) => M.insert (m, key v, (sc, span))) m vs end
                 | (_, m) => m)
      M.empty decls

  (* ---- free variables, for the dependency analysis (4.5.1) ---- *)

  fun fvExp (A.E (_, x), acc) =
    case x of
      A.EVar n => key n :: acc
    | A.ECon _ => acc
    | A.ELit _ => acc
    | A.EApp (f, a) => fvExp (a, fvExp (f, acc))
    | A.ESeq items => List.foldl (fn (A.EA e, acc) => fvExp (e, acc) | (A.EO (A.VarOp n), acc) => key n :: acc | (_, acc) => acc)
                        acc items
    | A.ELam (_, b) => fvExp (b, acc)
    | A.ELet (ds, b) => fvExp (b, fvDecls (ds, acc))
    | A.EIf (a, b, c) => fvExp (c, fvExp (b, fvExp (a, acc)))
    | A.ECase (e, alts) => List.foldl (fn (A.Alt (_, _, r), acc) => fvRhs (r, acc)) (fvExp (e, acc)) alts
    | A.EDo ss => fvStmts (ss, acc)
    | A.ETuple es => List.foldl fvExp acc es
    | A.EParen e => fvExp (e, acc)
    | A.EList es => List.foldl fvExp acc es
    | A.EEnum (a, b, c) =>
        List.foldl fvExp (fvExp (a, acc)) (List.mapPartial (fn x => x) [b, c])
    | A.EComp (e, ss) => fvExp (e, fvStmts (ss, acc))
    | A.ELeftSec (e, q) => fvExp (e, fvOp (q, acc))
    | A.ERightSec (q, e) => fvExp (e, fvOp (q, acc))
    | A.ERecCon (_, fs) => List.foldl (fn ((_, e), acc) => fvExp (e, acc)) acc fs
    | A.ERecUpd (e, fs) => List.foldl (fn ((_, e), acc) => fvExp (e, acc)) (fvExp (e, acc)) fs
    | A.ESig (e, _, _) => fvExp (e, acc)
  and fvOp (A.VarOp n, acc) = key n :: acc
    | fvOp (A.ConOp _, acc) = acc
  and fvStmts (ss, acc) =
    List.foldl (fn (A.S (_, s), acc) =>
                  case s of
                    A.SBind (_, e) => fvExp (e, acc)
                  | A.SLet ds => fvDecls (ds, acc)
                  | A.SExp e => fvExp (e, acc))
      acc ss
  and fvRhs (A.Rhs (_, x), acc) =
    case x of
      A.Plain (e, w) => fvExp (e, case w of SOME ds => fvDecls (ds, acc) | NONE => acc)
    | A.Guarded (gs, w) =>
        List.foldl (fn (A.Guard (_, g, e), acc) => fvExp (e, fvExp (g, acc)))
          (case w of SOME ds => fvDecls (ds, acc) | NONE => acc) gs
  and fvDecls (ds, acc) =
    List.foldl (fn (A.D (_, x), acc) =>
                  case x of
                    A.DFun (_, r) => fvRhs (r, acc)
                  | A.DPat (_, r) => fvRhs (r, acc)
                  | _ => acc)
      acc ds

  fun fvBind (Fun {clauses, ...}) = List.foldl (fn ((_, r), acc) => fvRhs (r, acc)) [] clauses
    | fvBind (Pat {rhs, ...}) = fvRhs (rhs, [])

  (* the declaration groups of a list of bindings, dependencies first *)
  fun groupsOf (bs : bind list) : bind list list =
    let
      val v = Vector.fromList bs
      val owner = Vector.foldli (fn (i, b, m) => List.foldl (fn (id, m) => M.insert (m, T.idKey id, i)) m (bound b)) M.empty v
      val succs = Vector.map (fn b => List.mapPartial (fn k => M.find (owner, k)) (fvBind b)) v
    in
      List.map (List.map (fn i => Vector.sub (v, i))) (HsLintScc.groups (Vector.length v, fn i => Vector.sub (succs, i)))
    end

  (* ---- expressions (11.3) ---- *)

  fun tiExp (env : env) (A.E ({span, ...}, x)) : T.ty =
    case x of
      A.EVar n => instantiate (lookup (env, n))
    | A.ECon n => conType n
    | A.ELit l => tiLit l
    | A.EApp (f, a) =>
        let
          val tf = tiExp env f
          val ta = tiExp env a
          val r = T.newTVar T.Star
        in
          unify (span, "an application", tf, T.fn_ (ta, r)); r
        end
    | A.ESeq [A.EA l, A.EO q, A.EA r] =>
        let
          val top = opType (env, q)
          val tl = tiExp env l
          val tr = tiExp env r
          val res = T.newTVar T.Star
        in
          unify (span, "an operator's operands", top, T.fn_ (tl, T.fn_ (tr, res))); res
        end
    | A.ESeq [A.ENeg, A.EA e] =>
        let val t = tiExp env e in push [T.IsIn (cls "Num", t)]; t end
    | A.ESeq _ => refuse (span, "hslint: a sequence of operators fixity did not resolve")
    | A.ELam (ps, b) =>
        let
          val (binds, ts) = tiPats ps
          val r = tiExp (extendMono (env, binds)) b
        in
          T.fnMany (ts, r)
        end
    | A.ELet (ds, b) => tiExp (tiDecls (env, ds)) b
    | A.EIf (c, t, e) =>
        let
          val () = unify (A.spanOfExp c, "a condition (exp.if.type.cond)", tiExp env c, tBool ())
          val tt = tiExp env t
        in
          unify (A.spanOfExp e, "the branches of `if` (exp.if.type.branches)", tiExp env e, tt); tt
        end
    | A.ECase (e, alts) =>
        let
          val te = tiExp env e
          val r = T.newTVar T.Star
        in
          List.app (fn A.Alt ({span = sp, ...}, p, rhs) =>
                      let
                        val (binds, tp) = tiPat p
                        val () = unify (A.spanOfPat p, "a pattern of `case` (exp.case.type.pats)", tp, te)
                      in
                        unify (sp, "the bodies of `case` (exp.case.type.bodies)", tiRhs (extendMono (env, binds), rhs), r)
                      end)
            alts;
          r
        end
    | A.EDo ss =>
        (* by its translation (3.14): `do {e} = e`, `do {e; ss} = e >> do {ss}`,
           `do {p <- e; ss} = e >>= \p -> do {ss}` (with `fail`), and
           `do {let ds; ss} = let ds in do {ss}` *)
        let
          fun go (env, []) = refuse (span, "a `do` with no statement")
            | go (env, [A.S (_, A.SExp e)]) = tiExp env e
            | go (env, [A.S ({span = sp, ...}, _)]) = refuse (sp, "the last statement of `do` is an expression")
            | go (env, A.S (_, s) :: rest) =
                case s of
                  A.SExp e => monadicIn (env, e, T.newTVar T.Star, fn () => go (env, rest))
                | A.SBind (p, e) =>
                    let val (binds, tp) = tiPat p
                    in monadicIn (env, e, tp, fn () => go (extendMono (env, binds), rest)) end
                | A.SLet ds => go (tiDecls (env, ds), rest)
          and monadicIn (env, e, ta, rest) =
            let
              val m = T.newTVar (T.KFun (T.Star, T.Star))
              val () = push [T.IsIn (cls "Monad", m)]
              val () = unify (A.spanOfExp e, "a statement of `do` (exp.do.methods)", tiExp env e, T.TAp (m, ta))
              val r = rest ()
            in
              unify (span, "the rest of `do` (exp.do.methods)", r, T.TAp (m, T.newTVar T.Star)); r
            end
        in
          go (env, ss)
        end
    | A.ETuple es => T.tuple (List.map (tiExp env) es)
    | A.EParen e => tiExp env e
    | A.EList es =>
        let val a = T.newTVar T.Star
        in
          List.app (fn e => unify (A.spanOfExp e, "an element of a list (exp.list.type.same)", tiExp env e, a)) es;
          T.list a
        end
    | A.EEnum (f, t, u) =>
        let
          val a = tiExp env f
          val () = List.app (fn e => unify (A.spanOfExp e, "a bound of an arithmetic sequence (exp.seq.type)", tiExp env e, a))
                     (List.mapPartial (fn x => x) [t, u])
        in
          push [T.IsIn (cls "Enum", a)]; T.list a
        end
    | A.EComp (e, quals) =>
        let
          fun go (env, []) = env
            | go (env, A.S (_, s) :: rest) =
                case s of
                  A.SBind (p, g) =>
                    let
                      val tg = tiExp env g
                      val (binds, tp) = tiPat p
                    in
                      unify (A.spanOfExp g, "a generator (exp.comp.gen.type)", tg, T.list tp);
                      go (extendMono (env, binds), rest)
                    end
                | A.SLet ds => go (tiDecls (env, ds), rest)
                | A.SExp g => (unify (A.spanOfExp g, "a guard (exp.comp.guard.type)", tiExp env g, tBool ()); go (env, rest))
        in
          T.list (tiExp (go (env, quals)) e)
        end
    | A.ELeftSec (e, q) =>
        let
          val top = opType (env, q)
          val te = tiExp env e
          val b = T.newTVar T.Star
          val c = T.newTVar T.Star
        in
          unify (span, "a section", top, T.fn_ (te, T.fn_ (b, c))); T.fn_ (b, c)
        end
    | A.ERightSec (q, e) =>
        let
          val top = opType (env, q)
          val te = tiExp env e
          val a = T.newTVar T.Star
          val c = T.newTVar T.Star
        in
          unify (span, "a section", top, T.fn_ (a, T.fn_ (te, c))); T.fn_ (a, c)
        end
    | A.ERecCon (c, fes) =>
        let
          val {args, result, con} =
            case conInst c of {result = T.TGen ~1, ...} => {args = [], result = T.newTVar T.Star, con = NONE} | r => r
          val (fs, strict) = case con of SOME {fields, strict, ...} => (fields, strict) | NONE => ([], [])
          fun position (f, i, []) =
                refuse (spanOfName f, "the field `" ^ #name (nameOf f) ^ "` is not one of the constructor's " ^
                                      "(exp.field.con.notown)")
            | position (f, i, SOME g :: rest) = if T.idEq (nameOf f, g) then i else position (f, i + 1, rest)
            | position (f, i, NONE :: rest) = position (f, i + 1, rest)
          val given =
            List.foldl (fn ((f, e), seen) =>
                          let val i = position (f, 0, fs)
                          in
                            if List.exists (fn j => j = i) seen then
                              refuse (spanOfName f, "the field `" ^ #name (nameOf f) ^ "` given twice (exp.field.con.twice)")
                            else ();
                            unify (A.spanOfExp e, "a field's value", tiExp env e, List.nth (args, i));
                            i :: seen
                          end)
              [] fes
          val () =
            ListPair.app (fn (i, s) => if s andalso not (List.exists (fn j => j = i) given) then
                                         refuse (span, "a strict field is left out of a construction (exp.field.con.strict)")
                                       else ())
              (List.tabulate (length strict, fn i => i), strict)
        in
          result
        end
    | A.ERecUpd (e, fes) => recUpd (env, span, e, fes)
    | A.ESig (e, cx, t) =>
        let
          val sc = E.sigScheme {context = cx, ty = t, span = span}
          val () = push (checkExpl (env, sc, false, span, "the expression", fn t => unify (span, "the expression", tiExp env e, t)))
        in
          instantiate sc
        end

  and opType (env, A.VarOp n) = instantiate (lookup (env, n))
    | opType (env, A.ConOp n) = conType n

  (* e { f1 = e1, ... } by its translation (3.15.3): the constructors that
     have every field, each taken apart and made again *)
  and recUpd (env, span, e, fes) =
    let
      val infos = List.map (fn (f, _) =>
                              case M.find (!E.fields, key f) of
                                SOME r => r
                              | NONE => refuse (spanOfName f, "`" ^ #name (nameOf f) ^ "` is not a field"))
                    fes
      val tycon = #tycon (hd infos)
      val () = List.app (fn {tycon = t, ...} => if T.idEq (t, tycon) then ()
                                                else refuse (span, "the fields of an update are of one type (exp.field.upd.onetype)"))
                 infos
      val () = ignore (List.foldl (fn ((f, _), seen) =>
                                     if List.exists (fn g => T.idEq (g, nameOf f)) seen then
                                       refuse (spanOfName f, "a field twice in an update (exp.field.upd.twice)")
                                     else nameOf f :: seen)
                         [] fes)
      val consAll =
        List.filter (fn k => List.all (fn {cons, ...} => List.exists (fn (k', _) => T.idEq (k, k')) cons) infos)
          (List.map #1 (#cons (hd infos)))
      val () = if null consAll then refuse (span, "no constructor has every field of the update (exp.field.upd.onecon)") else ()
      val kind = getOpt (E.tyconKind tycon, T.Star)
      val ks = E.argKinds kind
      val va = Vector.fromList (List.map T.newTVar ks)
      val vb = Vector.fromList (List.map T.newTVar ks)
      fun tyOf vs = Vector.foldl (fn (v, f) => T.TAp (f, v)) (T.TCon {id = tycon, kind = kind}) vs
      val vals = List.map (fn (f, x) => (nameOf f, tiExp env x, A.spanOfExp x)) fes
      fun one k =
        let
          val c = valOf (M.find (!E.cons, T.idKey k))
          fun ctx vs = List.map (T.instPred vs) (#context c)
        in
          push (ctx va @ ctx vb);
          ListPair.app (fn (fo, arg) =>
                          case fo of
                            SOME f =>
                              (case List.find (fn (g, _, _) => T.idEq (f, g)) vals of
                                 SOME (_, t, sp) => unify (sp, "a field's new value", t, T.inst vb arg)
                               | NONE => T.unify (T.inst va arg, T.inst vb arg))
                          | NONE => T.unify (T.inst va arg, T.inst vb arg))
            (#fields c, #args c)
        end
    in
      List.app one consAll;
      unify (A.spanOfExp e, "the record updated", tiExp env e, tyOf va);
      tyOf vb
    end

  and tiRhs (env, A.Rhs (_, x)) =
    case x of
      A.Plain (e, w) => tiExp (case w of SOME ds => tiDecls (env, ds) | NONE => env) e
    | A.Guarded (gs, w) =>
        let
          val env' = case w of SOME ds => tiDecls (env, ds) | NONE => env
          val r = T.newTVar T.Star
        in
          List.app (fn A.Guard (_, g, e) =>
                      (unify (A.spanOfExp g, "a guard", tiExp env' g, tBool ());
                       unify (A.spanOfExp e, "the bodies of a guarded right-hand side", tiExp env' e, r)))
            gs;
          r
        end

  (* the clauses of a function, at the type `t` (tiAlts) *)
  and tiClauses (env, clauses, t, span) =
    List.app (fn (ps, rhs) =>
                let
                  val (binds, ts) = tiPats ps
                  val r = tiRhs (extendMono (env, binds), rhs)
                in
                  unify (span, "a clause", T.fnMany (ts, r), t)
                end)
      clauses

  (* ---- binding groups (11.6) ---- *)

  (* `checkExpl (env, sc, restricted, span, what, body)`: tiExpl, where
     `body t` infers the binding at the type `t`; the deferred predicates *)
  and checkExpl (env, sc as T.Forall (_, (qs0, _)), restricted, span, what, body) =
    let
      val () =
        if restricted andalso not (null qs0) then
          refuse (span, what ^ " has a signature with a context in a restricted group: Rule 1 lets no constrained type " ^
                        "variable of the group be generalized (mr.rule1.constrained, mr.ex.nonsimple.sig)")
        else ()
      val (qs, t) = T.freshInst sc
      val ((), ps) = collecting (fn () => body t)
      val qs' = List.map T.zonkPred qs
      val t' = T.zonk t
      val fs = fixedVars env
      val gs = minus (T.tvs t', fs)
      val sc' = T.quantify (gs, (qs', t'))
      val ps' = List.filter (not o C.entail qs') (List.map T.zonkPred ps)
      val (ds, rs, defs) = split (span, fs, gs, ps')
    in
      if not (T.schemeEq (sc, sc')) then
        refuseWith (span, fn () => what ^ ": the signature " ^ T.showScheme sc ^ " is more general than the type inferred, " ^
                                   T.showScheme sc' ^ " (dec.sig.toogeneral)")
      else if not (null rs) then
        refuseWith (span, fn () => what ^ ": the signature's context is too weak, the binding needs " ^
                                   String.concatWith ", " (List.map T.showPred rs) ^ " (dec.sig.toogeneral.ctx)")
      else (bindDefaults (span, defs); ds)
    end

  (* split, its predicates' failures worded (11.5) *)
  and split (span, fs, gs, ps) =
    C.split (E.defaultsOf (!current), fs, gs, ps)
    handle C.NoInstance p => refuseWith (span, fn () => "no instance " ^ T.showPred p ^ " (dec.ctx.noinstance)")
         | C.Ambiguous (v, qs) =>
             refuseWith (span, fn () => "an ambiguous type variable, constrained by " ^
                                        String.concatWith ", " (List.map T.showPred qs) ^
                                        ", which no default resolves (def.ambig, def.cond, def.pick.none)")

  and bindDefaults (span, defs) =
    List.app (fn (v, qs, t) =>
                (chosen := !chosen @ [{module = !current, span = span, preds = List.map (generic v) qs, choice = t,
                                       ruleTwo = false}];
                 T.unify (T.TVar v, t)))
      defs

  (* a defaulted predicate with its variable as the generic `a` *)
  and generic v (T.IsIn (c, t)) = T.IsIn (c, E.abstract [v] t)

  (* `tiGroup (env, group, sigs)`: a declaration group, its explicit
     bindings checked after its implicit ones are inferred as one list;
     its deferred predicates and the schemes of what it binds *)
  and tiGroup (env : env, group : bind list, sigs) : T.pred list * (T.id * T.scheme * bool) list * bool =
    let
      fun sigOf id = Option.map #1 (M.find (sigs, T.idKey id))
      fun signed id = isSome (sigOf id)
      val span = bindSpan (hd group)
      val restricted =
        List.exists (fn Pat {simple = false, ...} => true
                      | Pat {simple = true, vars, ...} => List.exists (not o signed) vars
                      | Fun _ => false)
          group
      fun explicit (Fun {id, ...}) = signed id
        | explicit (Pat {simple, vars, ...}) = simple andalso List.all signed vars
      val expls = List.filter explicit group
      val impls = List.filter (not o explicit) group
      val declared =
        List.concat (List.map (fn b => List.mapPartial (fn id => Option.map (fn sc => (id, sc)) (sigOf id)) (bound b)) group)
      (* R21(b): the signatures of one group have one context, up to
         renaming *)
      val () =
        case declared of
          (_, first) :: rest =>
            List.app (fn (id, sc) =>
                        if contextsAgree (first, sc) then ()
                        else refuse (span, "the signatures of one declaration group have contexts identical up to " ^
                                           "renaming, and `" ^ plain id ^ "`'s differs (dec.gen.sig.identical, R21)"))
              rest
        | [] => ()
      val env' = extend (env, List.map (fn (id, sc) => (T.idKey id, sc)) declared)
      val (ds1, inferred) = if null impls then ([], []) else tiImpls (env', impls, restricted, span, signed)
      val env'' = extend (env', List.mapPartial (fn (id, sc) => if signed id then NONE else SOME (T.idKey id, sc)) inferred)
      val ds2 =
        List.concat
          (List.map
             (fn b =>
                case b of
                  Fun {id, clauses, span} =>
                    checkExpl (env'', valOf (sigOf id), restricted, span, "`" ^ plain id ^ "`",
                               fn t => tiClauses (env'', clauses, t, span))
                | Pat {vars = [id], rhs, span, ...} =>
                    checkExpl (env'', valOf (sigOf id), restricted, span, "`" ^ plain id ^ "`",
                               fn t => unify (span, "`" ^ plain id ^ "`", tiRhs (env'', rhs), t))
                | Pat _ => [])
             expls)
      (* a signed variable of a pattern binding that is not simple: its
         signature against what the pattern gave it *)
      val ds3 =
        List.concat
          (List.mapPartial
             (fn (id, sc) =>
                case List.find (fn (id', _) => T.idEq (id, id')) inferred of
                  SOME (_, inf) =>
                    SOME (checkExpl (env'', sc, restricted, span, "`" ^ plain id ^ "`",
                                     fn t => unify (span, "`" ^ plain id ^ "`'s signature", instantiate inf, t)))
                | NONE => NONE)
             declared)
      val schemes =
        List.map (fn (id, sc) => (id, sc, true)) declared
        @ List.mapPartial (fn (id, sc) => if signed id then NONE else SOME (id, sc, false)) inferred
    in
      (ds1 @ ds2 @ ds3, schemes, restricted)
    end

  (* tiImpls, in the conformant form: a restricted group's constrained
     variables that its types mention are neither generalized nor
     defaulted here, but deferred (R20) *)
  and tiImpls (env : env, bs : bind list, restricted, span, signed) =
    let
      fun assume b =
        case b of
          Fun {id, ...} => let val t = T.newTVar T.Star in ([(id, t)], NONE) end
        | Pat {pat, ...} =>
            let val (binds, t) = tiPat pat
            in (List.map (fn (k, t) => (valOf (List.find (fn id => T.idKey id = k) (bound b)), t)) binds, SOME t) end
      val ((assumed, ()), ps) =
        collecting (fn () =>
          let
            val assumed = List.map assume bs
            val all = List.concat (List.map #1 assumed)
            val env' = extendMono (env, List.mapPartial (fn (id, t) => if signed id then NONE else SOME (T.idKey id, t)) all)
            val () =
              ListPair.app
                (fn (Fun {id, clauses, span}, ([(_, t)], _)) => tiClauses (env', clauses, t, span)
                  | (Pat {rhs, span, ...}, (_, SOME t)) => unify (span, "a pattern binding", tiRhs (env', rhs), t)
                  | _ => ())
                (bs, assumed)
          in
            (all, ())
          end)
      val ps' = List.map T.zonkPred ps
      val ts' = List.map (fn (_, t) => T.zonk t) assumed
      val fs = fixedVars env
      val vss = List.map T.tvs ts'
      val gs = minus (union vss, fs)
      val (ds, rs, defs) = split (span, fs, if restricted then union vss else intersect vss, ps')
      val () = bindDefaults (span, defs)
    in
      if restricted then
        let val gs' = minus (gs, T.predTvs rs)
        in (ds @ rs, List.map (fn ((id, _), t) => (id, T.quantify (gs', ([], t)))) (ListPair.zip (assumed, ts'))) end
      else (ds, List.map (fn ((id, _), t) => (id, T.quantify (gs, (rs, t)))) (ListPair.zip (assumed, ts')))
    end

  (* two contexts that are one up to a renaming of their variables *)
  and contextsAgree (T.Forall (_, (ps, _)), T.Forall (_, (qs, _))) =
    let
      fun matchTy (m, a, b) =
        case (a, b) of
          (T.TGen i, T.TGen j) =>
            (case (List.find (fn (x, _) => x = i) m, List.find (fn (_, y) => y = j) m) of
               (SOME (_, y), _) => if y = j then SOME m else NONE
             | (NONE, SOME _) => NONE
             | (NONE, NONE) => SOME ((i, j) :: m))
        | (T.TAp (f, x), T.TAp (g, y)) => (case matchTy (m, f, g) of SOME m' => matchTy (m', x, y) | NONE => NONE)
        | (T.TCon c, T.TCon d) => if T.idEq (#id c, #id d) then SOME m else NONE
        | _ => NONE
      fun search ([], [], _) = true
        | search (T.IsIn (c, t) :: rest, qs, m) =
            let
              fun try ([], _) = false
                | try ((q as T.IsIn (d, u)) :: more, prior) =
                    (T.idEq (c, d) andalso
                     (case matchTy (m, t, u) of
                        SOME m' => search (rest, List.rev prior @ more, m')
                      | NONE => false))
                    orelse try (more, q :: prior)
            in
              try (qs, [])
            end
        | search _ = false
    in
      length ps = length qs andalso search (ps, qs, [])
    end

  (* a `let`'s or a `where`'s declarations: each group in order, its
     deferred predicates passed out (tiSeq tiBindGroup) *)
  and tiDecls (env : env, decls : A.decl list) : env =
    let
      val sigs = sigsOf decls
      fun go (env, []) = env
        | go (env, group :: rest) =
            let val (ds, schemes, _) = tiGroup (env, group, sigs)
            in push ds; go (extend (env, List.map (fn (id, sc, _) => (T.idKey id, sc)) schemes), rest) end
    in
      go (env, groupsOf (bindsOf decls))
    end

  (* ---- the top level of a group of modules (11.6.4) ---- *)

  (* the scheme a method of `cls` has in an instance of type `head` over
     generic variables with the context `context` *)
  fun methodInInstance ({scheme, ...} : E.method, head, context, arity, kinds) =
    let
      val ws = Vector.fromList (List.map T.newTVar kinds)
      val (ps, t) = T.freshInst scheme
      val h = T.inst ws head
      val () = case ps of
                 T.IsIn (_, a) :: _ => T.unify (a, h)
               | [] => ()
      val qual = (List.map (T.instPred ws) context @ List.drop (ps, 1), t)
      val vs = T.tvsList (t :: List.map (fn T.IsIn (_, u) => u) (#1 qual))
    in
      T.quantify (vs, qual)
    end

  (* `modules {group, main, cycleDefault, derived}`: a strongly connected
     group of modules (tiProgram): the declaration groups of its top level
     in their order, then its classes' default methods and its instances'
     methods, explicitly typed bindings both, a derived instance's made as
     the tree a user would write (`derived`: its module, its identity
     `CLS@TYCON` and its methods; D54) as any instance's, at the head and
     the least context this inference derived, the type of `main`, and
     Rule 2 *)
  fun modules {group : E.module list, main : string option, cycleDefault : bool,
               derived : (string * string * A.decl list) list} =
    let
      val mods = Vector.fromList group
      (* the bindings of the top level, each with its module *)
      val tagged =
        List.concat (List.map (fn {id, ast = A.Module (_, {decls, ...}), library} =>
                                 List.map (fn b => (b, id, library)) (bindsOf decls)) group)
      val sigs =
        List.foldl (fn ({ast = A.Module (_, {decls, ...}), ...} : E.module, m) =>
                      M.foldl (fn (k, v, m) => M.insert (m, k, v)) m (sigsOf decls))
          M.empty group
      val byFile =
        List.foldl (fn ({id, ast = A.Module ({span, ...}, _), library}, m) => M.insert (m, #file span, (id, library)))
          M.empty group
      (* a binding's module: its binders' (a name of the top level is its
         entity, qualified by its module), or its file's *)
      fun whose b =
        case bound b of
          {qual, ...} :: _ => (qual, Vector.exists (fn {id, library, ...} => id = qual andalso library) mods)
        | [] => getOpt (M.find (byFile, #file (bindSpan b)), ("", false))
      val deferred : (T.pred * string * HsSource.span) list ref = ref []
      fun group' bs =
        let
          val (mid, lib) = whose (hd bs)
          val () = (current := mid; inLibrary := lib; T.ruleTwo := (if cycleDefault then "" else mid))
          val (ds, schemes, restricted) = tiGroup (empty, bs, sigs)
          val () = deferred := !deferred @ List.map (fn p => (p, mid, bindSpan (hd bs))) ds
          val () = List.app (fn (id, sc, signed) =>
                               (tops := M.insert (!tops, T.idKey id, sc);
                                List.app (fn v => let val T.TV {owner, ...} = v in if !owner = "" then owner := mid else () end)
                                  (T.schemeTvs sc);
                                topMono := List.map T.TVar (T.schemeTvs sc) @ !topMono))
                     schemes
        in
          bindings := !bindings @ List.map (fn (id, sc, signed) => {module = #qual id, id = id, scheme = sc, signed = signed,
                                                                    restricted = restricted, span = bindSpan (hd bs)})
                                    schemes
        end
      val () = List.app group' (groupsOf (List.map #1 tagged))
      fun libraryOf mid = Vector.exists (fn {id, library, ...} => id = mid andalso library) mods
      fun inGroup mid = Vector.exists (fn {id, ...} => id = mid) mods
      (* class defaults and instance methods: explicitly typed bindings *)
      fun method (mid, b, sc) =
        let
          val () = (current := mid; inLibrary := libraryOf mid; T.ruleTwo := (if cycleDefault then "" else mid))
          val ds =
            case b of
              Fun {id, clauses, span} =>
                checkExpl (empty, sc, false, span, "the method `" ^ plain id ^ "`", fn t => tiClauses (empty, clauses, t, span))
            | Pat {vars = [id], rhs, span, ...} =>
                checkExpl (empty, sc, false, span, "the method `" ^ plain id ^ "`",
                           fn t => unify (span, "the method `" ^ plain id ^ "`", tiRhs (empty, rhs), t))
            | Pat {span, ...} => refuse (span, "a pattern binding in a class or an instance declaration")
        in
          deferred := !deferred @ List.map (fn p => (p, mid, bindSpan b)) ds
        end
      val () =
        List.app (fn {class, decls, module} =>
                    if inGroup module then
                      List.app (fn b => case M.find (!E.methods, T.idKey (hd (bound b))) of
                                          SOME {scheme, ...} => method (module, b, scheme)
                                        | NONE => refuse (bindSpan b, "`" ^ plain (hd (bound b)) ^ "` is not a method of `" ^
                                                                      plain class ^ "`"))
                        (bindsOf decls)
                    else ())
          (!E.classDecls)
      (* an instance's methods, each at its class's type for the instance *)
      fun instanceMethods (module, class, head, context, arity, decls) =
        let
          val kinds = case T.spine head of
                        (T.TCon {kind, ...}, _) => (List.take (E.argKinds kind, arity) handle Subscript => [])
                      | _ => []
        in
          List.app (fn b =>
                      case M.find (!E.methods, T.idKey (hd (bound b))) of
                        SOME (m as {class = c, ...}) =>
                          if T.idEq (c, class) then
                            method (module, b, methodInInstance (m, head, context, arity, kinds))
                          else refuse (bindSpan b, "`" ^ plain (hd (bound b)) ^ "` is not a method of `" ^
                                                   plain class ^ "`")
                      | NONE => refuse (bindSpan b, "`" ^ plain (hd (bound b)) ^ "` is not a method of `" ^
                                                    plain class ^ "`"))
            (bindsOf decls)
        end
      val () =
        List.app (fn {class, head, context, arity, decls, module, span} =>
                    if inGroup module then instanceMethods (module, class, head, context, arity, decls) else ())
          (!E.instances)
      (* a derived instance's methods, at what this inference derived *)
      val () =
        List.app (fn (module, inst, decls) =>
                    if inGroup module then
                      let
                        val (class, tc) = E.ofInstanceId inst
                        val span = case decls of A.D ({span, ...}, _) :: _ => span | [] => HsSource.noSpan
                      in
                        case List.find (fn {head, derived, ...} : C.inst =>
                                          derived andalso (case E.headTycon head of SOME t => T.idEq (t, tc) | NONE => false))
                               (C.instsOf class) of
                          SOME {head = T.IsIn (_, h), context, arity, ...} =>
                            instanceMethods (module, class, h, context, arity, decls)
                        | NONE => refuse (span, "a derived instance of `" ^ plain class ^ "` at `" ^ plain tc ^
                                                "` is made, which no deriving clause asks for")
                      end
                    else ())
          derived
      (* main has the type IO t (5) *)
      val () =
        case main of
          SOME mid =>
            if inGroup mid then
              case M.find (!tops, T.idKey {qual = mid, name = "main"}) of
                SOME sc =>
                  let
                    val (ps, t) = T.freshInst sc
                    val span = case List.find (fn {id, ...} : binding => T.idEq (id, {qual = mid, name = "main"})) (!bindings) of
                                 SOME {span, ...} => span
                               | NONE => HsSource.noSpan
                  in
                    current := mid;
                    T.ruleTwo := (if cycleDefault then "" else mid);
                    unify (span, "main has the type IO t (prog.main.type)", t, T.TAp (E.preludeTy "IO", T.newTVar T.Star));
                    deferred := !deferred @ List.map (fn p => (p, mid, span)) ps
                  end
              | NONE => ()
            else ()
        | NONE => ()
      (* Rule 2: what is left is defaulted, each module's predicates by its
         own default (D30), or the group's under --cycle-default=scc *)
      val reduced =
        List.concat
          (Vector.foldr (fn ({id, ...}, acc) =>
                           let
                             val mine = List.filter (fn (_, m, _) => m = id) (!deferred)
                             val () = (current := id; inLibrary := libraryOf id)
                             (* each predicate reduced with the place it arose *)
                             val rs =
                               List.concat
                                 (List.map (fn (p, _, sp) =>
                                              List.map (fn q => (q, id, sp)) (C.toHnfs [T.zonkPred p])
                                              handle C.NoInstance q =>
                                                refuseWith (sp, fn () => "no instance " ^ T.showPred q ^ " (dec.ctx.noinstance)"))
                                    mine)
                           in
                             rs :: acc
                           end)
             [] mods)
      val vars = T.predTvs (List.map #1 reduced)
      fun defaultsFor ms =
        if cycleDefault then
          let val all = List.map (fn {id, ...} => E.defaultsOf id) (Vector.foldr op :: [] mods)
          in hd all end
        else E.defaultsOf (hd ms)
      val () =
        if cycleDefault then
          let val all = Vector.foldr (fn ({id, ...}, acc) => E.defaultsOf id :: acc) [] mods
          in
            List.app (fn ds => if length ds = length (hd all) andalso ListPair.all T.same (ds, hd all) then ()
                               else refuse (HsSource.noSpan, "the modules of a cycle declare different defaults, " ^
                                                             "and --cycle-default=scc takes one for the cycle (D30)"))
              all
          end
        else ()
      val () = T.ruleTwo := ""
    in
      List.app
        (fn v =>
           let
             val mine = List.filter (fn (p, _, _) => C.mentions (v, p)) reduced
             val ms = List.map #2 mine
             val sp = case mine of (_, _, s) :: _ => s | [] => HsSource.noSpan
             val ds = defaultsFor ms
             val () =
               List.app (fn m => let val ds' = E.defaultsOf m
                                 in
                                   if length ds' = length ds andalso ListPair.all T.same (ds', ds) then ()
                                   else refuse (sp, "a type variable constrained in two modules of a cycle whose defaults " ^
                                                    "differ (D30)")
                                 end)
                 (if cycleDefault then [] else ms)
             val qs = List.map #1 mine
           in
             current := hd ms;
             case C.candidates (ds, (v, qs)) of
               t :: _ => (chosen := !chosen @ [{module = hd ms, span = sp, preds = List.map (generic v) (C.simplify qs),
                                                choice = t, ruleTwo = true}];
                          T.unify (T.TVar v, t))
             | [] => refuseWith (sp, fn () => "Rule 2: a monomorphic type variable left when the module is inferred, " ^
                                              "constrained by " ^ String.concatWith ", " (List.map (T.showPred o T.zonkPred) qs) ^
                                              ", which no default resolves (mr.rule2.notdefaultable)")
           end)
        vars;
      deferred := []
    end
end
