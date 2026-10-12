(* Signatures (Definition, Chapter 5): instantiation, realisation
   constraints (where type, sharing), matching by enrichment, and
   ascription. A signature is a set of flexible (bound) type names together
   with an environment mentioning them. *)
structure SigMatch =
struct
  open Types Env

  type sigma = {bound : tycon list, env : env}

  fun err (sp, msg) = Error.error (sp, msg)
  fun pathString (path, name) = String.concatWith "." (path @ [name])

  fun isBound (bound : tycon list, c : tycon) = List.exists (fn b => sameTycon (b, c)) bound

  fun fcnToString (TName c) = tyconName c
    | fcnToString (TAbbrev (_, body)) = toString body

  (* Rule 65: every use of a signature gets fresh bound names. *)
  fun instantiate ({bound, env} : sigma) : sigma =
    let
      val () = if !ElabStats.on then (ElabStats.count ElabStats.InstSig; ElabStats.add (ElabStats.InstNames, List.length bound))
               else ()
      val fresh = List.map (fn c => (c, freshTycon (#name c, #arity c, #eq c))) bound
      val phi = List.foldl (fn ((c, c'), m) => IntMap.insert (m, #stamp c, TName c')) IntMap.empty fresh
    in {bound = List.map #2 fresh, env = realizeEnv (phi, env)} end

  (* Apply a realisation; realised names stop being flexible. *)
  fun realizeSigma (phi : realisation, {bound, env} : sigma) : sigma =
    {bound = List.filter (fn c => not (IntMap.member (phi, #stamp c))) bound, env = realizeEnv (phi, env)}

  (* All type components of an environment with their paths, in a fixed order. *)
  fun tyPaths (env : env) : (string list * string * tystatus) list =
    let
      fun go (prefix : string list, e : env, acc) =
        let val acc = StringMap.foldri (fn (n, ts, acc) => (prefix, n, ts) :: acc) acc (tys e)
        in StringMap.foldri (fn (n, sub, acc) => go (prefix @ [n], sub, acc)) acc (strs e) end
    in go ([], env, []) end

  (* Rule 64: sigexp where type tyvarseq longtycon = ty. The clauses of a
     chain (`S where type t = a and type u = b where ...`), the innermost
     first, are realised at once: a definition is elaborated outside the
     signature and mentions none of its flexible names, so the clauses'
     realisations compose by their union. whereStep adds a clause to phi,
     what the clauses before it define of sigma, the signature the chain
     starts from, checking it as against the signature they realised; and
     whereFinish realises sigma by them all. *)
  fun whereStep ({bound, env} : sigma, phi : realisation, longid, fcn : tyfcn, sp) : realisation =
    let
      val () = if !ElabStats.on then ElabStats.count ElabStats.WhereClause else ()
      val (c, cons) =
        case findTy (env, longid) of
          NONE => err (sp, "unbound type constructor in signature: " ^ pathString longid)
        | SOME (TyStr {fcn = f, cons}) =>
            (case fcnIsName (realizeFcn (phi, f)) of
               SOME c =>
                 if isBound (bound, c) andalso not (IntMap.member (phi, #stamp c)) then (c, cons)
                 else err (sp, "type " ^ pathString longid ^ " is not a flexible type of the signature")
             | NONE => err (sp, "type " ^ pathString longid ^ " is already defined in the signature"))
    in
      if fcnArity fcn <> #arity c then
        err (sp, "type " ^ pathString longid ^ " has " ^ Int.toString (#arity c) ^ " parameter(s) but its definition has "
                 ^ Int.toString (fcnArity fcn))
      else if #eq c andalso not (fcnAdmitsEq fcn) then
        err (sp, "type " ^ pathString longid ^ " is an equality type but " ^ fcnToString fcn ^ " does not admit equality")
      else if not (List.null cons) andalso not (isSome (fcnIsName fcn)) then
        err (sp, "datatype " ^ pathString longid ^ " can only be identified with another type name")
      else IntMap.insert (phi, #stamp c, fcn)
    end

  fun whereFinish (sigma : sigma, phi : realisation) : sigma = realizeSigma (phi, sigma)

  (* Rule 78, sharing type longtycon1 = ... = longtyconn, and its derived
     form (Appendix A), sharing longstrid1 = ... = longstridn, which shares
     every type constructor specified in all of them, recursively. A run of
     sharing specifications is realised at once. The types its equations
     identify are classes of flexible names, by union-find: a class is
     named by the name the equations one at a time would have left it --
     the name of the first type of the equation that made it, as that
     equation found it -- and admits equality where one of its names does.
     The paths are looked up in the signature as the run found it, through
     the classes, so that each equation is checked, and its message given,
     as against the signature the equations before it realised. *)
  datatype equation = ShareTypes of Ast.longid list * Source.span | ShareStructures of Ast.longid list * Source.span

  fun shareRun ({bound, env} : sigma, eqns : equation list) : sigma =
    let
      val boundSet = List.foldl (fn (c, m) => IntMap.insert (m, #stamp c, ())) IntMap.empty bound
      (* the name each name was merged into, and the name of each class, by
         the stamp of its root *)
      val parent : int IntMap.map ref = ref IntMap.empty
      val names : tycon IntMap.map ref = ref IntMap.empty
      fun root s =
        case IntMap.find (!parent, s) of
          NONE => s
        | SOME p =>
            let val r = root p
            in if r <> p then parent := IntMap.insert (!parent, s, r) else (); r end
      (* the name a name of the signature stands for now *)
      fun now (c : tycon) : tycon =
        if not (IntMap.member (boundSet, #stamp c)) then c
        else getOpt (IntMap.find (!names, root (#stamp c)), c)
      fun flexible (longid, sp) : tycon =
        case findTy (env, longid) of
          NONE => err (sp, "unbound type constructor in signature: " ^ pathString longid)
        | SOME (TyStr {fcn, ...}) =>
            (case fcnIsName fcn of
               SOME c =>
                 if IntMap.member (boundSet, #stamp c) then now c
                 else err (sp, "type " ^ pathString longid ^ " is not a flexible type of the signature")
             | NONE => err (sp, "type " ^ pathString longid ^ " is already defined in the signature"))
      fun shareTypes (longids, sp) =
        let
          val () = if !ElabStats.on then ElabStats.count ElabStats.ShareTypes else ()
          val named = List.map (fn id => (id, flexible (id, sp))) longids
          val (id0, c0) = List.hd named
          val () = List.app (fn (id, c) =>
                                if #arity c <> #arity c0 then
                                  err (sp, "sharing type " ^ pathString id0 ^ " = " ^ pathString id ^ ": the types have different arities")
                                else ()) named
        in
          names := IntMap.insert (!names, #stamp c0, withEq (c0, List.exists (fn (_, c) => #eq c) named));
          List.app (fn (_, c) => if #stamp c = #stamp c0 then () else parent := IntMap.insert (!parent, #stamp c, #stamp c0))
                   named
        end
      (* fcnEqual of two type functions as they are now *)
      fun equalNow (t1 : ty, t2 : ty) : bool =
        case (prune t1, prune t2) of
          (TVar r1, TVar r2) => r1 = r2
        | (TCon (c1, a1), TCon (c2, a2)) =>
            #stamp (now c1) = #stamp (now c2) andalso List.length a1 = List.length a2 andalso ListPair.all equalNow (a1, a2)
        | (TRecord f1, TRecord f2) =>
            List.length f1 = List.length f2
            andalso ListPair.all (fn ((l1, a), (l2, b)) => l1 = l2 andalso equalNow (a, b)) (f1, f2)
        | (TArrow (a1, b1), TArrow (a2, b2)) => equalNow (a1, a2) andalso equalNow (b1, b2)
        | _ => false
      fun fcnEqualNow (f1 : tyfcn, f2 : tyfcn) : bool =
        fcnArity f1 = fcnArity f2
        andalso
        let val args = List.tabulate (fcnArity f1, fn _ => TCon (freshTycon ("?", 0, true), []))
        in equalNow (applyFcn (f1, args), applyFcn (f2, args)) end
      fun shareStructures (longids, sp) =
        let
          val () = if !ElabStats.on then ElabStats.count ElabStats.ShareStructures else ()
          fun envAt path =
            case findStr (env, path) of
              SOME e => e
            | NONE => err (sp, "unbound structure in sharing specification: " ^ String.concatWith "." path)
          (* type paths (relative) common to two structures *)
          fun common (e1 : env, e2 : env, rel : string list) : string list list =
            let
              val ts = StringMap.foldri (fn (n, _, acc) =>
                                            case StringMap.find (tys e2, n) of SOME _ => (rel @ [n]) :: acc | NONE => acc)
                                        [] (tys e1)
              val subs = StringMap.foldri (fn (n, s1, acc) =>
                                              case StringMap.find (strs e2, n) of SOME s2 => common (s1, s2, rel @ [n]) @ acc | NONE => acc)
                                          [] (strs e1)
            in ts @ subs end
          fun pairs [] = []
            | pairs (x :: rest) = List.map (fn y => (x, y)) rest @ pairs rest
          fun toLongid path = (List.take (path, List.length path - 1), List.last path)
          fun fcnAt id = case findTy (env, id) of SOME (TyStr {fcn, ...}) => fcn | NONE => Error.bug "shareStructures"
          fun sharePair (p1, p2) =
            List.app (fn rel =>
                         let
                           val id1 = toLongid (p1 @ rel)
                           val id2 = toLongid (p2 @ rel)
                         in if fcnEqualNow (fcnAt id1, fcnAt id2) then () else shareTypes ([id1, id2], sp) end)
                     (common (envAt p1, envAt p2, []))
        in
          List.app sharePair (pairs (List.map (fn (p, n) => p @ [n]) longids))
        end
      val () = List.app (fn ShareTypes (ids, sp) => shareTypes (ids, sp)
                          | ShareStructures (ids, sp) => shareStructures (ids, sp)) eqns
      (* a class keeps its name's place among the flexible names *)
      val bound' = List.mapPartial (fn c => let val c' = now c in if #stamp c' = #stamp c then SOME c' else NONE end) bound
      val phi = List.foldl (fn (c, m) =>
                               let val c' = now c
                               in if #stamp c' = #stamp c andalso #eq c' = #eq c then m else IntMap.insert (m, #stamp c, TName c') end)
                           IntMap.empty bound
    in
      {bound = bound', env = realizeEnv (phi, env)}
    end

  (* --- enrichment (Section 5.9) --- *)

  (* Replace the generic variables of a scheme by fresh nullary type names. *)
  fun skolemize (scheme : scheme) : ty * int list =
    let
      val memo : (int * ty) list ref = ref []
      val skolems : int list ref = ref []
      fun copy t =
        case prune t of
          t as TVar r =>
            (case !r of
               Unbound {id, level, eq, ...} =>
                 if level = genericLevel then
                   (case List.find (fn (i, _) => i = id) (!memo) of
                      SOME (_, t') => t'
                    | NONE =>
                      let val c = freshTycon (if eq then "''a" else "'a", 0, eq)
                          val t' = TCon (c, [])
                      in memo := (id, t') :: !memo; skolems := #stamp c :: !skolems; t' end)
                 else t
             | Bound _ => Error.bug "skolemize")
        | TCon (c, args) => TCon (c, List.map copy args)
        | TRecord fields => TRecord (List.map (fn (l, a) => (l, copy a)) fields)
        | TArrow (a, b) => TArrow (copy a, copy b)
      val t = copy scheme
    in (t, !skolems) end

  fun mentions (stamps : int list, t : ty) : bool =
    case prune t of
      TVar _ => false
    | TCon (c, args) => List.exists (fn s => s = #stamp c) stamps orelse List.exists (fn a => mentions (stamps, a)) args
    | TRecord fields => List.exists (fn (_, a) => mentions (stamps, a)) fields
    | TArrow (a, b) => mentions (stamps, a) orelse mentions (stamps, b)

  (* The structure's scheme must be at least as general as the signature's:
     an instance of the former unifies with the latter's skolemised body. *)
  (* what names the value for a message, made only for one *)
  fun moreGeneral (actual : scheme, spec : scheme, what : unit -> string, sp) : unit =
    let
      val (specTy, skolems) = skolemize spec
      val printer = newPrinter ()
      fun mismatch reason =
        err (sp, "signature mismatch: " ^ what () ^ " has type " ^ toStringWith printer actual
                 ^ " in the structure but " ^ toStringWith printer spec ^ " in the signature" ^ reason)
    in
      (Unify.unify (Unify.instantiate (0, actual), specTy)
       handle Unify.Unify reason => mismatch (" (" ^ reason ^ ")"));
      if mentions (skolems, actual) then mismatch " (the structure's type is less general)" else ()
    end

  (* Where the structure's scheme is the signature's own -- the same type,
     with the same generic variables, as an instance of the signature, a
     functor's parameter, passes on -- it is as general, and the
     unification is not made; the counters of type names and variables are
     moved as the check would have moved them (one name for each of the
     signature's generic variables, one variable for each of the
     structure's), so that every name made after it is the same. *)
  fun genericIds (t : ty, acc : int list) : int list option =
    case prune t of
      TVar (ref (Unbound {id, level, kind, ...})) =>
        if level <> genericLevel then SOME acc
        else (case kind of KFlex _ => NONE | _ => SOME (if List.exists (fn i => i = id) acc then acc else id :: acc))
    | TVar _ => SOME acc
    | TCon (_, args) => List.foldl (fn (a, SOME acc) => genericIds (a, acc) | (_, NONE) => NONE) (SOME acc) args
    | TRecord fields => List.foldl (fn ((_, a), SOME acc) => genericIds (a, acc) | (_, NONE) => NONE) (SOME acc) fields
    | TArrow (a, b) => (case genericIds (a, acc) of SOME acc => genericIds (b, acc) | NONE => NONE)

  fun atLeastAsGeneral (actual : scheme, spec : scheme, what : unit -> string, sp) : unit =
    if equalTy (actual, spec) then
      case (genericIds (spec, []), genericIds (actual, [])) of
        (SOME s, SOME a) => (tyconCounter := !tyconCounter + List.length s; tvarCounter := !tvarCounter + List.length a)
      | _ => moreGeneral (actual, spec, what, sp)
    else moreGeneral (actual, spec, what, sp)

  fun sameScheme (s1, s2, what, sp) = (atLeastAsGeneral (s1, s2, what, sp); atLeastAsGeneral (s2, s1, what, sp))

  fun schemeOf (v : valstatus) : scheme =
    case v of
      Val {scheme, ...} => scheme
    | Con {scheme, ...} => scheme
    | Exn {ty, ...} => ty
    | Prim {scheme, ...} => scheme
    | ConAsVal {scheme, ...} => scheme
    | ExnAsVal {ty, ...} => ty

  (* the names of the constructors in order, by a merge sort *)
  fun sortedNames (cons : (string * 'a) list) : string list =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if String.<= (x, y) then x :: merge (xs, y :: ys) else y :: merge (x :: xs, ys)
      fun sort [] = []
        | sort [x] = [x]
        | sort xs =
          let val k = List.length xs div 2
          in merge (sort (List.take (xs, k)), sort (List.drop (xs, k))) end
    in sort (List.map #1 cons) end

  (* Check that `actual` enriches the realised signature environment `specE`. *)
  fun checkEnrich (specE : env, actual : env, path : string list, sp) : unit =
    let
      fun name n = String.concatWith "." (path @ [n])
    in
      StringMap.appi
        (fn (n, TyStr {fcn = fs, cons = cs}) =>
            case StringMap.find (tys actual, n) of
              NONE => err (sp, "signature mismatch: type " ^ name n ^ " is not defined in the structure")
            | SOME (TyStr {fcn = fa, cons = ca}) =>
                (if fcnArity fs <> fcnArity fa then
                   err (sp, "signature mismatch: type " ^ name n ^ " has " ^ Int.toString (fcnArity fa)
                            ^ " parameter(s) in the structure but " ^ Int.toString (fcnArity fs) ^ " in the signature")
                 else if not (fcnEqual (fs, fa)) then
                   err (sp, "signature mismatch: type " ^ name n ^ " is " ^ fcnToString fa ^ " in the structure but "
                            ^ fcnToString fs ^ " in the signature")
                 else ();
                 if List.null cs then ()
                 else if sortedNames cs <> sortedNames ca then
                   err (sp, "signature mismatch: datatype " ^ name n ^ " has different constructors in the structure and the signature")
                 else ()))
        (tys specE);
      StringMap.appi
        (fn (n, sv) =>
            case StringMap.find (vals actual, n) of
              NONE => err (sp, "signature mismatch: value " ^ name n ^ " is not defined in the structure")
            | SOME av =>
                (case (sv, av) of
                   (Val {scheme, ...}, _) => atLeastAsGeneral (schemeOf av, scheme, fn () => "value " ^ name n, sp)
                 | (Con {scheme, ...}, Con {scheme = sa, ...}) => sameScheme (sa, scheme, fn () => "constructor " ^ name n, sp)
                 | (Con _, _) => err (sp, "signature mismatch: " ^ name n ^ " is a constructor in the signature but not in the structure")
                 | (Exn {ty, ...}, Exn {ty = ta, ...}) => sameScheme (ta, ty, fn () => "exception " ^ name n, sp)
                 | (Exn _, _) => err (sp, "signature mismatch: " ^ name n ^ " is an exception in the signature but not in the structure")
                 | _ => Error.bug "checkEnrich: unexpected status in signature"))
        (vals specE);
      StringMap.appi
        (fn (n, se) =>
            case StringMap.find (strs actual, n) of
              NONE => err (sp, "signature mismatch: structure " ^ name n ^ " is not defined in the structure")
            | SOME ae => checkEnrich (se, ae, path @ [n], sp))
        (strs specE)
    end

  (* The result of an ascription: the signature's types and schemes with the
     structure's stamps and constructor information. A constructor or
     exception matched by a value specification loses its status (5.9). *)
  fun mergeInfo (specE : env, actual : env) : env =
    let
      fun get (m, n) = case StringMap.find (m, n) of SOME x => x | NONE => Error.bug ("mergeInfo: missing " ^ n)
      val vals' =
        StringMap.mapi
          (fn (n, sv) =>
              case (sv, get (vals actual, n)) of
                (Val {scheme, ...}, Val {stamp, global, ...}) => Val {scheme = scheme, stamp = stamp, global = global}
              | (Val {scheme, ...}, Con {info, ...}) => ConAsVal {scheme = scheme, info = info}
              | (Val {scheme, ...}, ConAsVal {info, ...}) => ConAsVal {scheme = scheme, info = info}
              | (Val {scheme, ...}, Exn {info, ...}) => ExnAsVal {ty = scheme, info = info}
              | (Val {scheme, ...}, ExnAsVal {info, ...}) => ExnAsVal {ty = scheme, info = info}
              | (Val {scheme, ...}, Prim {name, ...}) => Prim {scheme = scheme, name = name}
              | (Con {scheme, ...}, Con {info, ...}) => Con {scheme = scheme, info = info}
              | (Exn {ty, ...}, Exn {info, ...}) => Exn {ty = ty, info = info}
              | _ => Error.bug "mergeInfo: status mismatch")
          (vals specE)
      val strs' = StringMap.mapi (fn (n, se) => mergeInfo (se, get (strs actual, n))) (strs specE)
      val tys' = StringMap.map (fn TyStr {fcn, cons} =>
                                   TyStr {fcn = fcn, cons = List.map (fn (c, _) => (c, get (vals', c))) cons})
                               (tys specE)
    in Env {vals = vals', tys = tys', strs = strs'} end

  (* Signature matching (Section 5.10): find the realisation of the flexible
     names from the structure's type components, then check enrichment.
     Returns the realisation and the realised signature environment. *)
  fun match ({bound, env = sigEnv} : sigma, actual : env, sp) : realisation * env =
    let
      val boundSet = List.foldl (fn (c, m) => IntMap.insert (m, #stamp c, ())) IntMap.empty bound
      fun one ((path, n, TyStr {fcn, cons}), phi) =
        case fcn of
          TName c =>
            if IntMap.member (boundSet, #stamp c) andalso not (IntMap.member (phi, #stamp c)) then
              (case findTy (actual, (path, n)) of
                 NONE => err (sp, "signature mismatch: type " ^ pathString (path, n) ^ " is not defined in the structure")
               | SOME (TyStr {fcn = fa, ...}) =>
                   if fcnArity fa <> #arity c then
                     err (sp, "signature mismatch: type " ^ pathString (path, n) ^ " has " ^ Int.toString (fcnArity fa)
                              ^ " parameter(s) in the structure but " ^ Int.toString (#arity c) ^ " in the signature")
                   else if #eq c andalso not (fcnAdmitsEq fa) then
                     err (sp, "signature mismatch: type " ^ pathString (path, n) ^ " must admit equality but "
                              ^ fcnToString fa ^ " does not")
                   else if not (List.null cons) andalso not (isSome (fcnIsName fa)) then
                     err (sp, "signature mismatch: " ^ pathString (path, n) ^ " is a datatype in the signature but not in the structure")
                   else IntMap.insert (phi, #stamp c, fa))
            else phi
        | TAbbrev _ => phi
      val paths = tyPaths sigEnv
      val () = if !ElabStats.on then (ElabStats.count ElabStats.MatchSig; ElabStats.add (ElabStats.MatchPaths, List.length paths))
               else ()
      val phi = List.foldl one IntMap.empty paths
      val specE = realizeEnv (phi, sigEnv)
    in
      checkEnrich (specE, actual, [], sp);
      (phi, specE)
    end

  (* Rules 52 and 53. *)
  fun ascribe (sigma as {bound, env} : sigma, actual : env, opaque : bool, sp) : env =
    let val (phi, specE) = match (sigma, actual, sp)
    in
      if not opaque then mergeInfo (specE, actual)
      else
        let
          (* each fresh name stands for what the structure made its type,
             which the intermediate representations see through (Ty) *)
          fun abstract (c : Types.tycon, m) =
            let val c' = freshTycon (#name c, #arity c, #eq c)
            in
              case IntMap.find (phi, #stamp c) of
                SOME fcn => Ty.bindRealization (#stamp c', fcn)
              | NONE => ();
              IntMap.insert (m, #stamp c, TName c')
            end
          val rho = List.foldl abstract IntMap.empty bound
        in mergeInfo (realizeEnv (rho, env), actual) end
    end
end
