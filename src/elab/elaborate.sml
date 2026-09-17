(* Elaboration: type inference for the Core language with namespace-only
   structures. Fills the annotation slots in the AST for the translator. *)
structure Elaborate =
struct
  open Ast Types Env

  val stampCounter = ref 0
  fun freshStamp () = let val s = !stampCounter in stampCounter := s + 1; s end

  val allowPrim = ref false

  (* overloaded operator variables and flexible records awaiting resolution *)
  val pendingOverloads : tvar ref list ref = ref []
  val pendingFlex : (tvar ref * span) list ref = ref []

  fun err (sp, msg) = Error.error (sp, msg)

  fun unifyAt (sp, t1, t2, context) =
    Unify.unify (t1, t2)
    handle Unify.Unify reason =>
      let
        val names = ref []
        val s1 = toStringWith names t1
        val s2 = toStringWith names t2
      in
        err (sp, context ^ ": type mismatch between " ^ s1 ^ " and " ^ s2 ^ " (" ^ reason ^ ")")
      end

  fun registerOverloads t =
    case prune t of
      TVar r => (case !r of Unbound {kind = KOverload _, ...} => pendingOverloads := r :: !pendingOverloads | _ => ())
    | TCon (_, args) => List.app registerOverloads args
    | TRecord fields => List.app (fn (_, a) => registerOverloads a) fields
    | TArrow (a, b) => (registerOverloads a; registerOverloads b)

  fun resolvePending () =
    (List.app (fn r =>
                 case !r of
                   Unbound {kind = KOverload names, ...} =>
                     let
                       val default =
                         if List.exists (fn n => n = "int") names then intTy
                         else if List.exists (fn n => n = "real") names then realTy
                         else if List.exists (fn n => n = "word") names then wordTy
                         else Error.bug "resolvePending: empty overload class"
                     in Unify.unify (TVar r, default) end
                 | _ => ()) (!pendingOverloads);
     pendingOverloads := [];
     List.app (fn (r, sp) =>
                 case !r of
                   Unbound {kind = KFlex _, ...} =>
                     err (sp, "unresolved flexible record: cannot determine the full set of fields")
                 | _ => ()) (!pendingFlex);
     pendingFlex := [])

  fun checkDupLabels (fields : (string * 'a) list, sp) =
    let
      fun go [] = ()
        | go ((l, _) :: rest) =
          if List.exists (fn (l2, _) => l2 = l) rest then err (sp, "duplicate record label '" ^ l ^ "'") else go rest
    in go fields end

  fun sconTy sc =
    case sc of
      SInt _ => intTy | SWord _ => wordTy | SReal _ => realTy | SString _ => stringTy | SChar _ => charTy

  type scope = ty StringMap.map ref

  fun newScope (outer : scope, tyvars : string list, level) : scope =
    let
      val m = List.foldl (fn (v, m) =>
                            StringMap.insert (m, v, freshTvar (level, KPlain, String.isPrefix "''" v)))
                         (!outer) tyvars
    in ref m end

  (* ------------------------------------------------------------------ *)
  (* Types                                                                *)
  fun elabTy (env, scope : scope, level, t : Ast.ty) : ty =
    case t of
      TyVar (v, _) =>
        (case StringMap.find (!scope, v) of
           SOME t => t
         | NONE =>
           let val t = freshTvar (level, KPlain, String.isPrefix "''" v)
           in scope := StringMap.insert (!scope, v, t); t end)
    | TyRecord (fields, sp) =>
        (checkDupLabels (fields, sp);
         TRecord (sortFields (List.map (fn (l, t) => (l, elabTy (env, scope, level, t))) fields)))
    | TyTuple (ts, _) => tupleTy (List.map (fn t => elabTy (env, scope, level, t)) ts)
    | TyCon (args, longid, sp) =>
        let val args' = List.map (fn t => elabTy (env, scope, level, t)) args
        in
          case findTy (env, longid) of
            NONE => err (sp, "unbound type constructor: " ^ longidToString longid)
          | SOME (Tycon {tycon, ...}) =>
              if List.length args' <> #arity tycon then
                err (sp, "type constructor " ^ #name tycon ^ " expects " ^ Int.toString (#arity tycon)
                         ^ " argument(s) but got " ^ Int.toString (List.length args'))
              else TCon (tycon, args')
          | SOME (Abbrev {params, body}) =>
              if List.length args' <> List.length params then
                err (sp, "type abbreviation " ^ longidToString longid ^ " expects " ^ Int.toString (List.length params)
                         ^ " argument(s) but got " ^ Int.toString (List.length args'))
              else Unify.substitute (params, args', body)
        end
    | TyArrow (a, b, _) => TArrow (elabTy (env, scope, level, a), elabTy (env, scope, level, b))

  (* A generic parameter variable for type abbreviations and datatypes. *)
  fun paramVar (name : string) : int * ty =
    let val t = freshTvar (genericLevel, KPlain, String.isPrefix "''" name)
    in
      case t of
        TVar (ref (Unbound {id, ...})) => (id, t)
      | _ => Error.bug "paramVar"
    end

  (* ------------------------------------------------------------------ *)
  (* Patterns                                                             *)
  fun bindingsToEnv (bindings : (string * valstatus) list) =
    List.foldl (fn ((n, v), e) => bindVal (e, n, v)) Env.empty bindings

  fun lookupCon (env, longid, sp) =
    case findVal (env, longid) of
      SOME (Con c) => SOME (Con c)
    | SOME (Exn e) => SOME (Exn e)
    | SOME _ => NONE
    | NONE =>
        (case longid of
           ([], _) => NONE
         | _ => err (sp, "unbound constructor: " ^ longidToString longid))

  fun elabPat (env, level, scope, isGlobal, p : pat, bound : (string * span) list ref)
      : ty * (string * valstatus) list =
    let
      fun bindVar (name, sp) =
        (if List.exists (fn (n, _) => n = name) (!bound) then
           err (sp, "duplicate variable '" ^ name ^ "' in pattern")
         else bound := (name, sp) :: !bound;
         let
           val stamp = freshStamp ()
           val t = fresh level
         in (stamp, t, (name, Val {scheme = t, stamp = stamp, global = isGlobal})) end)
      fun elab p =
        case p of
          PWild _ => (fresh level, [])
        | PScon (sc, _) => (sconTy sc, [])
        | PVar (longid as (path, name), slot, sp) =>
            (case lookupCon (env, longid, sp) of
               SOME (Con {scheme, info}) =>
                 if #hasArg info then err (sp, "constructor " ^ name ^ " expects an argument")
                 else (slot := SOME (PICon info); (Unify.instantiate (level, scheme), []))
             | SOME (Exn {ty, info}) =>
                 if #hasArg info then err (sp, "exception constructor " ^ name ^ " expects an argument")
                 else (slot := SOME (PIExn info); (ty, []))
             | _ =>
                 (case path of
                    [] => let val (stamp, t, b) = bindVar (name, sp)
                          in slot := SOME (PIVar (stamp, isGlobal)); (t, [b]) end
                  | _ => err (sp, longidToString longid ^ " is not a constructor")))
        | PRecord (fields, flex, slot, sp) =>
            let
              val () = checkDupLabels (fields, sp)
              val results = List.map (fn (l, p) => let val (t, bs) = elab p in ((l, t), bs) end) fields
              val ftys = sortFields (List.map #1 results)
              val bindings = List.concat (List.map #2 results)
            in
              if flex then
                let val r = freshTvar (level, KFlex ftys, false)
                in
                  case r of
                    TVar rr => pendingFlex := (rr, sp) :: !pendingFlex
                  | _ => ();
                  slot := SOME r;
                  (r, bindings)
                end
              else (TRecord ftys, bindings)
            end
        | PTuple ([], _) => (unitTy, [])
        | PTuple (ps, _) =>
            let val results = List.map elab ps
            in (tupleTy (List.map #1 results), List.concat (List.map #2 results)) end
        | PList (ps, sp) =>
            let
              val a = fresh level
              val results = List.map (fn p => let val (t, bs) = elab p
                                              in unifyAt (spanOfPat p, a, t, "list pattern element"); bs end) ps
            in (listTy a, List.concat results) end
        | PApp (longid, slot, arg, sp) =>
            let
              val conTy =
                case lookupCon (env, longid, sp) of
                  SOME (Con {scheme, info}) =>
                    if not (#hasArg info) then err (sp, "constructor " ^ #name info ^ " takes no argument")
                    else (slot := SOME (PICon info); Unify.instantiate (level, scheme))
                | SOME (Exn {ty, info}) =>
                    if not (#hasArg info) then err (sp, "exception constructor " ^ #name info ^ " takes no argument")
                    else (slot := SOME (PIExn info); ty)
                | _ => err (sp, longidToString longid ^ " is not a constructor")
              val (targ, bs) = elab arg
            in
              case conTy of
                TArrow (dom, cod) => (unifyAt (spanOfPat arg, dom, targ, "constructor argument"); (cod, bs))
              | _ => Error.bug "constructor with argument has non-arrow type"
            end
        | PTyped (p, t, sp) =>
            let
              val (tp, bs) = elab p
              val ta = elabTy (env, scope, level, t)
            in unifyAt (sp, ta, tp, "pattern type annotation"); (ta, bs) end
        | PLayered (name, tyopt, p, slot, sp) =>
            let
              val (stamp, tv, b) = bindVar (name, sp)
              val () = slot := SOME (PIVar (stamp, isGlobal))
              val (tp, bs) = elab p
              val () = unifyAt (sp, tv, tp, "layered pattern")
              val () = case tyopt of
                         NONE => ()
                       | SOME t => unifyAt (sp, elabTy (env, scope, level, t), tv, "pattern type annotation")
            in (tv, b :: bs) end
    in
      elab p
    end

  (* ------------------------------------------------------------------ *)
  (* Expressions                                                          *)
  fun nonexpansive e =
    case e of
      EScon _ => true
    | EVar _ => true
    | EFn _ => true
    | EPrim _ => true
    | ESelect _ => true
    | ETuple (es, _) => List.all nonexpansive es
    | ERecord (fs, _) => List.all (fn (_, e) => nonexpansive e) fs
    | EList (es, _) => List.all nonexpansive es
    | ETyped (e, _, _) => nonexpansive e
    | EApp (EVar (_, slot, _), a, _) =>
        (case !slot of
           SOME (VCon info) => not (#isRef info) andalso nonexpansive a
         | SOME (VExn _) => nonexpansive a
         | _ => false)
    | _ => false

  fun elabExp (env, level, scope : scope, e : exp) : ty =
    case e of
      EScon (sc, _) => sconTy sc
    | EVar (longid, slot, sp) =>
        (case findVal (env, longid) of
           NONE => err (sp, "unbound variable or constructor: " ^ longidToString longid)
         | SOME (Val {scheme, stamp, global}) =>
             (slot := SOME (if global then VGlobal stamp else VLocal stamp);
              Unify.instantiate (level, scheme))
         | SOME (Con {scheme, info}) => (slot := SOME (VCon info); Unify.instantiate (level, scheme))
         | SOME (Exn {ty, info}) => (slot := SOME (VExn info); ty)
         | SOME (Prim {scheme, name}) =>
             let val t = Unify.instantiate (level, scheme)
             in registerOverloads t; slot := SOME (VBuiltin (name, t)); t end)
    | ERecord (fields, sp) =>
        (checkDupLabels (fields, sp);
         TRecord (sortFields (List.map (fn (l, e) => (l, elabExp (env, level, scope, e))) fields)))
    | ETuple ([], _) => unitTy
    | ETuple (es, _) => tupleTy (List.map (fn e => elabExp (env, level, scope, e)) es)
    | ESelect (lab, slot, sp) =>
        let
          val a = fresh level
          val r = freshTvar (level, KFlex [(lab, a)], false)
        in
          case r of TVar rr => pendingFlex := (rr, sp) :: !pendingFlex | _ => ();
          slot := SOME r;
          TArrow (r, a)
        end
    | EList (es, _) =>
        let val a = fresh level
        in
          List.app (fn e => unifyAt (spanOfExp e, a, elabExp (env, level, scope, e), "list element")) es;
          listTy a
        end
    | ESeq (es, _) =>
        List.foldl (fn (e, _) => elabExp (env, level, scope, e)) unitTy es
    | ELet (decs, body, _) =>
        let val delta = elabDecs (env, level, false, scope, decs)
        in elabExp (plus (env, delta), level, scope, body) end
    | EApp (f, a, sp) =>
        let
          val tf = elabExp (env, level, scope, f)
          val ta = elabExp (env, level, scope, a)
        in
          case prune tf of
            TArrow (dom, cod) => (unifyAt (spanOfExp a, dom, ta, "function argument"); cod)
          | _ =>
            let val r = fresh level
            in unifyAt (sp, tf, TArrow (ta, r), "function application"); r end
        end
    | ETyped (e, t, sp) =>
        let
          val te = elabExp (env, level, scope, e)
          val ta = elabTy (env, scope, level, t)
        in unifyAt (sp, ta, te, "type annotation"); ta end
    | EAndalso (a, b, _) =>
        (unifyAt (spanOfExp a, boolTy, elabExp (env, level, scope, a), "operand of andalso");
         unifyAt (spanOfExp b, boolTy, elabExp (env, level, scope, b), "operand of andalso");
         boolTy)
    | EOrelse (a, b, _) =>
        (unifyAt (spanOfExp a, boolTy, elabExp (env, level, scope, a), "operand of orelse");
         unifyAt (spanOfExp b, boolTy, elabExp (env, level, scope, b), "operand of orelse");
         boolTy)
    | EHandle (e, rules, _) =>
        let val te = elabExp (env, level, scope, e)
        in elabMatch (env, level, scope, rules, exnTy, te); te end
    | ERaise (e, _) =>
        (unifyAt (spanOfExp e, exnTy, elabExp (env, level, scope, e), "argument of raise"); fresh level)
    | EIf (c, t, e, _) =>
        let
          val () = unifyAt (spanOfExp c, boolTy, elabExp (env, level, scope, c), "condition of if")
          val tt = elabExp (env, level, scope, t)
          val te = elabExp (env, level, scope, e)
        in unifyAt (spanOfExp e, tt, te, "branches of if"); tt end
    | EWhile (c, b, _) =>
        (unifyAt (spanOfExp c, boolTy, elabExp (env, level, scope, c), "condition of while");
         ignore (elabExp (env, level, scope, b));
         unitTy)
    | ECase (e, rules, _) =>
        let
          val te = elabExp (env, level, scope, e)
          val res = fresh level
        in elabMatch (env, level, scope, rules, te, res); res end
    | EFn (rules, _) =>
        let
          val arg = fresh level
          val res = fresh level
        in elabMatch (env, level, scope, rules, arg, res); TArrow (arg, res) end
    | EPrim (name, t, sp) =>
        if not (!allowPrim) then err (sp, "_prim is only allowed when compiling with --allow-prim")
        else
          (case Prims.find name of
             NONE => err (sp, "unknown primitive '" ^ name ^ "'")
           | SOME _ => elabTy (env, scope, level, t))

  and elabMatch (env, level, scope, rules : mrule list, argTy, resTy) =
    List.app (fn (p, e) =>
                let
                  val bound = ref []
                  val (tp, bindings) = elabPat (env, level, scope, false, p, bound)
                  val () = unifyAt (spanOfPat p, argTy, tp, "pattern")
                  val env' = plus (env, bindingsToEnv bindings)
                  val te = elabExp (env', level, scope, e)
                in unifyAt (spanOfExp e, resTy, te, "result of match rule") end) rules

  (* ------------------------------------------------------------------ *)
  (* Declarations. Return the environment delta.                          *)
  and elabDecs (env, level, top, scope, decs : dec list) : env =
    let
      fun go ([], _, delta) = delta
        | go (d :: rest, env, delta) =
          let val d' = elabDec (env, level, top, scope, d)
          in go (rest, plus (env, d'), plus (delta, d')) end
    in go (decs, env, Env.empty) end

  and elabDec (env, level, top, outerScope : scope, d : dec) : env =
    case d of
      DVal (tvs, binds, sp) =>
        let
          val scope = newScope (outerScope, tvs, level + 1)
          val allBindings =
            List.map (fn (p, e) =>
                         let
                           val te = elabExp (env, level + 1, scope, e)
                           val bound = ref []
                           val (tp, bindings) = elabPat (env, level + 1, scope, top, p, bound)
                           val () = unifyAt (spanOfPat p, tp, te, "val binding")
                           val () = if nonexpansive e then Unify.generalize (level, tp)
                                    else Unify.lowerLevels (level, tp)
                         in bindings end) binds
          val flat = List.concat allBindings
          fun checkDups [] = ()
            | checkDups ((n, _) :: rest) =
              if List.exists (fn (m, _) => m = n) rest then err (sp, "duplicate variable '" ^ n ^ "' in val declaration")
              else checkDups rest
        in checkDups flat; bindingsToEnv flat end
    | DValRec (tvs, binds, sp) =>
        let
          val scope = newScope (outerScope, tvs, level + 1)
          fun stripVar (PVar (([], name), slot, sp)) = (name, slot, NONE, sp)
            | stripVar (PTyped (PVar (([], name), slot, sp), t, _)) = (name, slot, SOME t, sp)
            | stripVar p = err (spanOfPat p, "val rec requires a variable on the left-hand side")
          fun isFn (EFn _) = true
            | isFn (ETyped (e, _, _)) = isFn e
            | isFn _ = false
          val prepared =
            List.map (fn (p, e) =>
                         let
                           val (name, slot, tyopt, psp) = stripVar p
                           val () = if isFn e then () else err (spanOfExp e, "val rec right-hand side must be a function expression")
                           val stamp = freshStamp ()
                           val tv = fresh (level + 1)
                           val () = slot := SOME (PIVar (stamp, top))
                         in (name, Val {scheme = tv, stamp = stamp, global = top}, tv, tyopt, e, psp) end) binds
          val env' = plus (env, bindingsToEnv (List.map (fn (n, v, _, _, _, _) => (n, v)) prepared))
        in
          List.app (fn (name, _, tv, tyopt, e, psp) =>
                       let
                         val () = case tyopt of
                                    NONE => ()
                                  | SOME t => unifyAt (psp, elabTy (env, scope, level + 1, t), tv, "val rec type annotation")
                         val te = elabExp (env', level + 1, scope, e)
                       in unifyAt (spanOfExp e, tv, te, "val rec binding") end) prepared;
          List.app (fn (_, _, tv, _, _, _) => Unify.generalize (level, tv)) prepared;
          bindingsToEnv (List.map (fn (n, v, _, _, _, _) => (n, v)) prepared)
        end
    | DFun (tvs, fundefs, sp) =>
        let
          val scope = newScope (outerScope, tvs, level + 1)
          val prepared =
            List.map (fn (f : fundef) =>
                         let
                           val stamp = freshStamp ()
                           val tv = fresh (level + 1)
                           val () = #info f := SOME (PIVar (stamp, top))
                         in (#name f, Val {scheme = tv, stamp = stamp, global = top}, tv, f) end) fundefs
          fun checkDups [] = ()
            | checkDups ((n, _, _, _) :: rest) =
              if List.exists (fn (m, _, _, _) => m = n) rest then err (sp, "duplicate function name '" ^ n ^ "'")
              else checkDups rest
          val () = checkDups prepared
          val env' = plus (env, bindingsToEnv (List.map (fn (n, v, _, _) => (n, v)) prepared))
        in
          List.app (fn (name, _, tv, f) =>
                       List.app (fn {pats, resty, body} =>
                                    let
                                      val bound = ref []
                                      val results = List.map (fn p => elabPat (env', level + 1, scope, false, p, bound)) pats
                                      val argTys = List.map #1 results
                                      val bindings = List.concat (List.map #2 results)
                                      val env'' = plus (env', bindingsToEnv bindings)
                                      val tbody = elabExp (env'', level + 1, scope, body)
                                      val () = case resty of
                                                 NONE => ()
                                               | SOME t => unifyAt (spanOfExp body, elabTy (env, scope, level + 1, t), tbody, "function result type annotation")
                                      val clauseTy = List.foldr TArrow tbody argTys
                                    in unifyAt (#span f, tv, clauseTy, "clauses of function " ^ name) end)
                                (#clauses f)) prepared;
          List.app (fn (_, _, tv, _) => Unify.generalize (level, tv)) prepared;
          bindingsToEnv (List.map (fn (n, v, _, _) => (n, v)) prepared)
        end
    | DType (typbinds, _) =>
        List.foldl (fn (tb : typbind, delta) =>
                       let
                         val params = List.map paramVar (#tyvars tb)
                         val scope = ref (StringMap.fromList (ListPair.zip (#tyvars tb, List.map #2 params)))
                         val body = elabTy (env, scope, level, #ty tb)
                       in bindTy (delta, #name tb, Abbrev {params = List.map #1 params, body = body}) end)
                   Env.empty typbinds
    | DDatatype (datbinds, typbinds, sp) =>
        let
          val tycons = List.map (fn (db : datbind) => (db, freshTycon (#name db, List.length (#tyvars db)))) datbinds
          val env1 = List.foldl (fn ((db, tc), e) => bindTy (e, #name db, Tycon {tycon = tc, cons = []})) env tycons
          val abbrevs = elabDec (env1, level, top, outerScope, DType (typbinds, sp))
          val env2 = plus (env1, abbrevs)
          fun elabDatbind ((db : datbind, tc), delta) =
            let
              val params = List.map paramVar (#tyvars db)
              val scope = ref (StringMap.fromList (ListPair.zip (#tyvars db, List.map #2 params)))
              val resTy = TCon (tc, List.map #2 params)
              val ncons = List.length (#cons db)
              val cons =
                List.foldl (fn ((cname, argOpt, csp), (acc, i)) =>
                               let
                                 val () = if List.exists (fn (n, _) => n = cname) acc then
                                            err (csp, "duplicate constructor '" ^ cname ^ "'") else ()
                                 val scheme = case argOpt of
                                                NONE => resTy
                                              | SOME t => TArrow (elabTy (env2, scope, level, t), resTy)
                                 val info = {name = cname, tag = i, hasArg = isSome argOpt, ncons = ncons, isRef = false}
                               in ((cname, Con {scheme = scheme, info = info}) :: acc, i + 1) end)
                           ([], 0) (#cons db)
              val cons = List.rev (#1 cons)
              val delta = bindTy (delta, #name db, Tycon {tycon = tc, cons = cons})
            in List.foldl (fn ((n, v), d) => bindVal (d, n, v)) delta cons end
        in
          plus (abbrevs, List.foldl elabDatbind Env.empty tycons)
        end
    | DDatatypeRepl (name, longid, sp) =>
        (case findTy (env, longid) of
           SOME (Tycon {tycon, cons}) =>
             List.foldl (fn ((n, v), d) => bindVal (d, n, v))
                        (bindTy (Env.empty, name, Tycon {tycon = tycon, cons = cons})) cons
         | SOME (Abbrev _) => err (sp, longidToString longid ^ " is a type abbreviation, not a datatype")
         | NONE => err (sp, "unbound type constructor: " ^ longidToString longid))
    | DException (exbinds, _) =>
        List.foldl (fn (eb, delta) =>
                       case eb of
                         ExnDecl (name, tyopt, slot, sp) =>
                           let
                             val stamp = freshStamp ()
                             val scope = ref (!outerScope)
                             val ty = case tyopt of
                                        NONE => exnTy
                                      | SOME t => TArrow (elabTy (env, scope, level + 1, t), exnTy)
                             val info = {name = name, stamp = stamp, isGlobal = top, hasArg = isSome tyopt, builtin = NONE}
                           in slot := SOME (PIExn info); bindVal (delta, name, Exn {ty = ty, info = info}) end
                       | ExnRepl (name, longid, slot, sp) =>
                           (case findVal (env, longid) of
                              SOME (Exn {ty, info}) => (slot := SOME (PIExn info); bindVal (delta, name, Exn {ty = ty, info = info}))
                            | SOME _ => err (sp, longidToString longid ^ " is not an exception constructor")
                            | NONE => err (sp, "unbound exception constructor: " ^ longidToString longid)))
                   Env.empty exbinds
    | DLocal (d1, d2, _) =>
        let val delta1 = elabDecs (env, level, top, outerScope, d1)
        in elabDecs (plus (env, delta1), level, top, outerScope, d2) end
    | DOpen (ids, sp) =>
        List.foldl (fn ((path, name), delta) =>
                       case findStr (env, path @ [name]) of
                         SOME e => plus (delta, e)
                       | NONE => err (sp, "unbound structure: " ^ longidToString (path, name))) Env.empty ids
    | DInfix _ => Env.empty
    | DInfixr _ => Env.empty
    | DNonfix _ => Env.empty
    | DStructure (name, StrStruct (decs, _), _) =>
        bindStr (Env.empty, name, elabDecs (env, level, top, outerScope, decs))
    | DStructure (name, StrId ((path, sname), sp), _) =>
        (case findStr (env, path @ [sname]) of
           SOME e => bindStr (Env.empty, name, e)
         | NONE => err (sp, "unbound structure: " ^ longidToString (path, sname)))

  (* ------------------------------------------------------------------ *)
  fun elabProgram (decs : dec list) : env =
    let
      val env = ref Env.initial
    in
      List.app (fn d =>
                  let val delta = elabDec (!env, 0, true, ref StringMap.empty, d)
                  in resolvePending (); env := plus (!env, delta) end) decs;
      !env
    end
end
