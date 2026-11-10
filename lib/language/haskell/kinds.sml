(* Implements: HS_KINDS *)
structure HsKinds :> HS_KINDS =
struct
  structure A = HsAst
  structure T = HsTypes
  structure M = HsStringMap

  type tycon = {key : string, kind : T.kind, params : int, synonym : T.ty option, cons : string list, newtype : bool}
  type env = tycon M.map

  fun keyOf (A.Name (_, {qual, name})) =
    if qual = "" then (if name = "(->)" then T.arrowCon else name)
    else HsModules.key {space = HsModules.Type, home = qual, name = name}

  fun conKey (A.Name (_, {qual, name})) =
    if qual = "" then name else HsModules.key {space = HsModules.Value, home = qual, name = name}

  fun find (env, key) =
    case M.find (env, key) of
      SOME t => SOME t
    | NONE =>
        Option.map (fn k => {key = key, kind = k, params = 0, synonym = NONE, cons = [], newtype = false})
          (T.builtinKind key)

  fun spanOfTy (A.T ({span, ...}, _)) = span

  (* a type as a message shows it: names without their modules *)
  fun showTy (A.T (_, x)) =
    case x of
      A.TVar (A.Name (_, {name, ...})) => name
    | A.TCon (A.Name (_, {name, ...})) => name
    | A.TApp (f, a) => showTy f ^ " " ^ showAtom a
    | A.TFun (a, b) => showAtom a ^ " -> " ^ showTy b
    | A.TList t => "[" ^ showTy t ^ "]"
    | A.TTuple ts => "(" ^ String.concatWith ", " (List.map showTy ts) ^ ")"
    | A.TParen t => "(" ^ showTy t ^ ")"
  and showAtom (t as A.T (_, x)) =
    case x of
      A.TApp _ => "(" ^ showTy t ^ ")"
    | A.TFun _ => "(" ^ showTy t ^ ")"
    | _ => showTy t

  fun tyVars t =
    let
      fun go (A.T (_, x), acc) =
        case x of
          A.TVar (A.Name (_, {name, ...})) => if List.exists (fn v => v = name) acc then acc else acc @ [name]
        | A.TCon _ => acc
        | A.TApp (f, a) => go (a, go (f, acc))
        | A.TFun (a, b) => go (b, go (a, acc))
        | A.TList t => go (t, acc)
        | A.TTuple ts => List.foldl go acc ts
        | A.TParen t => go (t, acc)
    in
      go (t, [])
    end

  (* the class assertions of a context *)
  fun assertions (A.T (_, x)) =
    case x of
      A.TTuple ts => ts
    | A.TParen t => assertions t
    | _ => [A.T (A.noAnn, x)]

  fun assertionsOf ctx = case ctx of NONE => [] | SOME t => (case t of A.T (_, A.TTuple ts) => ts | _ => [t])

  fun splitAssertion (t as A.T (a, x)) =
    case x of
      A.TApp (A.T (_, A.TCon c), arg) => SOME (c, arg)
    | A.TParen t' => splitAssertion t'
    | _ => NONE

  (* ---- kinds of types ---- *)

  type kenv = {env : env, classKind : string -> T.kind option, vars : T.kind M.map ref}

  fun err (span, msg) = raise HsSource.Error (span, msg)

  fun headName (A.T (_, x)) =
    case x of
      A.TApp (f, _) => headName f
    | A.TParen t => headName t
    | A.TCon (A.Name (_, {name, ...})) => SOME name
    | _ => NONE

  fun kindOf ({env, classKind, vars} : kenv) t =
    let
      (* a synonym is applied to all its parameters (4.2.2) *)
      fun synonymApplied (A.T ({span, ...}, x), args) =
        case x of
          A.TApp (f, _) => synonymApplied (f, args + 1)
        | A.TParen t => synonymApplied (t, args)
        | A.TCon n =>
            (case find (env, keyOf n) of
               SOME {synonym = SOME _, params, ...} =>
                 if args < params then
                   err (span, "the type synonym `" ^ (case n of A.Name (_, {name, ...}) => name) ^ "` is applied to " ^
                              Int.toString args ^ " of its " ^ Int.toString params ^ " parameters: a synonym is always " ^
                              "applied to all of them")
                 else ()
             | _ => ())
        | _ => ()
      fun go t = (synonymApplied (t, 0); kind t)
      (* the kind of a type at the head of an application, or alone *)
      and kind (t as A.T ({span, ...}, x)) =
        case x of
          A.TVar (A.Name (_, {name, ...})) =>
            (case M.find (!vars, name) of
               SOME k => k
             | NONE => let val k = T.newKind () in vars := M.insert (!vars, name, k); k end)
        | A.TCon n =>
            (case find (env, keyOf n) of
               SOME {kind, ...} => kind
             | NONE => T.newKind ())
        | A.TApp (f, a) =>
            let
              val kf = kind f
              val ka = go a
              val r = T.newKind ()
            in
              T.unifyKind (kf, T.KFun (ka, r))
              handle T.KindMismatch _ =>
                err (spanOfTy f,
                     case T.kindRepr kf of
                       T.KStar => (case headName f of
                                     SOME h => "`" ^ h ^ "` is applied to more types than its kind takes: `" ^ showTy f ^
                                               "` is of kind * and is applied to `" ^ showTy a ^ "`"
                                   | NONE => "the type `" ^ showTy f ^ "` of kind * is applied to a type, as only a type constructor can be")
                     | _ => "the type `" ^ showTy f ^ "`, of kind " ^ T.showKind kf ^ ", is applied to `" ^ showTy a ^
                            "`, of kind " ^ T.showKind ka);
              r
            end
        | A.TFun (a, b) => (check (a, T.KStar); check (b, T.KStar); T.KStar)
        | A.TList t => (check (t, T.KStar); T.KStar)
        | A.TTuple ts => (List.app (fn t => check (t, T.KStar)) ts; T.KStar)
        | A.TParen t => kind t
      and check (t, want) =
        let val k = go t
        in
          T.unifyKind (k, want)
          handle T.KindMismatch _ =>
            err (spanOfTy t, "the type `" ^ showTy t ^ "` has kind " ^ T.showKind k ^ ", where a type of kind " ^
                             T.showKind want ^ " is wanted")
        end
    in
      go t
    end

  fun checkType (kenv : kenv) (t, want) =
    let val k = kindOf kenv t
    in
      T.unifyKind (k, want)
      handle T.KindMismatch _ =>
        err (spanOfTy t, "the type `" ^ showTy t ^ "` has kind " ^ T.showKind k ^ ", where a type of kind " ^
                         T.showKind want ^ " is wanted")
    end

  fun checkContext (kenv as {classKind, ...} : kenv) ctx =
    List.app
      (fn a =>
         case splitAssertion a of
           SOME (c, arg) =>
             (case classKind (keyOf c) of
                SOME k => checkType kenv (arg, k)
              | NONE => ignore (kindOf kenv arg))
         | NONE => ())
      (assertionsOf ctx)

  (* ---- types made the checker's ---- *)

  fun convert (env, var) t =
    let
      fun go (t as A.T ({span, ...}, x)) =
        case x of
          A.TApp _ => app (t, [])
        | A.TCon _ => app (t, [])
        | A.TVar (A.Name (_, {name, ...})) => var name
        | A.TFun (a, b) => T.fn_ (go a, go b)
        | A.TList t => T.list (go t)
        | A.TTuple ts => T.tuple (List.map go ts)
        | A.TParen t => go t
      and app (A.T ({span, ...}, x), args) =
        case x of
          A.TApp (f, a) => app (f, a :: args)
        | A.TParen t => app (t, args)
        | A.TCon n =>
            let val key = keyOf n
            in
              case find (env, key) of
                SOME {synonym = SOME rhs, params, ...} =>
                  if length args < params then
                    err (span, "the type synonym `" ^ T.nameOfKey key ^ "` is applied to " ^ Int.toString (length args) ^
                               " of its " ^ Int.toString params ^ " parameters: a synonym is always applied to all of them")
                  else
                    T.apply (T.substGen (List.map go (List.take (args, params)), rhs), List.map go (List.drop (args, params)))
              | _ => T.apply (T.TCon key, List.map go args)
            end
        | _ => T.apply (go (A.T (A.noAnn, x)), List.map go args)
    in
      go t
    end

  fun contextPreds (env, var) ctx =
    List.mapPartial
      (fn a => case splitAssertion a of
                 SOME (c, arg) => SOME {cls = keyOf c, ty = convert (env, var) arg}
               | NONE => NONE)
      (assertionsOf ctx)

  (* ---- kind inference over a unit's declarations ---- *)

  fun declKey (home, A.D (_, x)) =
    case x of
      A.DData (_, c, _, _, _) => SOME (keyOf c)
    | A.DNewtype (_, c, _, _, _) => SOME (keyOf c)
    | A.DType (c, _, _) => SOME (keyOf c)
    | A.DClass (_, c, _, _) => SOME (keyOf c)
    | _ => NONE

  (* the type constructors and classes a declaration names *)
  fun mentions (A.D (_, x)) =
    let
      fun ty (A.T (_, t), acc) =
        case t of
          A.TCon n => keyOf n :: acc
        | A.TApp (f, a) => ty (a, ty (f, acc))
        | A.TFun (a, b) => ty (b, ty (a, acc))
        | A.TList t => ty (t, acc)
        | A.TTuple ts => List.foldl ty acc ts
        | A.TParen t => ty (t, acc)
        | A.TVar _ => acc
      fun ctx (c, acc) = case c of SOME t => ty (t, acc) | NONE => acc
      fun constr (A.C (_, k), acc) =
        case k of
          A.CPlain (_, args) => List.foldl (fn ((_, t), acc) => ty (t, acc)) acc args
        | A.CInfix ((_, l), _, (_, r)) => ty (r, ty (l, acc))
        | A.CRec (_, fs) => List.foldl (fn (A.Field (_, _, _, t), acc) => ty (t, acc)) acc fs
    in
      case x of
        A.DData (cx, _, _, cs, _) => List.foldl constr (ctx (cx, [])) cs
      | A.DNewtype (cx, _, _, c, _) => constr (c, ctx (cx, []))
      | A.DType (_, _, t) => ty (t, [])
      | A.DClass (cx, _, _, body) =>
          List.foldl (fn (A.D (_, A.DSig (_, c, t)), acc) => ty (t, ctx (c, acc)) | (_, acc) => acc) (ctx (cx, []))
            (getOpt (body, []))
      | _ => []
    end

  fun nameText (A.Name (_, {name, ...})) = name

  fun infer {env, classKind, decls} =
    let
      val errors : (HsSource.span * string) list ref = ref []
      val typeDecls = List.mapPartial (fn (home, d) => Option.map (fn k => (k, (home, d))) (declKey (home, d))) decls
      val byKey = List.foldl (fn ((k, hd), m) => M.insert (m, k, hd)) M.empty typeDecls
      val groups = HsScc.sccs (List.map #1 typeDecls, fn k => mentions (#2 (valOf (M.find (byKey, k)))))
      val env = ref env
      val classKinds : T.kind M.map ref = ref M.empty
      fun ck key = case M.find (!classKinds, key) of SOME k => SOME k | NONE => classKind key
      fun guard f = f () handle HsSource.Error e => errors := e :: !errors
      fun arrows (ks, r) = List.foldr T.KFun r ks
      fun group keys =
        let
          (* provisional kinds *)
          val provisional =
            List.map
              (fn k =>
                 let val (_, A.D (_, x)) = valOf (M.find (byKey, k))
                 in
                   case x of
                     A.DData (_, _, vs, _, _) => (k, List.map (fn _ => T.newKind ()) vs, T.KStar, false)
                   | A.DNewtype (_, _, vs, _, _) => (k, List.map (fn _ => T.newKind ()) vs, T.KStar, false)
                   | A.DType (_, vs, _) => (k, List.map (fn _ => T.newKind ()) vs, T.newKind (), false)
                   | A.DClass _ => (k, [T.newKind ()], T.KStar, true)
                   | _ => (k, [], T.KStar, false)
                 end)
              keys
          val () =
            List.app
              (fn (k, ps, r, isClass) =>
                 if isClass then classKinds := M.insert (!classKinds, k, hd ps)
                 else env := M.insert (!env, k, {key = k, kind = arrows (ps, r), params = length ps, synonym = NONE, cons = [],
                                                 newtype = false}))
              provisional
          fun vars (names, ks) =
            ref (ListPair.foldl (fn (n, k, m) => M.insert (m, nameText n, k)) M.empty (names, ks))
          fun kenv vs : kenv = {env = !env, classKind = ck, vars = vs}
          fun constrTypes (A.C (_, k)) =
            case k of
              A.CPlain (_, args) => List.map #2 args
            | A.CInfix ((_, l), _, (_, r)) => [l, r]
            | A.CRec (_, fs) => List.map (fn A.Field (_, _, _, t) => t) fs
          val () =
            List.app
              (fn (k, ps, r, _) =>
                 let val (_, A.D (_, x)) = valOf (M.find (byKey, k))
                 in
                   case x of
                     A.DData (cx, _, vs, cs, _) =>
                       let val vm = vars (vs, ps)
                       in
                         guard (fn () => checkContext (kenv vm) cx);
                         List.app (fn c => List.app (fn t => guard (fn () => checkType (kenv vm) (t, T.KStar))) (constrTypes c)) cs
                       end
                   | A.DNewtype (cx, _, vs, c, _) =>
                       let val vm = vars (vs, ps)
                       in
                         guard (fn () => checkContext (kenv vm) cx);
                         List.app (fn t => guard (fn () => checkType (kenv vm) (t, T.KStar))) (constrTypes c)
                       end
                   | A.DType (_, vs, t) => guard (fn () => checkType (kenv (vars (vs, ps))) (t, r))
                   | A.DClass (cx, _, v, body) =>
                       (guard (fn () => checkContext (kenv (vars ([v], ps))) cx);
                        List.app
                          (fn A.D (_, A.DSig (_, c, t)) =>
                                let val vm = vars ([v], ps)
                                in guard (fn () => (checkContext (kenv vm) c; checkType (kenv vm) (t, T.KStar))) end
                            | _ => ())
                          (getOpt (body, [])))
                   | _ => ()
                 end)
              provisional
          (* every kind left open is * *)
          val () =
            List.app
              (fn (k, ps, r, isClass) =>
                 if isClass then classKinds := M.insert (!classKinds, k, T.defaultKind (hd ps))
                 else
                   let val {params, ...} = valOf (M.find (!env, k))
                   in
                     env := M.insert (!env, k, {key = k, kind = T.defaultKind (arrows (ps, r)), params = params, synonym = NONE,
                                                cons = [], newtype = false})
                   end)
              provisional
        in
          ()
        end
      val () = List.app group groups
      (* the synonyms' right-hand sides and the constructors, kinds known *)
      fun finish (k, (home, A.D ({span, ...}, x))) =
        case x of
          A.DType (_, vs, t) =>
            let
              val names = List.map nameText vs
              fun var n =
                case List.find (fn (m, _) => m = n) (ListPair.zip (names, List.tabulate (length names, fn i => i))) of
                  SOME (_, i) => T.TGen i
                | NONE => raise HsSource.Error (span, "the type variable `" ^ n ^ "` is not a parameter of the synonym")
              val rhs = convert (!env, var) t
              val {kind, params, ...} = valOf (M.find (!env, k))
            in
              env := M.insert (!env, k, {key = k, kind = kind, params = params, synonym = SOME rhs, cons = [], newtype = false})
            end
        | A.DData (_, _, _, cs, _) =>
            let val {kind, params, ...} = valOf (M.find (!env, k))
            in
              env := M.insert (!env, k, {key = k, kind = kind, params = params, synonym = NONE,
                                         cons = List.map (fn A.C (_, c) =>
                                                           conKey (case c of A.CPlain (n, _) => n | A.CInfix (_, n, _) => n
                                                                           | A.CRec (n, _) => n)) cs,
                                         newtype = false})
            end
        | A.DNewtype (_, _, _, A.C (_, c), _) =>
            let val {kind, params, ...} = valOf (M.find (!env, k))
            in
              env := M.insert (!env, k, {key = k, kind = kind, params = params, synonym = NONE,
                                         cons = [conKey (case c of A.CPlain (n, _) => n | A.CInfix (_, n, _) => n
                                                                 | A.CRec (n, _) => n)],
                                         newtype = true})
            end
        | _ => ()
      (* synonyms in dependency order, so each expands those before it *)
      val () =
        List.app
          (fn g =>
             case g of
               [k] =>
                 let val hd = valOf (M.find (byKey, k))
                 in
                   case hd of
                     (_, A.D ({span, ...}, A.DType _)) =>
                       if List.exists (fn m => m = k) (mentions (#2 hd)) then
                         errors := (span, "the type synonym `" ^ T.nameOfKey k ^ "` is defined by itself") :: !errors
                       else guard (fn () => finish (k, hd))
                   | _ => guard (fn () => finish (k, hd))
                 end
             | ks =>
                 let
                   fun isSyn k = case M.find (byKey, k) of SOME (_, A.D (_, A.DType _)) => true | _ => false
                   val syns = List.filter isSyn ks
                   val synGroups = HsScc.sccs (syns, fn k => List.filter isSyn (mentions (#2 (valOf (M.find (byKey, k))))))
                 in
                   List.app
                     (fn [k] =>
                           let val hd as (_, A.D ({span, ...}, _)) = valOf (M.find (byKey, k))
                           in
                             if List.exists (fn m => m = k) (mentions (#2 hd)) then
                               errors := (span, "the type synonym `" ^ T.nameOfKey k ^ "` is defined by itself") :: !errors
                             else guard (fn () => finish (k, hd))
                           end
                       | cyc =>
                           List.app
                             (fn k =>
                                let val (_, A.D ({span, ...}, _)) = valOf (M.find (byKey, k))
                                in
                                  errors := (span, "the type synonym `" ^ T.nameOfKey k ^ "` is in a cycle of synonyms, " ^
                                                   "which no data type or newtype breaks") :: !errors
                                end)
                             cyc)
                     synGroups;
                   List.app (fn k => if isSyn k then () else guard (fn () => finish (k, valOf (M.find (byKey, k))))) ks
                 end)
          groups
    in
      {env = !env, classKinds = M.listItems (!classKinds), errors = List.rev (!errors)}
    end
end
