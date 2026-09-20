(* Elaboration: type inference for the Core language with namespace-only
   structures. Fills the annotation slots in the AST for the translator. *)
structure Elaborate =
struct
  open Ast Types Env

  val stampCounter = ref 0
  fun freshStamp () = let val s = !stampCounter in stampCounter := s + 1; s end

  val allowPrim = ref false

  (* Signatures and functors are components of the basis, not of
     environments (Section 5.1); both are declared at top level only. *)
  val sigs : SigMatch.sigma StringMap.map ref = ref StringMap.empty

  datatype funinfo =
      FunInfo of {param : string option, paramSig : SigMatch.sigma, body : strexp, defEnv : env, allowPrim : bool,
                  defSigs : SigMatch.sigma StringMap.map, defFuns : funinfo StringMap.map}
  val funs : funinfo StringMap.map ref = ref StringMap.empty

  (* overloaded operator variables and flexible records awaiting resolution *)
  val pendingOverloads : tvar ref list ref = ref []
  val pendingFlex : (tvar ref * span) list ref = ref []

  (* Exhaustiveness and redundancy reports are deferred to the end of the
     top-level declaration, when flexible record patterns have their types.
     They are switched off while a functor body is re-elaborated for an
     application, since the body was reported on when the functor was declared. *)
  val pendingChecks : (unit -> unit) list ref = ref []
  val reportMatches = ref true
  fun deferCheck (f : unit -> unit) = if !reportMatches then pendingChecks := f :: !pendingChecks else ()

  fun err (sp, msg) = Error.error (sp, msg)

  fun unifyAt (sp, t1, t2, context) =
    Unify.unify (t1, t2)
    handle Unify.Unify reason =>
      let
        val printer = newPrinter ()
        val s1 = toStringWith printer t1
        val s2 = toStringWith printer t2
      in
        err (sp, context ^ ": type mismatch between " ^ s1 ^ " and " ^ s2 ^ " (" ^ reason ^ ")")
      end

  (* int and word constants awaiting the resolution of their type, for the
     check that the type can represent them *)
  val pendingLiterals : (scon * ty * Source.span) list ref = ref []

  fun power2 (n : int) : IntInf.int = IntInf.pow (IntInf.fromInt 2, n)

  fun checkLiteral (sc, t, sp) =
    let
      fun check (what, v, lo, hi) =
        if IntInf.< (v, lo) orelse IntInf.> (v, hi)
        then err (sp, what ^ " constant " ^ Ast.sconToString sc ^ " is out of range for the type " ^ toString t)
        else ()
    in
      case prune t of
        TCon (c, _) =>
          (case (sc, Overload.literalOf c) of
             (SInt v, SOME (Overload.Bits n)) =>
               check ("integer", v, IntInf.~ (power2 (n - 1)), IntInf.- (power2 (n - 1), IntInf.fromInt 1))
           | (SWord v, SOME (Overload.Bits n)) =>
               check ("word", v, IntInf.fromInt 0, IntInf.- (power2 n, IntInf.fromInt 1))
           | (SChar v, SOME (Overload.Bits n)) =>
               check ("character", IntInf.fromInt v, IntInf.fromInt 0, IntInf.- (power2 n, IntInf.fromInt 1))
           | (SWideString cs, SOME (Overload.Bits n)) =>
               List.app (fn v => check ("string", IntInf.fromInt v, IntInf.fromInt 0,
                                        IntInf.- (power2 n, IntInf.fromInt 1)))
                        cs
           | _ => ())
      | _ => ()
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
                         else if List.exists (fn n => n = "char") names then charTy
                         else if List.exists (fn n => n = "string") names then stringTy
                         else Error.bug "resolvePending: empty overload class"
                     in Unify.unify (TVar r, default) end
                 | _ => ()) (!pendingOverloads);
     pendingOverloads := [];
     List.app checkLiteral (List.rev (!pendingLiterals));
     pendingLiterals := [])

  (* Section 4.11: the program context must determine every flexible record.
     Checked once the whole program is elaborated, together with the deferred
     match reports (which need the records' labels). *)
  fun finish () =
    (List.app (fn (r, sp) =>
                 case !r of
                   Unbound {kind = KFlex _, ...} =>
                     err (sp, "unresolved flexible record: cannot determine the full set of fields")
                 | _ => ()) (List.rev (!pendingFlex));
     pendingFlex := [];
     List.app (fn f => f ()) (List.rev (!pendingChecks));
     pendingChecks := [])

  (* Section 2.9 and 3.5: identifiers that no binding or description may (re)bind. *)
  val reservedVids = ["true", "false", "nil", "::", "ref"]
  fun checkBindable (name, sp, allowIt : bool) =
    if List.exists (fn r => r = name) reservedVids orelse (not allowIt andalso name = "it") then
      err (sp, "'" ^ name ^ "' cannot be rebound")
    else ()

  fun checkDupLabels (fields : (string * 'a) list, sp) =
    let
      fun go [] = ()
        | go ((l, _) :: rest) =
          if List.exists (fn (l2, _) => l2 = l) rest then err (sp, "duplicate record label '" ^ l ^ "'") else go rest
    in go fields end

  (* The type of a special constant. An int, word or real constant is
     overloaded over the types of its kind (Appendix E: the classes Int, Word
     and Real) and defaults to int, word or real; its type is left in the slot
     for Translate. *)
  fun sconTy (level, sc, slot : ty option ref, sp) =
    let
      fun overloaded kind =
        let val t = freshTvar (level, KOverload [kind], false)
        in
          registerOverloads t;
          pendingLiterals := (sc, t, sp) :: !pendingLiterals;
          slot := SOME t;
          t
        end
    in
      case sc of
        SInt _ => overloaded "int"
      | SWord _ => overloaded "word"
      | SReal _ => overloaded "real"
      | SString _ => overloaded "string"
      | SWideString _ => overloaded "string"
      | SChar _ => overloaded "char"
    end

  type scope = ty StringMap.map ref

  (* --- explicit type variables (Section 4.6) --- *)
  fun addTyvar (v, acc) = if List.exists (fn w => w = v) acc then acc else v :: acc

  fun tyvarsOfTy (t : Ast.ty, acc : string list) : string list =
    case t of
      TyVar (v, _) => addTyvar (v, acc)
    | TyRecord (fields, _) => List.foldl (fn ((_, t), acc) => tyvarsOfTy (t, acc)) acc fields
    | TyTuple (ts, _) => List.foldl tyvarsOfTy acc ts
    | TyCon (args, _, _) => List.foldl tyvarsOfTy acc args
    | TyArrow (a, b, _) => tyvarsOfTy (b, tyvarsOfTy (a, acc))

  fun minusTyvars (vs, bound) = List.filter (fn v => not (List.exists (fn w => w = v) bound)) vs

  (* The type variables occurring unguarded in a value declaration: those
     in it that are not inside a smaller value declaration. Variables bound
     by the tyvarseq of a type or datatype binding do not count. *)
  fun unguardedExp (e : exp, acc) : string list =
    case e of
      EScon _ => acc
    | EVar _ => acc
    | ERecord (fields, _) => List.foldl (fn ((_, e), acc) => unguardedExp (e, acc)) acc fields
    | ETuple (es, _) => List.foldl unguardedExp acc es
    | ESelect _ => acc
    | EList (es, _) => List.foldl unguardedExp acc es
    | ESeq (es, _) => List.foldl unguardedExp acc es
    | ELet (decs, e, _) => unguardedExp (e, List.foldl unguardedDec acc decs)
    | EApp (f, a, _) => unguardedExp (a, unguardedExp (f, acc))
    | ETyped (e, t, _) => tyvarsOfTy (t, unguardedExp (e, acc))
    | EAndalso (a, b, _) => unguardedExp (b, unguardedExp (a, acc))
    | EOrelse (a, b, _) => unguardedExp (b, unguardedExp (a, acc))
    | EHandle (e, rules, _) => unguardedRules (rules, unguardedExp (e, acc))
    | ERaise (e, _) => unguardedExp (e, acc)
    | EIf (a, b, c, _) => unguardedExp (c, unguardedExp (b, unguardedExp (a, acc)))
    | EWhile (a, b, _) => unguardedExp (b, unguardedExp (a, acc))
    | ECase (e, rules, _) => unguardedRules (rules, unguardedExp (e, acc))
    | EFn (rules, _) => unguardedRules (rules, acc)
    | EPrim (_, t, _) => tyvarsOfTy (t, acc)

  and unguardedRules (rules : mrule list, acc) =
    List.foldl (fn ((p, e), acc) => unguardedExp (e, unguardedPat (p, acc))) acc rules

  and unguardedPat (p : pat, acc) : string list =
    case p of
      PRecord (fields, _, _, _) => List.foldl (fn ((_, p), acc) => unguardedPat (p, acc)) acc fields
    | PTuple (ps, _) => List.foldl unguardedPat acc ps
    | PList (ps, _) => List.foldl unguardedPat acc ps
    | PApp (_, _, p, _) => unguardedPat (p, acc)
    | PTyped (p, t, _) => tyvarsOfTy (t, unguardedPat (p, acc))
    | PLayered (_, tyopt, p, _, _) =>
        unguardedPat (p, case tyopt of SOME t => tyvarsOfTy (t, acc) | NONE => acc)
    | _ => acc

  (* declarations nested in an expression *)
  and unguardedDec (d : dec, acc) : string list =
    case d of
      DVal _ => acc                          (* a smaller value declaration guards its variables *)
    | DValRec _ => acc
    | DFun _ => acc
    | DType (tbs, _) =>
        List.foldl (fn (tb : typbind, acc) => minusTyvars (tyvarsOfTy (#ty tb, []), #tyvars tb) @ acc) acc tbs
    | DDatatype (dbs, tbs, _) =>
        List.foldl (fn (db : datbind, acc) =>
                       minusTyvars (List.foldl (fn ((_, SOME t, _), a) => tyvarsOfTy (t, a) | ((_, NONE, _), a) => a) [] (#cons db),
                                    #tyvars db) @ acc)
                   (unguardedDec (DType (tbs, Source.noSpan), acc)) dbs
    | DException (ebs, _) =>
        List.foldl (fn (ExnDecl (_, SOME t, _, _), acc) => tyvarsOfTy (t, acc) | (_, acc) => acc) acc ebs
    | DLocal (d1, d2, _) => List.foldl unguardedDec (List.foldl unguardedDec acc d1) d2
    | DAbstype (dbs, tbs, decs, _) =>
        List.foldl unguardedDec (unguardedDec (DDatatype (dbs, tbs, Source.noSpan), acc)) decs
    | _ => acc

  (* the unguarded variables of a value declaration itself *)
  fun unguardedValDec (d : dec) : string list =
    case d of
      DVal (_, binds, _) => List.foldl (fn ((p, e), acc) => unguardedExp (e, unguardedPat (p, acc))) [] binds
    | DValRec (_, binds, _) => List.foldl (fn ((p, e), acc) => unguardedExp (e, unguardedPat (p, acc))) [] binds
    | DFun (_, fs, _) =>
        List.foldl (fn (f : fundef, acc) =>
                       List.foldl (fn ({pats, resty, body}, acc) =>
                                      unguardedExp (body, List.foldl unguardedPat
                                                                    (case resty of SOME t => tyvarsOfTy (t, acc) | NONE => acc)
                                                                    pats))
                                  acc (#clauses f)) [] fs
    | _ => []

  (* Rule 15: the scope of a value declaration binds its explicit type
     variables and those implicitly scoped at it, as rigid variables. *)
  fun valScope (outer : scope, explicit : string list, d : dec, level, sp) : scope * string list =
    let
      val () = List.app (fn v =>
                            if StringMap.member (!outer, v) then err (sp, "explicit type variable " ^ v ^ " is already in scope")
                            else ()) explicit
      val implicit = List.filter (fn v => not (StringMap.member (!outer, v)) andalso not (List.exists (fn w => w = v) explicit))
                                 (List.rev (unguardedValDec d))
      val scoped = explicit @ implicit
      val m = List.foldl (fn (v, m) => StringMap.insert (m, v, freshTvar (level, KRigid v, String.isPrefix "''" v))) (!outer) scoped
    in (ref m, scoped) end

  (* Rule 15's side condition: the scoped variables must have been generalised.
     A variable that was unified with a type of the enclosing context has
     been lowered to the context's level; an unused one still sits at the
     declaration's own level, which is fine. *)
  fun checkGeneralised (scope : scope, scoped : string list, level, sp) =
    List.app (fn v =>
                 case StringMap.find (!scope, v) of
                   SOME t =>
                     (case prune t of
                        TVar (ref (Unbound {level = l, ...})) =>
                          if l > level then ()
                          else err (sp, "explicit type variable " ^ v ^ " cannot be generalised")
                      | _ => err (sp, "explicit type variable " ^ v ^ " cannot be generalised"))
                 | NONE => ()) scoped

  (* A scope for the type variables of a type expression in a specification,
     which are implicitly quantified (rule 79). *)
  fun specScope (t : Ast.ty, level) : scope =
    ref (List.foldl (fn (v, m) => StringMap.insert (m, v, freshTvar (level, KPlain, String.isPrefix "''" v)))
                    StringMap.empty (tyvarsOfTy (t, [])))

  (* ------------------------------------------------------------------ *)
  (* Types                                                                *)
  fun elabTy (env, scope : scope, level, t : Ast.ty) : ty =
    case t of
      TyVar (v, sp) =>
        (case StringMap.find (!scope, v) of
           SOME t => t
         | NONE => err (sp, "unbound type variable " ^ v))
    | TyRecord (fields, sp) =>
        (checkDupLabels (fields, sp);
         TRecord (sortFields (List.map (fn (l, t) => (l, elabTy (env, scope, level, t))) fields)))
    | TyTuple (ts, _) => tupleTy (List.map (fn t => elabTy (env, scope, level, t)) ts)
    | TyCon (args, longid, sp) =>
        let val args' = List.map (fn t => elabTy (env, scope, level, t)) args
        in
          case findTy (env, longid) of
            NONE => err (sp, "unbound type constructor: " ^ longidToString longid)
          | SOME (TyStr {fcn, ...}) =>
              if List.length args' <> fcnArity fcn then
                err (sp, "type constructor " ^ longidToString longid ^ " expects " ^ Int.toString (fcnArity fcn)
                         ^ " argument(s) but got " ^ Int.toString (List.length args'))
              else applyFcn (fcn, args')
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
    | SOME _ => NONE                       (* values, including constructors that lost their status *)
    | NONE =>
        (case longid of
           ([], _) => NONE
         | _ => err (sp, "unbound constructor: " ^ longidToString longid))

  fun elabPat (env, level, scope, isGlobal, p : pat, bound : (string * span) list ref)
      : ty * (string * valstatus) list =
    let
      fun bindVar (name, sp) =
        (checkBindable (name, sp, true);
         if List.exists (fn (n, _) => n = name) (!bound) then
           err (sp, "duplicate variable '" ^ name ^ "' in pattern")
         else bound := (name, sp) :: !bound;
         let
           val stamp = freshStamp ()
           val t = fresh level
         in (stamp, t, (name, Val {scheme = t, stamp = stamp, global = isGlobal})) end)
      fun elab p =
        case p of
          PWild _ => (fresh level, [])
        | PScon (sc, slot, sp) => (sconTy (level, sc, slot, sp), [])
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
                let val r = freshFlex (level, ftys, false)
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
         | _ => false)                     (* a constructor that lost its status is an ordinary variable *)
    | _ => false

  fun elabExp (env, level, scope : scope, e : exp) : ty =
    case e of
      EScon (sc, slot, sp) => sconTy (level, sc, slot, sp)
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
             in registerOverloads t; slot := SOME (VBuiltin (name, t)); t end
         | SOME (ConAsVal {scheme, info}) => (slot := SOME (VConVal info); Unify.instantiate (level, scheme))
         | SOME (ExnAsVal {ty, info}) => (slot := SOME (VExnVal info); ty))
    | ERecord (fields, sp) =>
        (checkDupLabels (fields, sp);
         TRecord (sortFields (List.map (fn (l, e) => (l, elabExp (env, level, scope, e))) fields)))
    | ETuple ([], _) => unitTy
    | ETuple (es, _) => tupleTy (List.map (fn e => elabExp (env, level, scope, e)) es)
    | ESelect (lab, slot, sp) =>
        let
          val a = fresh level
          val r = freshFlex (level, [(lab, a)], false)
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
    | EHandle (e, rules, sp) =>
        let val te = elabExp (env, level, scope, e)
        in elabMatch (env, level, scope, rules, exnTy, te, false, sp); te end
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
    | ECase (e, rules, sp) =>
        let
          val te = elabExp (env, level, scope, e)
          val res = fresh level
        in elabMatch (env, level, scope, rules, te, res, true, sp); res end
    | EFn (rules, sp) =>
        let
          val arg = fresh level
          val res = fresh level
        in elabMatch (env, level, scope, rules, arg, res, true, sp); TArrow (arg, res) end
    | EPrim (name, t, sp) =>
        if not (!allowPrim) then err (sp, "_prim is only allowed when compiling with --allow-prim")
        else
          (case Prims.find name of
             NONE => err (sp, "unknown primitive '" ^ name ^ "'")
           | SOME _ => elabTy (env, scope, level, t))

  (* Section 4.11: a fn match must be exhaustive, every match irredundant. *)
  and elabMatch (env, level, scope, rules : mrule list, argTy, resTy, exhaustive : bool, sp) =
    (List.app (fn (p, e) =>
                 let
                   val bound = ref []
                   val (tp, bindings) = elabPat (env, level, scope, false, p, bound)
                   val () = unifyAt (spanOfPat p, argTy, tp, "pattern")
                   val env' = plus (env, bindingsToEnv bindings)
                   val te = elabExp (env', level, scope, e)
                 in unifyAt (spanOfExp e, resTy, te, "result of match rule") end) rules;
     deferCheck (fn () => Exhaust.checkMatch (List.map #1 rules, sp, exhaustive)))

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
          val (scope, scoped) = valScope (outerScope, tvs, d, level + 1, sp)
          val allBindings =
            List.map (fn (p, e) =>
                         let
                           val te = elabExp (env, level + 1, scope, e)
                           val bound = ref []
                           val (tp, bindings) = elabPat (env, level + 1, scope, top, p, bound)
                           val () = unifyAt (spanOfPat p, tp, te, "val binding")
                           val () = if nonexpansive e then Unify.generalize (level, tp)
                                    else Unify.lowerLevels (level, tp)
                           (* 4.11: reported except for components of a top-level declaration *)
                           val () = if top then () else deferCheck (fn () => Exhaust.checkBinding (p, spanOfPat p))
                         in bindings end) binds
          val flat = List.concat allBindings
          fun checkDups [] = ()
            | checkDups ((n, _) :: rest) =
              if List.exists (fn (m, _) => m = n) rest then err (sp, "duplicate variable '" ^ n ^ "' in val declaration")
              else checkDups rest
        in checkDups flat; checkGeneralised (scope, scoped, level, sp); bindingsToEnv flat end
    | DValRec (tvs, binds, sp) =>
        let
          val (scope, scoped) = valScope (outerScope, tvs, d, level + 1, sp)
          fun isFn (EFn _) = true
            | isFn (ETyped (e, _, _)) = isFn e
            | isFn _ = false
          (* every variable of a binding's pattern is bound to the same function *)
          val prepared =
            List.map (fn (p, e) =>
                         let
                           val (vars, tys) =
                             case recBindVars p of
                               SOME r => r
                             | NONE => err (spanOfPat p, "val rec requires a variable on the left-hand side")
                           val () = if isFn e then () else err (spanOfExp e, "val rec right-hand side must be a function expression")
                           val tv = fresh (level + 1)
                           val bindings =
                             List.map (fn (name, slot, psp) =>
                                          let val stamp = freshStamp ()
                                          in
                                            checkBindable (name, psp, true);
                                            slot := SOME (PIVar (stamp, top));
                                            (name, Val {scheme = tv, stamp = stamp, global = top})
                                          end) vars
                         in (bindings, tv, tys, e, spanOfPat p) end) binds
          val allBindings = List.concat (List.map #1 prepared)
          fun checkDups [] = ()
            | checkDups ((n, _) :: rest) =
              if List.exists (fn (m, _) => m = n) rest then err (sp, "duplicate variable '" ^ n ^ "' in val rec declaration")
              else checkDups rest
          val () = checkDups allBindings
          val env' = plus (env, bindingsToEnv allBindings)
        in
          List.app (fn (_, tv, tys, e, psp) =>
                       let
                         val () = List.app (fn t => unifyAt (psp, elabTy (env, scope, level + 1, t), tv, "val rec type annotation")) tys
                         val te = elabExp (env', level + 1, scope, e)
                       in unifyAt (spanOfExp e, tv, te, "val rec binding") end) prepared;
          List.app (fn (_, tv, _, _, _) => Unify.generalize (level, tv)) prepared;
          checkGeneralised (scope, scoped, level, sp);
          bindingsToEnv allBindings
        end
    | DFun (tvs, fundefs, sp) =>
        let
          val (scope, scoped) = valScope (outerScope, tvs, d, level + 1, sp)
          val prepared =
            List.map (fn (f : fundef) =>
                         let
                           val () = checkBindable (#name f, #span f, true)
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
          List.app (fn (name, _, tv, f : fundef) =>
                      (List.app (fn {pats, resty, body} =>
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
                                (#clauses f);
                       deferCheck (fn () =>
                         Exhaust.checkClauses (List.map #pats (#clauses f),
                                               List.map (fn (c : clause) => spanOfPat (List.hd (#pats c))) (#clauses f),
                                               #span f)))) prepared;
          List.app (fn (_, _, tv, _) => Unify.generalize (level, tv)) prepared;
          checkGeneralised (scope, scoped, level, sp);
          bindingsToEnv (List.map (fn (n, v, _, _) => (n, v)) prepared)
        end
    | DType (typbinds, _) =>
        List.foldl (fn (tb : typbind, delta) =>
                       let
                         val () = if StringMap.member (tys delta, #name tb) then
                                    err (#span tb, "duplicate type constructor '" ^ #name tb ^ "' in one declaration") else ()
                         val params = List.map paramVar (#tyvars tb)
                         val scope = ref (List.foldl (fn ((v, t), m) => StringMap.insert (m, v, t)) (!outerScope)
                                                     (ListPair.zip (#tyvars tb, List.map #2 params)))
                         val body = elabTy (env, scope, level, #ty tb)
                       in bindTy (delta, #name tb, TyStr {fcn = TAbbrev (List.map #1 params, body), cons = []}) end)
                   Env.empty typbinds
    | DDatatype (datbinds, typbinds, sp) =>
        let
          (* Fresh type names, provisionally admitting equality; the maximal
             attributes are computed below (Section 4.9, rule 17). *)
          fun dupTycons [] = ()
            | dupTycons ((db : datbind) :: rest) =
              if List.exists (fn (db' : datbind) => #name db' = #name db) rest
                 orelse List.exists (fn (tb : typbind) => #name tb = #name db) typbinds then
                err (#span db, "duplicate type constructor '" ^ #name db ^ "' in one declaration")
              else dupTycons rest
          val () = dupTycons datbinds
          val tycons = List.map (fn (db : datbind) => (db, freshTycon (#name db, List.length (#tyvars db), true))) datbinds
          val env1 = List.foldl (fn ((db, tc), e) => bindTy (e, #name db, TyStr {fcn = TName tc, cons = []})) env tycons
          val abbrevs = elabDec (env1, level, top, outerScope, DType (typbinds, sp))
          val env2 = plus (env1, abbrevs)
          fun elabDatbind ((db : datbind, tc), (delta, groups)) =
            let
              val params = List.map paramVar (#tyvars db)
              val scope = ref (List.foldl (fn ((v, t), m) => StringMap.insert (m, v, t)) (!outerScope)
                                          (ListPair.zip (#tyvars db, List.map #2 params)))
              val resTy = TCon (tc, List.map #2 params)
              val ncons = List.length (#cons db)
              val siblings = List.map (fn (cname, argOpt, _) => (cname, isSome argOpt)) (#cons db)
              val cons =
                List.foldl (fn ((cname, argOpt, csp), (acc, i, args)) =>
                               let
                                 val () = checkBindable (cname, csp, false)
                                 val () = if List.exists (fn (n, _) => n = cname) acc then
                                            err (csp, "duplicate constructor '" ^ cname ^ "'") else ()
                                 val (scheme, args) =
                                   case argOpt of
                                     NONE => (resTy, args)
                                   | SOME t => let val ta = elabTy (env2, scope, level, t)
                                               in (TArrow (ta, resTy), ta :: args) end
                                 val info = {name = cname, tag = i, hasArg = isSome argOpt, ncons = ncons, isRef = false,
                                             siblings = siblings}
                               in ((cname, Con {scheme = scheme, info = info}) :: acc, i + 1, args) end)
                           ([], 0, []) (#cons db)
              val args = #3 cons
              val cons = List.rev (#1 cons)
              val delta = bindTy (delta, #name db, TyStr {fcn = TName tc, cons = cons})
            in (List.foldl (fn ((n, v), d) => bindVal (d, n, v)) delta cons, (tc, args) :: groups) end
          val (delta, groups) = List.foldl elabDatbind (Env.empty, []) tycons
          (* Maximise equality: a datatype of the group admits equality iff
             every constructor argument does under the current assumption. *)
          fun admitsUnder (assume : bool IntMap.map) (t : ty) : bool =
            case prune t of
              TVar _ => true
            | TCon (c, args) =>
                (case IntMap.find (assume, #stamp c) of
                   SOME b => b andalso List.all (admitsUnder assume) args
                 | NONE =>
                     sameTycon (c, refTycon) orelse sameTycon (c, arrayTycon)
                     orelse (#eq c andalso List.all (admitsUnder assume) args))
            | TRecord fields => List.all (fn (_, a) => admitsUnder assume a) fields
            | TArrow _ => false
          fun iterate assume =
            let
              val assume' =
                List.foldl (fn ((tc : tycon, args), m) => IntMap.insert (m, #stamp tc, List.all (admitsUnder assume) args))
                           IntMap.empty groups
            in if IntMap.listItems assume' = IntMap.listItems assume then assume else iterate assume' end
          val final = iterate (List.foldl (fn ((tc : tycon, _), m) => IntMap.insert (m, #stamp tc, true)) IntMap.empty groups)
          val phi =
            List.foldl (fn ((tc : tycon, _), m) =>
                           IntMap.insert (m, #stamp tc, TName (withEq (tc, IntMap.lookup (final, #stamp tc)))))
                       IntMap.empty groups
        in
          realizeEnv (phi, plus (abbrevs, delta))
        end
    | DDatatypeRepl (name, longid, sp) =>
        (case findTy (env, longid) of
           SOME (ts as TyStr {cons, ...}) =>
             List.foldl (fn ((n, v), d) => bindVal (d, n, v)) (bindTy (Env.empty, name, ts)) cons
         | NONE => err (sp, "unbound type constructor: " ^ longidToString longid))
    | DAbstype (datbinds, typbinds, decs, sp) =>
        let
          (* rule 19: the datatypes are visible with their constructors in the
             body only; outside they are abstract and do not admit equality *)
          val delta1 = elabDec (env, level, top, outerScope, DDatatype (datbinds, typbinds, sp))
          val delta2 = elabDecs (plus (env, delta1), level, top, outerScope, decs)
          val phi =
            StringMap.foldli (fn (_, TyStr {fcn = TName c, cons = _ :: _}, m) => IntMap.insert (m, #stamp c, TName (withEq (c, false)))
                               | (_, _, m) => m) IntMap.empty (tys delta1)
          val absTys = Env {vals = StringMap.empty,
                            tys = StringMap.map (fn TyStr {fcn, ...} => TyStr {fcn = realizeFcn (phi, fcn), cons = []}) (tys delta1),
                            strs = StringMap.empty}
        in plus (absTys, realizeEnv (phi, delta2)) end
    | DException (exbinds, _) =>
        List.foldl (fn (eb, delta) =>
                       case eb of
                         ExnDecl (name, tyopt, slot, sp) =>
                           let
                             val () = checkBindable (name, sp, false)
                             val () = if StringMap.member (vals delta, name) then
                                        err (sp, "duplicate exception constructor '" ^ name ^ "' in one declaration") else ()
                             val stamp = freshStamp ()
                             val scope = ref (!outerScope)
                             val ty = case tyopt of
                                        NONE => exnTy
                                      | SOME t => TArrow (elabTy (env, scope, level + 1, t), exnTy)
                             val info = {name = name, stamp = stamp, isGlobal = top, hasArg = isSome tyopt, builtin = NONE}
                           in slot := SOME (PIExn info); bindVal (delta, name, Exn {ty = ty, info = info}) end
                       | ExnRepl (name, longid, slot, sp) =>
                           (checkBindable (name, sp, false);
                            if StringMap.member (vals delta, name) then
                              err (sp, "duplicate exception constructor '" ^ name ^ "' in one declaration") else ();
                            case findVal (env, longid) of
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
    | DOverload {kind, strid, literal, span = sp} =>
        (* Register <strid>.<kind> as an overloading type whose operators are
           the values of the structure. A structure that only renames a
           registered type (structure Int64 = Int) needs no registration. *)
        let
          val () = if !allowPrim then () else err (sp, "_overload is only allowed when compiling with --allow-prim")
          val name = String.concatWith "." strid
          val () = if List.exists (fn k => k = kind) ["int", "word", "real", "char", "string"] then ()
                   else err (sp, "_overload: unknown kind " ^ kind)
          val str = case Env.findStr (env, strid) of
                      SOME e => e
                    | NONE => err (sp, "unbound structure: " ^ name)
          val tycon = case Env.findTy (str, ([], kind)) of
                        SOME tystr =>
                          (case Env.tyStrName tystr of
                             SOME c => c
                           | NONE => err (sp, "_overload: " ^ name ^ "." ^ kind ^ " is not a type name"))
                      | NONE => err (sp, "_overload: structure " ^ name ^ " has no type " ^ kind)
          fun global what longid =
            case Env.findVal (env, longid) of
              SOME (Val {stamp, global = true, ...}) => stamp
            | _ => err (sp, "_overload: " ^ what ^ " is not a top-level value")
          fun operator opname = (opname, Overload.Global (global (name ^ "." ^ opname) (strid, opname)))
          val lit = case literal of
                      OvBits n => Overload.Bits n
                    | OvVia (path, f) => Overload.Via (global (String.concatWith "." (path @ [f])) (path, f))
        in
          case Overload.kindOf tycon of
            SOME _ => ()
          | NONE => Overload.register (tycon, kind, List.map operator (Overload.operators kind), lit);
          Env.empty
        end
    | DStructure (binds, _) =>
        (* all bindings of one declaration are elaborated in the same environment (rule 61) *)
        List.foldl (fn (b : strbind, delta) => bindStr (delta, #name b, elabStrexp (env, level, top, outerScope, #strexp b)))
                   Env.empty binds
    | DSignature (binds, _) =>
        (* all bindings are elaborated in the same basis (rule 67) *)
        let val elaborated = List.map (fn (b : sigbind) => (#name b, elabSigexp (env, #sigexp b))) binds
        in List.app (fn (n, sg) => sigs := StringMap.insert (!sigs, n, sg)) elaborated; Env.empty end
    | DFunctor (binds, _) =>
        let
          val elaborated =
            List.map (fn (b : funbind) =>
                         let
                           val sigma = elabSigexp (env, #paramSig b)
                           val bodyEnv = case #param b of
                                           SOME x => bindStr (env, x, #env sigma)
                                         | NONE => plus (env, #env sigma)
                           (* the body is checked once against the parameter signature (rule 86);
                              its annotations are discarded, each application elaborates a copy *)
                           val _ = elabStrexp (bodyEnv, level, top, outerScope, #body b)
                           val () = resolvePending ()
                           val sigsNow = !sigs
                           val funsNow = !funs
                         in
                           (#name b, FunInfo {param = #param b, paramSig = sigma, body = #body b, defEnv = env,
                                              allowPrim = !allowPrim, defSigs = sigsNow, defFuns = funsNow})
                         end) binds
        in List.app (fn (n, f) => funs := StringMap.insert (!funs, n, f)) elaborated; Env.empty end

  (* ------------------------------------------------------------------ *)
  (* Structure expressions.                                               *)
  and elabStrexp (env, level, top, scope : scope, se : strexp) : env =
    case se of
      StrStruct (decs, _) => elabDecs (env, level, top, scope, decs)
    | StrId ((path, sname), sp) =>
        (case findStr (env, path @ [sname]) of
           SOME e => e
         | NONE => err (sp, "unbound structure: " ^ longidToString (path, sname)))
    | StrAscribe (se, sigexp, opaque, sp) =>
        let
          val e = elabStrexp (env, level, top, scope, se)
          val sigma = elabSigexp (env, sigexp)
        in SigMatch.ascribe (sigma, e, opaque, sp) end
    | StrApp (funid, arg, slot, sp) =>
        (case StringMap.find (!funs, funid) of
           NONE => err (sp, "unbound functor: " ^ funid)
         | SOME (FunInfo {param, paramSig, body, defEnv, allowPrim = ap, defSigs, defFuns}) =>
             let
               (* rule 54: match the argument, then specialise a copy of the body to it,
                  in the basis of the functor's definition *)
               val argEnv = elabStrexp (env, level, top, scope, arg)
               val thinned = SigMatch.ascribe (paramSig, argEnv, false, sp)
               val bodyEnv = case param of
                               SOME x => bindStr (defEnv, x, thinned)
                             | NONE => plus (defEnv, thinned)
               val copy = copyStrexp body
               val saved = (!allowPrim, !reportMatches, !sigs, !funs)
               fun restore () =
                 (allowPrim := #1 saved; reportMatches := #2 saved; sigs := #3 saved; funs := #4 saved)
               val () = (allowPrim := ap; reportMatches := false; sigs := defSigs; funs := defFuns)
               val result =
                 elabStrexp (bodyEnv, level, top, scope, copy)
                 handle Error.CompileError (sp', msg) =>
                   (restore ();
                    raise Error.CompileError (sp', "in the application of functor " ^ funid ^ " at "
                                                   ^ Source.describe sp ^ ": " ^ msg))
               val () = restore ()
             in slot := SOME copy; result end)
    | StrLet (decs, body, _) =>
        let val delta = elabDecs (env, level, top, scope, decs)
        in elabStrexp (plus (env, delta), level, top, scope, body) end

  (* ------------------------------------------------------------------ *)
  (* Signature expressions and specifications (rules 62-84).             *)
  and elabSigexp (env, se : sigexp) : SigMatch.sigma =
    case se of
      SigId (n, sp) =>
        (case StringMap.find (!sigs, n) of
           SOME sg => SigMatch.instantiate sg
         | NONE => err (sp, "unbound signature: " ^ n))
    | SigSig (specs, sp) => elabSpecs (env, specs)
    | SigWhere (se, clauses, _) =>
        List.foldl (fn ((tvs, longid, ty, csp), sigma) =>
                       let
                         val params = List.map paramVar tvs
                         val scope = ref (StringMap.fromList (ListPair.zip (tvs, List.map #2 params)))
                         val body = elabTy (env, scope, 0, ty)
                       in SigMatch.whereType (sigma, longid, TAbbrev (List.map #1 params, body), csp) end)
                   (elabSigexp (env, se)) clauses

  and elabSpecs (env, specs : spec list) : SigMatch.sigma =
    let
      fun add (sigma : SigMatch.sigma, bound', delta, sp) : SigMatch.sigma =
        {bound = #bound sigma @ bound', env = plusDisjoint (#env sigma, delta, sp)}
      (* rule 77: later specifications see the earlier ones *)
      fun cur (sigma : SigMatch.sigma) = plus (env, #env sigma)
      fun one (spec, sigma) =
        case spec of
          SpecVal (descs, _) =>
            List.foldl (fn ((n, ty, dsp), sigma) =>
                           let
                             val () = checkBindable (n, dsp, true)
                             val scope = specScope (ty, 1)
                             val t = elabTy (cur sigma, scope, 1, ty)
                             val () = Unify.generalize (0, t)              (* rule 79: implicitly closed *)
                           in add (sigma, [], bindVal (Env.empty, n, Val {scheme = t, stamp = freshStamp (), global = true}), dsp) end)
                       sigma descs
        | SpecType (descs, _) =>
            List.foldl (fn ((tvs, n, dsp), sigma) =>
                           let val tc = freshTycon (n, List.length tvs, false)
                           in add (sigma, [tc], bindTy (Env.empty, n, TyStr {fcn = TName tc, cons = []}), dsp) end)
                       sigma descs
        | SpecEqtype (descs, _) =>
            List.foldl (fn ((tvs, n, dsp), sigma) =>
                           let val tc = freshTycon (n, List.length tvs, true)
                           in add (sigma, [tc], bindTy (Env.empty, n, TyStr {fcn = TName tc, cons = []}), dsp) end)
                       sigma descs
        | SpecDatatype (dbs, sp) =>
            let
              val delta = elabDec (cur sigma, 0, true, ref StringMap.empty, DDatatype (dbs, [], sp))
              val names = StringMap.foldri (fn (_, TyStr {fcn = TName c, ...}, acc) => c :: acc | (_, _, acc) => acc) [] (tys delta)
            in add (sigma, names, delta, sp) end
        | SpecDatatypeRepl (n, longid, sp) =>
            add (sigma, [], elabDec (cur sigma, 0, true, ref StringMap.empty, DDatatypeRepl (n, longid, sp)), sp)
        | SpecException (descs, _) =>
            List.foldl (fn ((n, tyopt, dsp), sigma) =>
                           let
                             val () = checkBindable (n, dsp, false)
                             val scope = ref StringMap.empty
                             val ty = case tyopt of
                                        NONE => exnTy
                                      | SOME t => TArrow (elabTy (cur sigma, scope, 0, t), exnTy)
                             val info = {name = n, stamp = freshStamp (), isGlobal = true, hasArg = isSome tyopt, builtin = NONE}
                           in add (sigma, [], bindVal (Env.empty, n, Exn {ty = ty, info = info}), dsp) end)
                       sigma descs
        | SpecStructure (descs, _) =>
            (* all descriptions of one specification are elaborated in the same basis (rule 84) *)
            let val elaborated = List.map (fn (n, sg, dsp) => (n, elabSigexp (cur sigma, sg), dsp)) descs
            in
              List.foldl (fn ((n, sg : SigMatch.sigma, dsp), sigma) =>
                             add (sigma, #bound sg, bindStr (Env.empty, n, #env sg), dsp)) sigma elaborated
            end
        | SpecInclude (sg, sp) =>
            let val sg' = elabSigexp (cur sigma, sg)
            in add (sigma, #bound sg', #env sg', sp) end
        | SpecSharingType (ids, sp) => SigMatch.shareTypes (sigma, ids, sp)
        | SpecSharing (ids, sp) => SigMatch.shareStructures (sigma, ids, sp)
    in
      List.foldl one {bound = [], env = Env.empty} specs
    end

  (* ------------------------------------------------------------------ *)
  (* Elaborate top-level declarations, extending env in place. *)
  (* Rules 87-89: a top-level declaration may not leave free type variables
     in the basis, e.g. val r = ref nil. *)
  fun freeTyvar (t : ty) : ty option =
    case prune t of
      t as TVar (ref (Unbound {level, kind, ...})) =>
        (case kind of KFlex _ => NONE | _ => if level = genericLevel then NONE else SOME t)
    | TVar _ => NONE
    | TCon (_, args) => List.foldl (fn (a, NONE) => freeTyvar a | (_, r) => r) NONE args
    | TRecord fields => List.foldl (fn ((_, a), NONE) => freeTyvar a | (_, r) => r) NONE fields
    | TArrow (a, b) => (case freeTyvar a of NONE => freeTyvar b | r => r)

  fun checkClosed (delta : env, sp) : unit =
    (StringMap.appi (fn (n, v) =>
                        let val scheme = case v of Val {scheme, ...} => scheme | _ => unitTy
                        in
                          case freeTyvar scheme of
                            NONE => ()
                          | SOME _ =>
                              err (sp, "the type of " ^ n ^ ", " ^ toString scheme
                                       ^ ", contains a type variable that cannot be generalised "
                                       ^ "(a top-level declaration may not have free type variables)")
                        end) (vals delta);
     StringMap.app (fn e => checkClosed (e, sp)) (strs delta))

  fun elabTop (env : env ref, decs : dec list) : unit =
    List.app (fn d =>
                let
                  val () = Unify.flexHook := (fn r => pendingFlex := (r, spanOfDec d) :: !pendingFlex)
                  val delta = elabDec (!env, 0, true, ref StringMap.empty, d)
                in resolvePending (); checkClosed (delta, spanOfDec d); env := plus (!env, delta) end) decs

  fun elabProgram (decs : dec list) : env =
    let val env = ref Env.initial
    in elabTop (env, decs); finish (); !env end
end
