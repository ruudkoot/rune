(* The declarations of a program as HsLint's second inference reads them
   (the haskell98 roadmap's M16, D54): its type constructors, synonyms and
   classes with the kinds inferred for them over their dependency groups
   (4.6), the types of its constructors, fields and methods, its instances,
   written and derived, with the contexts of the derived ones found by the
   fixpoint of 4.3.3 and 10.1, and each module's default types (4.3.4).
   Every check of a declaration that the Report makes static is made here:
   each refusal names the row of the conformance table it is for.

   It reads the renamed tree: a name of the top level is its entity, with
   the module's identity, and the special syntax stays as written. It is
   HsLint's own reading, and shares nothing with the checker's (D54). *)
structure HsLintEnv =
struct
  structure A = HsAst
  structure T = HsLintTypes
  structure C = HsLintClasses
  structure K = HsLintKinds
  structure M = HsStringMap

  (* a module of the program: its identity, its renamed and resolved
     tree, and whether it is the library's *)
  type module = {id : string, ast : A.module, library : bool}

  (* a type constructor: a data type or newtype with its constructors, a
     synonym with its arity and its expansion over generic variables, or
     built in *)
  datatype tydef =
      Data of {kind : T.kind, cons : T.id list, newtype : bool}
    | Synonym of {kind : T.kind, arity : int, rhs : T.ty}

  (* a data constructor: its type, its arguments' fields and strictness,
     and its type constructor *)
  type con = {id : T.id, scheme : T.scheme, arity : int, fields : T.id option list, strict : bool list, tycon : T.id,
              args : T.ty list, context : T.pred list}

  (* a field: its selector's type, and the constructors that have it, with
     its position in each *)
  type field = {id : T.id, tycon : T.id, scheme : T.scheme, cons : (T.id * int) list}

  (* a class's method: its type, the class's predicate first *)
  type method = {id : T.id, class : T.id, scheme : T.scheme}

  (* a written instance, for its methods: the class, the instance's type
     and context over generic variables, its bindings and module *)
  type instance = {class : T.id, head : T.ty, context : T.pred list, arity : int, decls : A.decl list,
                   module : string, span : HsSource.span}

  (* a class declaration, for its default methods *)
  type classDecl = {class : T.id, decls : A.decl list, module : string}

  val tydefs : tydef M.map ref = ref M.empty
  val cons : con M.map ref = ref M.empty
  val fields : field M.map ref = ref M.empty
  val methods : method M.map ref = ref M.empty
  val classKinds : T.kind M.map ref = ref M.empty
  val defaults : T.ty list M.map ref = ref M.empty
  val instances : instance list ref = ref []
  val classDecls : classDecl list ref = ref []
  (* the identity of the Prelude, and the modules of the program *)
  val prelude = ref ""
  val programModules : bool M.map ref = ref M.empty

  fun reset () =
    (tydefs := M.empty; cons := M.empty; fields := M.empty; methods := M.empty; classKinds := M.empty;
     defaults := M.empty; instances := []; classDecls := []; prelude := ""; programModules := M.empty;
     C.reset ())

  fun refuse (span, msg) = raise T.Refuse (span, msg)

  fun nameOf (A.Name (_, q)) = q
  fun spanOfName (A.Name ({span, ...}, _)) = span
  fun text (A.Name (_, q)) = #name q
  fun plain ({name, ...} : T.id) = name

  (* ---- the Prelude's entities, which the translations name ---- *)

  fun preludeId name = {qual = !prelude, name = name} : T.id

  (* the identity of the program's module of the name `m`, the library's
     where there is one *)
  fun moduleId m =
    if M.member (!programModules, "haskell98:" ^ m) then SOME ("haskell98:" ^ m)
    else if M.member (!programModules, m) then SOME m
    else NONE

  fun tyconKind (q : T.id) : T.kind option =
    if #qual q = "" then
      case #name q of
        "()" => SOME T.Star
      | "[]" => SOME (T.KFun (T.Star, T.Star))
      | "(->)" => SOME (T.KFun (T.Star, T.KFun (T.Star, T.Star)))
      | n => if String.isPrefix "(," n then SOME (K.toKind (K.tupleKind (size n - 1))) else NONE
    else
      case M.find (!tydefs, T.idKey q) of
        SOME (Data {kind, ...}) => SOME kind
      | SOME (Synonym {kind, ...}) => SOME kind
      | NONE => NONE

  (* a type constructor of the Prelude, by its name: `Char`, `Bool` *)
  fun preludeTy name =
    let val q = preludeId name
    in T.TCon {id = q, kind = getOpt (tyconKind q, T.Star)} end

  (* the expansion of a nullary synonym of the Prelude, `String` *)
  fun tString () = T.list (preludeTy "Char")

  (* ---- types of the source ---- *)

  fun strip (A.T (_, A.TParen t)) = strip t
    | strip t = t

  (* the head of an application of the source and its arguments *)
  fun tySpine t =
    let
      fun go (t, args) =
        case strip t of
          A.T (_, A.TApp (f, a)) => go (f, a :: args)
        | h => (h, args)
    in
      go (t, [])
    end

  (* the type-level names a type mentions *)
  fun tyNames (A.T (_, x), acc) =
    case x of
      A.TCon (A.Name (_, q)) => q :: acc
    | A.TApp (f, a) => tyNames (a, tyNames (f, acc))
    | A.TFun (a, b) => tyNames (b, tyNames (a, acc))
    | A.TList a => tyNames (a, acc)
    | A.TTuple ts => List.foldl tyNames acc ts
    | A.TParen t => tyNames (t, acc)
    | A.TVar _ => acc

  (* a context's predicates: each class with its type *)
  fun predsOf (cx : A.ty option) : (A.name * A.ty) list =
    let
      fun one t =
        case tySpine t of
          (A.T (_, A.TCon c), [arg]) => (c, arg)
        | _ => refuse (A.spanOfTy t, "a context holds class assertions, each a class and a type")
    in
      case cx of
        NONE => []
      | SOME t =>
          case strip t of
            A.T (_, A.TTuple ts) => List.map one ts
          | A.T (_, A.TCon (A.Name (_, {qual = "", name = "()"}))) => []
          | t' => [one t']
    end

  (* `convert vars t`: the type `t` with its variables as `vars` gives
     them and its synonyms expanded; a synonym is applied to all its
     arguments (4.2.2, dec.type.partial) *)
  fun convert (vars : A.name -> T.ty) (t : A.ty) : T.ty =
    let
      fun go t =
        let val (h, args) = tySpine t
        in
          case h of
            A.T ({span, ...}, A.TCon (n as A.Name (_, q))) =>
              (case M.find (!tydefs, T.idKey q) of
                 SOME (Synonym {arity, rhs, ...}) =>
                   if length args < arity then
                     refuse (span, "the type synonym `" ^ text n ^ "` takes " ^ Int.toString arity ^
                                   " arguments and is given " ^ Int.toString (length args) ^ " (dec.type.partial)")
                   else
                     let
                       val ts = Vector.fromList (List.map go (List.take (args, arity)))
                     in
                       List.foldl (fn (a, f) => T.TAp (f, go a)) (T.inst ts rhs) (List.drop (args, arity))
                     end
               | _ =>
                   let
                     val k = case tyconKind q of
                               SOME k => k
                             | NONE => refuse (span, "the type constructor `" ^ text n ^ "` is not defined")
                   in
                     List.foldl (fn (a, f) => T.TAp (f, go a)) (T.TCon {id = q, kind = k}) args
                   end)
          | _ =>
              let
                val A.T (_, x) = h
                val hd =
                  case x of
                    A.TVar n => vars n
                  | A.TFun (a, b) => T.fn_ (go a, go b)
                  | A.TList a => T.list (go a)
                  | A.TTuple ts => T.tuple (List.map go ts)
                  | _ => refuse (A.spanOfTy h, "a type of a form HsLint does not know")
              in
                List.foldl (fn (a, f) => T.TAp (f, go a)) hd args
              end
        end
    in
      go t
    end

  (* the kind a class's variable has *)
  fun classKind (n as A.Name ({span, ...}, q)) =
    case M.find (!classKinds, T.idKey q) of
      SOME k => k
    | NONE => refuse (span, "`" ^ text n ^ "` is not a class")

  (* `typeSig {fixed, context, ty, span}`: a type signature's variables,
     each with a fresh variable of the kind its use gives it, those of
     `fixed` (a class's variable) as given, then its predicates and type.
     The type has kind `*`; a predicate's type its class's kind. *)
  fun typeSig {fixed : (string * T.ty) list, context : A.ty option, ty : A.ty, span : HsSource.span} =
    let
      val kinds : (string * K.ikind) list ref =
        ref (List.map (fn (n, t) => (n, K.fromKind (T.kindOf t))) fixed)
      fun var (A.Name (_, {name, ...})) =
        case List.find (fn (n, _) => n = name) (!kinds) of
          SOME (_, k) => k
        | NONE => let val k = K.fresh () in kinds := !kinds @ [(name, k)]; k end
      fun con q =
        case tyconKind q of
          SOME k => K.fromKind k
        | NONE => refuse (span, "the type constructor `" ^ A.nameText q ^ "` is not defined")
      val infer = K.infer {con = con, var = var}
      val () = K.unify (infer ty, K.KStar)
               handle K.Mismatch => refuse (A.spanOfTy ty, "a signature's type has kind *, and this one has kind " ^
                                                            K.show (infer ty) ^ " (kind.sig.star)")
      val preds = predsOf context
      val () =
        List.app (fn (c, t) =>
                    K.unify (infer t, K.fromKind (classKind c))
                    handle K.Mismatch => refuse (A.spanOfTy t, "the class `" ^ text c ^ "` is of types of kind " ^
                                                               T.showKind (classKind c) ^ " (kind.checked)"))
          preds
      val vars =
        List.map (fn (n, k) =>
                    case List.find (fn (m, _) => m = n) fixed of
                      SOME (_, t) => (n, t)
                    | NONE => (n, T.newTVar (K.toKind k)))
          (!kinds)
      fun look (A.Name ({span = sp, ...}, {name, ...})) =
        case List.find (fn (n, _) => n = name) vars of
          SOME (_, t) => t
        | NONE => refuse (sp, "the type variable `" ^ name ^ "` is not in scope")
      val ps = List.map (fn (c, t) => T.IsIn (nameOf c, convert look t)) preds
      val t = convert look ty
      (* a variable of the context that the type does not mention makes the
         type ambiguous (4.1.4, 4.3.4) *)
      val () =
        List.app (fn v => if T.occurs (v, t) then ()
                          else refuse (span, "the context of a signature constrains a type variable its type does not " ^
                                             "mention, an ambiguous type (ty.sem.form, def.ambig.def_written)"))
          (T.predTvs ps)
      val own = List.mapPartial (fn (n, t) => if List.exists (fn (m, _) => m = n) fixed then NONE
                                              else case T.prune t of T.TVar v => SOME v | _ => NONE) vars
    in
      {vars = own, preds = ps, ty = t}
    end

  (* the scheme of a signature, over all its variables *)
  fun sigScheme {context, ty, span} =
    let val {vars, preds, ty = t} = typeSig {fixed = [], context = context, ty = ty, span = span}
    in T.quantify (vars, (preds, t)) end

  (* ---- the declarations of type constructors and classes ---- *)

  datatype tdecl =
      TData of {id : T.id, cx : A.ty option, params : A.name list, cons : A.constr list, deriv : A.deriv option,
                newtype : bool, module : string, span : HsSource.span}
    | TSyn of {id : T.id, params : A.name list, rhs : A.ty, module : string, span : HsSource.span}
    | TClass of {id : T.id, cx : A.ty option, var : A.name, decls : A.decl list, module : string, span : HsSource.span}

  fun tdeclId (TData {id, ...}) = id
    | tdeclId (TSyn {id, ...}) = id
    | tdeclId (TClass {id, ...}) = id

  fun conArgs (A.C (_, x)) =
    case x of
      A.CPlain (k, args) => (k, List.map (fn (s, t) => (NONE, s, t)) args)
    | A.CInfix (l, k, r) => (k, [(NONE, #1 l, #2 l), (NONE, #1 r, #2 r)])
    | A.CRec (k, fs) =>
        (k, List.concat (List.map (fn A.Field (_, vs, s, t) => List.map (fn v => (SOME (nameOf v), s, t)) vs) fs))

  fun sigsOf decls =
    List.mapPartial (fn A.D ({span, ...}, A.DSig (vs, cx, t)) => SOME (vs, cx, t, span) | _ => NONE) decls

  (* the type-level names a declaration depends on, for its group *)
  fun tdeclNames d =
    case d of
      TData {cx, cons, ...} =>
        List.foldl (fn (c, acc) => List.foldl (fn ((_, _, t), acc) => tyNames (t, acc)) acc (#2 (conArgs c)))
          (case cx of SOME t => tyNames (t, []) | NONE => []) cons
    | TSyn {rhs, ...} => tyNames (rhs, [])
    | TClass {cx, decls, ...} =>
        List.foldl (fn ((_, c, t, _), acc) => tyNames (t, case c of SOME c => tyNames (c, acc) | NONE => acc))
          (case cx of SOME t => tyNames (t, []) | NONE => []) (sigsOf decls)

  fun collect (modules : module list) =
    List.concat
      (List.map
         (fn {id = mid, ast = A.Module (_, {decls, ...}), ...} =>
            List.mapPartial
              (fn A.D ({span, ...}, x) =>
                 case x of
                   A.DData (cx, n, ps, cs, d) =>
                     SOME (TData {id = nameOf n, cx = cx, params = ps, cons = cs, deriv = d, newtype = false,
                                  module = mid, span = span})
                 | A.DNewtype (cx, n, ps, c, d) =>
                     SOME (TData {id = nameOf n, cx = cx, params = ps, cons = [c], deriv = d, newtype = true,
                                  module = mid, span = span})
                 | A.DType (n, ps, t) => SOME (TSyn {id = nameOf n, params = ps, rhs = t, module = mid, span = span})
                 | A.DClass (cx, n, v, body) =>
                     SOME (TClass {id = nameOf n, cx = cx, var = v, decls = getOpt (body, []), module = mid, span = span})
                 | _ => NONE)
              decls)
         modules)

  (* type variables of a declaration's head: distinct (dec.data.vars.distinct,
     dec.type.vars.distinct) *)
  fun distinct (row, ps : A.name list) =
    let
      fun go ([], _) = ()
        | go (p :: rest, seen) =
            if List.exists (fn n => n = plain (nameOf p)) seen then
              refuse (spanOfName p, "the type variable `" ^ text p ^ "` is a parameter twice (" ^ row ^ ")")
            else go (rest, plain (nameOf p) :: seen)
    in
      go (ps, [])
    end

  (* ---- kind inference over the groups (4.6) ---- *)

  fun inferKinds (ds : tdecl vector) =
    let
      val n = Vector.length ds
      val index = Vector.foldli (fn (i, d, m) => M.insert (m, T.idKey (tdeclId d), i)) M.empty ds
      fun succs i =
        List.mapPartial (fn q => M.find (index, T.idKey q)) (tdeclNames (Vector.sub (ds, i)))
      val groups = HsLintScc.groups (n, succs)
      fun group members =
        let
          val vars = List.map (fn i => (i, K.fresh ())) members
          fun own q =
            case M.find (index, T.idKey q) of
              SOME i => (case List.find (fn (j, _) => j = i) vars of SOME (_, k) => SOME k | NONE => NONE)
            | NONE => NONE
          fun con q =
            case own q of
              SOME k => k
            | NONE => (case tyconKind q of
                         SOME k => K.fromKind k
                       | NONE => K.fresh ())
          fun clsKind (c as A.Name ({span, ...}, q)) =
            case own q of
              SOME k => k
            | NONE => (case M.find (!classKinds, T.idKey q) of
                         SOME k => K.fromKind k
                       | NONE => refuse (span, "`" ^ text c ^ "` is not a class"))
          fun env params =
            let val ks = List.map (fn p => (plain (nameOf p), K.fresh ())) params
            in
              (ks,
               fn (v as A.Name ({span, ...}, {name, ...})) =>
                  case List.find (fn (m, _) => m = name) ks of
                    SOME (_, k) => k
                  | NONE => refuse (span, "the type variable `" ^ name ^ "` is not a parameter of the declaration " ^
                                          "(dec.data.vars.rhs, dec.type.vars.scope)"))
            end
          fun want (infer, t, k, msg) =
            K.unify (infer t, k) handle K.Mismatch => refuse (A.spanOfTy t, msg)
          fun context (infer, cx) =
            List.app (fn (c, t) => want (infer, t, clsKind c, "the class `" ^ text c ^ "` is of types of another kind " ^
                                                             "(kind.checked)"))
              (predsOf cx)
          fun one (i, k) =
            case Vector.sub (ds, i) of
              TData {params, cx, cons = cs, ...} =>
                let
                  val () = distinct ("dec.data.vars.distinct", params)
                  val (ks, var) = env params
                  val infer = K.infer {con = con, var = var}
                in
                  context (infer, cx);
                  List.app (fn c => List.app (fn (_, _, t) => want (infer, t, K.KStar, "a field's type has kind * (kind.checked)"))
                                      (#2 (conArgs c)))
                    cs;
                  K.unify (k, List.foldr (fn ((_, a), r) => K.KArr (a, r)) K.KStar ks)
                  handle K.Mismatch => refuse (#span (case Vector.sub (ds, i) of TData r => r | _ => raise Fail "data"),
                                               "a type constructor of one kind is used at another (kind.consistent)")
                end
            | TSyn {params, rhs, span, ...} =>
                let
                  val () = distinct ("dec.type.vars.distinct", params)
                  val (ks, var) = env params
                  val kr = K.infer {con = con, var = var} rhs
                in
                  K.unify (k, List.foldr (fn ((_, a), r) => K.KArr (a, r)) kr ks)
                  handle K.Mismatch => refuse (span, "a type synonym of one kind is used at another (kind.consistent)")
                end
            | TClass {var = v, cx, decls, ...} =>
                let
                  val name = plain (nameOf v)
                  fun var (A.Name ({span, ...}, {name = m, ...})) =
                    if m = name then k else refuse (span, "the type variable `" ^ m ^ "` is not the class's (cls.class.super.onlyvar)")
                  val () = context (K.infer {con = con, var = var}, cx)
                in
                  List.app
                    (fn (_, c, t, _) =>
                       let
                         val ks = ref [(name, k)]
                         fun var' (A.Name (_, {name = m, ...})) =
                           case List.find (fn (x, _) => x = m) (!ks) of
                             SOME (_, kk) => kk
                           | NONE => let val kk = K.fresh () in ks := !ks @ [(m, kk)]; kk end
                         val infer = K.infer {con = con, var = var'}
                       in
                         want (infer, t, K.KStar, "a method's type has kind * (kind.sig.star)");
                         context (infer, c)
                       end)
                    (sigsOf decls)
                end
        in
          List.app one vars;
          List.app (fn (i, k) =>
                      let val d = Vector.sub (ds, i)
                      in
                        case d of
                          TClass {id, ...} => classKinds := M.insert (!classKinds, T.idKey id, K.toKind k)
                        | TData {id, newtype, ...} =>
                            tydefs := M.insert (!tydefs, T.idKey id, Data {kind = K.toKind k, cons = [], newtype = newtype})
                        | TSyn {id, params, ...} =>
                            tydefs := M.insert (!tydefs, T.idKey id,
                                                Synonym {kind = K.toKind k, arity = length params, rhs = T.TGen 0})
                      end)
            vars
        end
    in
      List.app group groups
    end

  (* ---- synonyms: no cycle, expanded in their order (4.2.2) ---- *)

  fun synonyms (ds : tdecl list) =
    let
      val syns = Vector.fromList (List.filter (fn TSyn _ => true | _ => false) ds)
      val n = Vector.length syns
      val index = Vector.foldli (fn (i, d, m) => M.insert (m, T.idKey (tdeclId d), i)) M.empty syns
      fun succs i = List.mapPartial (fn q => M.find (index, T.idKey q)) (tdeclNames (Vector.sub (syns, i)))
      fun one i =
        case Vector.sub (syns, i) of
          TSyn {id, params, rhs, ...} =>
            let
              val gens = List.tabulate (length params, fn j => (plain (nameOf (List.nth (params, j))), T.TGen j))
              fun var (A.Name ({span, ...}, {name, ...})) =
                case List.find (fn (m, _) => m = name) gens of
                  SOME (_, t) => t
                | NONE => refuse (span, "the type variable `" ^ name ^ "` is not a parameter of the synonym (dec.type.vars.scope)")
              val t = convert var rhs
            in
              case M.find (!tydefs, T.idKey id) of
                SOME (Synonym {kind, arity, ...}) =>
                  tydefs := M.insert (!tydefs, T.idKey id, Synonym {kind = kind, arity = arity, rhs = t})
              | _ => ()
            end
        | _ => ()
    in
      List.app
        (fn [i] =>
              if HsLintScc.selfLoop succs i then
                (case Vector.sub (syns, i) of
                   TSyn {span, id, ...} => refuse (span, "the type synonym `" ^ plain id ^ "` is defined by itself (dec.type.rec.self)")
                 | _ => ())
              else one i
          | group =>
              case Vector.sub (syns, hd group) of
                TSyn {span, ...} => refuse (span, "type synonyms defined by one another (dec.type.rec.mutual)")
              | _ => ())
        (HsLintScc.groups (n, succs))
    end

  (* ---- data types and newtypes: constructors and fields (4.2.1, 4.2.3) ---- *)

  (* the type with the variables `vs` made the generic variables of their
     positions *)
  fun abstract (vs : T.tyvar list) t =
    let
      fun index (v, i, []) = NONE
        | index (v, i, w :: ws) = if T.tvEq (v, w) then SOME i else index (v, i + 1, ws)
      fun go t =
        case T.prune t of
          T.TVar v => (case index (v, 0, vs) of SOME i => T.TGen i | NONE => T.TVar v)
        | T.TAp (a, b) => T.TAp (go a, go b)
        | t' => t'
    in
      go t
    end

  fun argKinds (T.KFun (a, b)) = a :: argKinds b
    | argKinds T.Star = []

  fun datatypes (ds : tdecl list) =
    List.app
      (fn TData {id, cx, params, cons = cs, newtype, span, ...} =>
            let
              val kind = case M.find (!tydefs, T.idKey id) of SOME (Data {kind, ...}) => kind | _ => T.Star
              val vs = ListPair.map (fn (p, k) => (plain (nameOf p), T.newTVar k)) (params, argKinds kind)
              fun var (A.Name ({span, ...}, {name, ...})) =
                case List.find (fn (m, _) => m = name) vs of
                  SOME (_, t) => t
                | NONE => refuse (span, "the type variable `" ^ name ^ "` is not a parameter of the declaration " ^
                                        "(dec.data.vars.rhs, dec.data.vars.ctx)")
              val tvs = List.mapPartial (fn (_, t) => case t of T.TVar v => SOME v | _ => NONE) vs
              val result = List.foldl (fn ((_, t), f) => T.TAp (f, t)) (T.TCon {id = id, kind = kind}) vs
              val context = List.map (fn (c, t) => T.IsIn (nameOf c, convert var t)) (predsOf cx)
              val fieldTypes : (T.id * T.ty * T.id * int * T.pred list) list ref = ref []
              fun con c =
                let
                  val (k, args) = conArgs c
                  (* a field once in a constructor (3.15.1, exp.field.once) *)
                  val () =
                    ignore (List.foldl (fn ((SOME f, _, t), seen) =>
                                            if List.exists (fn g => T.idEq (f, g)) seen then
                                              refuse (A.spanOfTy t, "the field `" ^ plain f ^ "` twice in the constructor `" ^
                                                                    text k ^ "` (exp.field.once)")
                                            else f :: seen
                                         | (_, seen) => seen)
                              [] args)
                  val ts = List.map (fn (_, _, t) => convert var t) args
                  val free = T.tvsList ts
                  val cx = List.filter (fn p => List.all (fn v => List.exists (fn w => T.tvEq (v, w)) free) (T.predTvs [p]))
                             context
                  val scheme = T.quantify (tvs, (cx, T.fnMany (ts, result)))
                  val () =
                    List.app (fn (((SOME f, _, _), t), i) => fieldTypes := !fieldTypes @ [(f, t, nameOf k, i, cx)]
                               | _ => ())
                      (ListPair.zip (ListPair.zip (args, ts), List.tabulate (length ts, fn i => i)))
                in
                  cons := M.insert (!cons, T.idKey (nameOf k),
                                    {id = nameOf k, scheme = scheme, arity = length ts,
                                     fields = List.map #1 args, strict = List.map #2 args, tycon = id,
                                     args = List.map (abstract tvs) ts,
                                     context = List.map (fn T.IsIn (c, t) => T.IsIn (c, abstract tvs t)) cx});
                  nameOf k
                end
              val names = List.map con cs
              (* a field: one type in every constructor that has it
                 (dec.field.shared.differ) *)
              fun fieldsOf [] = ()
                | fieldsOf ((f, t, _, _, _) :: rest) =
                    let
                      val all = List.filter (fn (g, _, _, _, _) => T.idEq (f, g)) (!fieldTypes)
                      val () =
                        List.app (fn (_, u, _, _, _) =>
                                    if T.same (t, u) then ()
                                    else refuse (span, "the field `" ^ plain f ^ "` has two types in the constructors of `" ^
                                                       plain id ^ "` (dec.field.shared.differ)"))
                          all
                      val cx = List.foldl (fn ((_, _, _, _, ps), acc) =>
                                             acc @ List.filter (fn p => not (List.exists (fn q => T.predEq (p, q)) acc)) ps)
                                 [] all
                    in
                      fields := M.insert (!fields, T.idKey f,
                                          {id = f, tycon = id, scheme = T.quantify (tvs, (cx, T.fn_ (result, t))),
                                           cons = List.map (fn (_, _, k, i, _) => (k, i)) all});
                      fieldsOf (List.filter (fn (g, _, _, _, _) => not (T.idEq (f, g))) rest)
                    end
            in
              fieldsOf (!fieldTypes);
              tydefs := M.insert (!tydefs, T.idKey id, Data {kind = kind, cons = names, newtype = newtype})
            end
        | _ => ())
      ds

  (* ---- classes (4.3.1) ---- *)

  fun classes (ds : tdecl list) =
    let
      val cls = List.mapPartial (fn TClass r => SOME r | _ => NONE) ds
      fun std ({qual, ...} : T.id) = String.isPrefix "haskell98:" qual
      fun head {id, cx, var, span, ...} =
        let
          val name = plain (nameOf var)
          fun super (c, t) =
            case strip t of
              A.T (_, A.TVar v) =>
                if plain (nameOf v) = name then nameOf c
                else refuse (spanOfName v, "a superclass context constrains the class's variable alone (cls.class.super.onlyvar)")
            | t' => refuse (A.spanOfTy t', "a superclass context constrains the class's variable alone (cls.class.super.onlyvar)")
          val kind = getOpt (M.find (!classKinds, T.idKey id), T.Star)
        in
          C.classes := M.insert (!C.classes, T.idKey id,
                                 {id = id, kind = kind, supers = List.map super (predsOf cx), std = std id})
        end
      fun cyclic {id, span, ...} =
        if List.exists (fn d => T.idEq (d, id)) (List.concat (List.map C.closure (C.supers id))) then
          refuse (span, "the class `" ^ plain id ^ "` is its own superclass: the superclass relation is cyclic " ^
                        "(cls.class.super.acyclic)")
        else ()
      fun body {id, var, decls, module, ...} =
        let
          val kind = getOpt (M.find (!classKinds, T.idKey id), T.Star)
          val a = T.newTVar kind
          val av = case a of T.TVar v => v | _ => raise Fail "a class's variable"
          val name = plain (nameOf var)
          fun method (vs, c, t, sp) =
            let
              val {vars, preds, ty} = typeSig {fixed = [(name, a)], context = c, ty = t, span = sp}
              val () =
                if List.exists (fn v => T.tvEq (v, av)) (T.predTvs preds) then
                  refuse (sp, "a method's own context may not constrain the class's variable `" ^ name ^ "` (cls.method.ctx.notu)")
                else ()
              val () =
                if T.occurs (av, ty) then ()
                else refuse (sp, "a method's type mentions the class's variable `" ^ name ^ "` (cls.method.mentions)")
              val scheme = T.quantify (av :: vars, (T.IsIn (id, a) :: preds, ty))
            in
              List.app (fn v => methods := M.insert (!methods, T.idKey (nameOf v), {id = nameOf v, class = id, scheme = scheme}))
                vs
            end
        in
          List.app method (sigsOf decls);
          classDecls := !classDecls @ [{class = id, decls = decls, module = module}]
        end
    in
      List.app head cls;
      List.app cyclic cls;
      List.app body cls
    end

  (* ---- instances (4.3.2) ---- *)

  fun headTycon (T.IsIn (_, t)) =
    case T.spine t of
      (T.TCon {id, ...}, _) => SOME id
    | _ => NONE

  (* an entity of a key, `SPACE HOME \t NAME` (HsModules.key), or a
     built-in name *)
  fun idOfKey (k : string) : T.id =
    if k = "->" then {qual = "", name = "(->)"}
    else
      case CharVector.findi (fn (_, c) => c = #"\t") k of
        SOME (i, _) => {qual = String.substring (k, 1, i - 1), name = String.extract (k, i + 1, NONE)}
      | NONE => {qual = "", name = k}

  (* the class and the type constructor of an instance's identity,
     `CLS@TYCON` (HsClasses.instanceId) *)
  fun ofInstanceId (inst : string) : T.id * T.id =
    case CharVector.findi (fn (_, c) => c = #"@") inst of
      SOME (i, _) => (idOfKey (String.substring (inst, 0, i)), idOfKey (String.extract (inst, i + 1, NONE)))
    | NONE => (idOfKey inst, idOfKey "")

  (* the instance of the class for the same type constructor, if any:
     one per class and type in the program (cls.inst.once) *)
  fun existing (cls, tc) =
    List.find (fn {head, ...} : C.inst => case headTycon head of SOME tc' => T.idEq (tc, tc') | NONE => false)
      (C.instsOf cls)

  fun duplicate (span, cls, tc, row) =
    case existing (cls, tc) of
      SOME _ => refuse (span, "a second instance of `" ^ plain cls ^ "` for `" ^ plain tc ^ "`: a type is an instance of a " ^
                              "class once in a program (" ^ row ^ ")")
    | NONE => ()

  fun written (modules : module list) =
    let
      fun one mid (A.D ({span, ...}, A.DInstance (cx, c, ty, body))) =
            let
              val cls = nameOf c
              val ckind = classKind c
              fun var t =
                case strip t of
                  A.T (_, A.TVar v) => v
                | t' => refuse (A.spanOfTy t', "an instance's type is a type constructor applied to type variables " ^
                                               "(cls.inst.reject.nested)")
              val (tc, vs) =
                case strip ty of
                  A.T (_, A.TList t) => (T.builtin "[]", [var t])
                | A.T (_, A.TTuple ts) => (T.builtin (T.tupleName (length ts)), List.map var ts)
                | A.T (_, A.TFun (a, b)) => (T.builtin "(->)", [var a, var b])
                | t' =>
                    case tySpine t' of
                      (A.T ({span = sp, ...}, A.TCon n), args) =>
                        (case M.find (!tydefs, T.idKey (nameOf n)) of
                           SOME (Synonym _) =>
                             refuse (sp, "an instance's type may not be the type synonym `" ^ text n ^ "` (cls.inst.reject.synonym)")
                         | _ => (nameOf n, List.map var args))
                    | (h, _) => refuse (A.spanOfTy h, "an instance's type is a type constructor applied to type variables, " ^
                                                      "not a type variable (cls.inst.reject.var)")
              val () = distinct ("cls.inst.reject.repeated", vs)
              val tk = case tyconKind tc of SOME k => k | NONE => refuse (span, "`" ^ plain tc ^ "` is not a type constructor")
              val ks = argKinds tk
              fun drop (k, 0) = SOME k
                | drop (T.KFun (_, r), n) = drop (r, n - 1)
                | drop (T.Star, _) = NONE
              val () =
                case drop (tk, length vs) of
                  SOME k => if k = ckind then ()
                            else refuse (span, "the class `" ^ text c ^ "` is of types of kind " ^ T.showKind ckind ^
                                               ", and the instance's type has kind " ^ T.showKind k ^ " (cls.inst.kind)")
                | NONE => refuse (span, "an instance's type applies `" ^ plain tc ^ "` to more types than its kind takes " ^
                                        "(kind.checked)")
              val head = List.foldl (fn (i, f) => T.TAp (f, T.TGen i)) (T.TCon {id = tc, kind = tk})
                           (List.tabulate (length vs, fn i => i))
              fun position v =
                let
                  fun go (i, []) = refuse (spanOfName v, "an instance's context constrains the variables of its type alone " ^
                                                         "(cls.inst.ctx.vars)")
                    | go (i, w :: ws) = if plain (nameOf w) = plain (nameOf v) then i else go (i + 1, ws)
                in
                  go (0, vs)
                end
              val context =
                List.map (fn (d, t) =>
                            case strip t of
                              A.T (_, A.TVar v) =>
                                let val i = position v
                                in
                                  if classKind d = List.nth (ks, i) then T.IsIn (nameOf d, T.TGen i)
                                  else refuse (A.spanOfTy t, "the class `" ^ text d ^ "` is of types of another kind " ^
                                                             "(kind.checked)")
                                end
                            | t' => refuse (A.spanOfTy t', "an instance's context constrains type variables alone " ^
                                                           "(cls.inst.ctx.simple)"))
                  (predsOf cx)
            in
              duplicate (span, cls, tc, "cls.inst.once");
              C.addInst {head = T.IsIn (cls, head), context = context, arity = length vs, span = span, derived = false};
              instances := !instances @ [{class = cls, head = head, context = context, arity = length vs,
                                          decls = getOpt (body, []), module = mid, span = span}]
            end
        | one _ _ = ()
    in
      List.app (fn {id, ast = A.Module (_, {decls, ...}), ...} => List.app (one id) decls) modules
    end

  (* ---- the tuples' instances (6.1.4, 15.1) ---- *)

  (* Every tuple of 2 to 15 components is an instance of Eq, Ord, Bounded,
     Read and Show (6.1.4) and of Ix (15.1) where its components are. The
     Report's code gives a few and calls the rest similar, which M17's
     overlay is to write (ov.tuples.fifteen); until it does, HsLint adds
     each instance the program does not declare, as derived. *)
  fun tuples () =
    let
      val classes =
        List.filter (fn c => isSome (M.find (!C.classes, T.idKey c)))
          (List.mapPartial (fn (m, n) => Option.map (fn mid => {qual = mid, name = n}) (moduleId m))
             [("Prelude", "Eq"), ("Prelude", "Ord"), ("Prelude", "Bounded"), ("PreludeText", "Read"),
              ("PreludeText", "Show"), ("Ix", "Ix")])
      fun one (cls, n) =
        let
          val tc = T.builtin (T.tupleName n)
          val head = List.foldl (fn (i, f) => T.TAp (f, T.TGen i)) (T.TCon {id = tc, kind = valOf (tyconKind tc)})
                       (List.tabulate (n, fn i => i))
        in
          case existing (cls, tc) of
            SOME _ => ()
          | NONE => C.addInst {head = T.IsIn (cls, head), context = List.tabulate (n, fn i => T.IsIn (cls, T.TGen i)),
                               arity = n, span = HsSource.noSpan, derived = true}
        end
    in
      List.app (fn c => List.app (fn n => one (c, n)) (List.tabulate (14, fn i => i + 2))) classes
    end

  (* ---- derived instances (4.3.3, 10) ---- *)

  val derivable = ["Eq", "Ord", "Enum", "Bounded", "Show", "Read", "Ix"]

  fun derived (ds : tdecl list) =
    let
      (* what is to be derived: the class, the type constructor, its
         arity and constructors, where *)
      fun wanted (TData {id, deriv = SOME (A.Deriv (_, _, cs)), params, cons = cs', cx, span, ...}) =
            List.map
              (fn c =>
                 let
                   val cls = nameOf c
                   val () =
                     if C.isStd cls andalso List.exists (fn n => n = plain cls) derivable then ()
                     else refuse (spanOfName c, "the class `" ^ text c ^ "` cannot be derived: only Eq, Ord, Enum, Bounded, " ^
                                                "Show, Read and Ix can (cls.derive.user)")
                   val arities = List.map (fn k => #arity (valOf (M.find (!cons, T.idKey (nameOf (#1 (conArgs k)))))))
                                   cs'
                   val enumeration = List.all (fn a => a = 0) arities
                   val () =
                     case plain cls of
                       "Enum" => if enumeration then ()
                                 else refuse (spanOfName c, "Enum is derived for an enumeration alone (cls.derive.impossible)")
                     | "Bounded" => if enumeration orelse length cs' = 1 then ()
                                    else refuse (spanOfName c, "Bounded is derived for an enumeration or a type of one " ^
                                                               "constructor (cls.derive.impossible)")
                     | "Ix" => if enumeration orelse length cs' = 1 then ()
                               else refuse (spanOfName c, "Ix is derived for an enumeration or a type of one constructor " ^
                                                          "(cls.derive.impossible)")
                     | _ => ()
                 in
                   {cls = cls, tycon = id, arity = length params, cx = cx, params = params,
                    cons = List.map (fn k => nameOf (#1 (conArgs k))) cs', span = spanOfName c}
                 end)
              cs
        | wanted _ = []
      val todo = Vector.fromList (List.concat (List.map wanted ds))
      val n = Vector.length todo
      val contexts = Array.array (n, [] : T.pred list)
      val writtenInsts = !C.insts
      fun headOf {tycon, arity, ...} =
        let val k = getOpt (tyconKind tycon, T.Star)
        in List.foldl (fn (i, f) => T.TAp (f, T.TGen i)) (T.TCon {id = tycon, kind = k}) (List.tabulate (arity, fn i => i)) end
      fun install () =
        (C.insts := writtenInsts;
         Vector.appi (fn (i, d as {cls, arity, span, ...}) =>
                        C.addInst {head = T.IsIn (cls, headOf d), context = Array.sub (contexts, i), arity = arity,
                                   span = span, derived = true})
           todo)
      (* the least context: each field's type in the class, with the data
         type's own context (10.1's cx), reduced to predicates on the
         type's variables (dec.ctx.derive.simple) *)
      fun contextOf {cls, tycon, arity, cons = ks, span, cx, params} =
        let
          val kinds = List.take (argKinds (getOpt (tyconKind tycon, T.Star)), arity)
          val vs = List.map T.newTVar kinds
          val ts = Vector.fromList vs
          val fieldTys = List.concat (List.map (fn k => List.map (T.inst ts) (#args (valOf (M.find (!cons, T.idKey k))))) ks)
          (* a predicate with the type's variables as its parameters, a, b *)
          fun shown (T.IsIn (d, t)) =
            T.showPred (T.IsIn (d, abstract (List.mapPartial (fn T.TVar v => SOME v | _ => NONE) vs) t))
          (* the data declaration's own context, cx of 10.1's
             `instance (cx, cx') => C (T u1 ... uk)` *)
          val byName = ListPair.map (fn (p, v) => (plain (nameOf p), v)) (params, vs)
          fun var (A.Name ({span, ...}, {name, ...})) =
            case List.find (fn (m, _) => m = name) byName of
              SOME (_, t) => t
            | NONE => refuse (span, "the type variable `" ^ name ^ "` is not a parameter of the declaration " ^
                                    "(dec.data.vars.ctx)")
          val dataCtx = List.map (fn (c, t) => T.IsIn (nameOf c, convert var t)) (predsOf cx)
          val reduced = C.reduce (List.map (fn t => T.IsIn (cls, t)) fieldTys @ dataCtx)
                        handle C.NoInstance p =>
                          refuse (span, "`" ^ plain cls ^ "` cannot be derived for `" ^ plain tycon ^ "`: no instance " ^
                                        shown p ^ " (cls.derive.impossible)")
          fun position (v, i, []) = NONE
            | position (v, i, t :: rest) =
                (case T.prune t of T.TVar w => if T.tvEq (v, w) then SOME i else position (v, i + 1, rest) | _ => position (v, i + 1, rest))
          fun simple (p as T.IsIn (d, t)) =
            case T.prune t of
              T.TVar v => (case position (v, 0, vs) of SOME i => (T.idKey d ^ "/" ^ Int.toString i, T.IsIn (d, T.TGen i))
                                                     | NONE => refuse (span, "a derived context of a variable not the type's"))
            | _ => refuse (span, "the derived instance of `" ^ plain cls ^ "` for `" ^ plain tycon ^ "` would need the context " ^
                                 shown p ^ ", which is not simple (dec.ctx.derive.simple)")
          val keyed = List.map simple reduced
          val sorted = List.foldl (fn ((k, p), acc) =>
                                     if List.exists (fn (k', _) => k' = k) acc then acc
                                     else let
                                            fun ins [] = [(k, p)]
                                              | ins ((x as (k', _)) :: rest) = if String.< (k, k') then (k, p) :: x :: rest
                                                                               else x :: ins rest
                                          in ins acc end)
                         [] keyed
        in
          List.map #2 sorted
        end
      fun sameCtx (a, b) = length a = length b andalso ListPair.all T.predEq (a, b)
      fun loop () =
        let
          val () = install ()
          val changed = ref false
          val () =
            Vector.appi (fn (i, d) =>
                           let val c = contextOf d
                           in if sameCtx (c, Array.sub (contexts, i)) then () else (Array.update (contexts, i, c); changed := true) end)
              todo
        in
          if !changed then loop () else ()
        end
    in
      (* a derived instance beside a written one (cls.derive.explicit.also) *)
      Vector.app (fn {cls, tycon, span, ...} =>
                    (duplicate (span, cls, tycon, "cls.derive.explicit.also");
                     C.addInst {head = T.IsIn (cls, T.TCon {id = tycon, kind = T.Star}), context = [], arity = 0,
                                span = span, derived = true}))
        todo;
      loop ()
    end

  (* ---- every instance's superclasses (4.3.2, cls.inst.super) ---- *)

  fun superclasses () =
    M.foldl
      (fn (_, is, ()) =>
         List.app
           (fn {head = T.IsIn (cls, h), context, arity, span, derived} =>
              let
                val kinds = case headTycon (T.IsIn (cls, h)) of
                              SOME tc => (List.take (argKinds (getOpt (tyconKind tc, T.Star)), arity) handle Subscript => [])
                            | NONE => []
                val ts = Vector.fromList (List.map T.newTVar (kinds @ List.tabulate (arity - length kinds, fn _ => T.Star)))
                val h' = T.inst ts h
                val ctx = List.map (T.instPred ts) context
              in
                List.app (fn s =>
                            if C.entail ctx (T.IsIn (s, h')) then ()
                            else refuse (span, "the " ^ (if derived then "derived " else "") ^ "instance of `" ^ plain cls ^
                                               "` for " ^ T.showTy h ^ " needs an instance of its superclass `" ^ plain s ^
                                               "` whose context its own implies (cls.inst.super)"))
                  (C.supers cls)
              end)
           is)
      () (!C.insts)

  (* ---- default declarations (4.3.4) ---- *)

  fun defaultsOf mid =
    case M.find (!defaults, mid) of
      SOME ts => ts
    | NONE => [preludeTy "Integer", preludeTy "Double"]

  fun defaultDecls (modules : module list) =
    List.app
      (fn {id = mid, ast = A.Module (_, {decls, ...}), ...} =>
         let
           val ds = List.mapPartial (fn A.D ({span, ...}, A.DDefault ts) => SOME (span, ts) | _ => NONE) decls
           fun ty t =
             let
               val {vars, ty = t', ...} = typeSig {fixed = [], context = NONE, ty = t, span = A.spanOfTy t}
               val () = if null vars then () else refuse (A.spanOfTy t, "a default type has no type variable (def.decl)")
               val num = preludeId "Num"
             in
               if C.entail [] (T.IsIn (num, t')) then t'
               else refuse (A.spanOfTy t, "a default type is an instance of Num, and " ^ T.showTy t' ^ " is not (def.decl.num)")
             end
         in
           case ds of
             [] => ()
           | [(_, ts)] => defaults := M.insert (!defaults, mid, List.map ty ts)
           | _ :: (span, _) :: _ => refuse (span, "a second default declaration in one module (def.one.permodule)")
         end)
      modules

  (* ---- the program's declarations ---- *)

  fun build (modules : module list) =
    let
      val () = reset ()
      val () = List.app (fn {id, ...} => programModules := M.insert (!programModules, id, true)) modules
      val () =
        prelude :=
          (case List.find (fn {id, ...} => HsModules.moduleName id = "Prelude") modules of
             SOME {id, ...} => id
           | NONE => "haskell98:Prelude")
      val ds = collect modules
      val () = inferKinds (Vector.fromList ds)
      val () = synonyms ds
      val () = datatypes ds
      val () = classes ds
      val () = if M.member (!C.classes, T.idKey (preludeId "Num")) then C.numId := SOME (preludeId "Num") else ()
      val () = written modules
      val () = tuples ()
      val () = derived ds
      val () = superclasses ()
    in
      defaultDecls modules
    end
end
