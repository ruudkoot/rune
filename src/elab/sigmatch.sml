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

  fun fcnToString (TName c) = #name c
    | fcnToString (TAbbrev (_, body)) = toString body

  (* Rule 65: every use of a signature gets fresh bound names. *)
  fun instantiate ({bound, env} : sigma) : sigma =
    let
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

  (* The flexible type name a path of the signature denotes. *)
  fun flexibleAt ({bound, env} : sigma, longid, sp) : tycon * (string * valstatus) list =
    case findTy (env, longid) of
      NONE => err (sp, "unbound type constructor in signature: " ^ pathString longid)
    | SOME (TyStr {fcn, cons}) =>
        (case fcnIsName fcn of
           SOME c =>
             if isBound (bound, c) then (c, cons)
             else err (sp, "type " ^ pathString longid ^ " is not a flexible type of the signature")
         | NONE => err (sp, "type " ^ pathString longid ^ " is already defined in the signature"))

  (* Rule 64: sigexp where type tyvarseq longtycon = ty *)
  fun whereType (sigma : sigma, longid, fcn : tyfcn, sp) : sigma =
    let val (c, cons) = flexibleAt (sigma, longid, sp)
    in
      if fcnArity fcn <> #arity c then
        err (sp, "type " ^ pathString longid ^ " has " ^ Int.toString (#arity c) ^ " parameter(s) but its definition has "
                 ^ Int.toString (fcnArity fcn))
      else if #eq c andalso not (fcnAdmitsEq fcn) then
        err (sp, "type " ^ pathString longid ^ " is an equality type but " ^ fcnToString fcn ^ " does not admit equality")
      else if not (List.null cons) andalso not (isSome (fcnIsName fcn)) then
        err (sp, "datatype " ^ pathString longid ^ " can only be identified with another type name")
      else realizeSigma (IntMap.insert (IntMap.empty, #stamp c, fcn), sigma)
    end

  (* Rule 78: sharing type longtycon1 = ... = longtyconn *)
  fun shareTypes (sigma as {bound, env} : sigma, longids, sp) : sigma =
    let
      val named = List.map (fn id => (id, #1 (flexibleAt (sigma, id, sp)))) longids
      val (id0, c0) = List.hd named
      val () = List.app (fn (id, c) =>
                            if #arity c <> #arity c0 then
                              err (sp, "sharing type " ^ pathString id0 ^ " = " ^ pathString id ^ ": the types have different arities")
                            else ()) named
      val c0' = withEq (c0, List.exists (fn (_, c) => #eq c) named)
      val phi = List.foldl (fn ((_, c), m) => IntMap.insert (m, #stamp c, TName c0')) IntMap.empty named
      val bound' = List.map (fn c => if sameTycon (c, c0) then c0' else c)
                            (List.filter (fn c => sameTycon (c, c0) orelse not (IntMap.member (phi, #stamp c))) bound)
    in {bound = bound', env = realizeEnv (phi, env)} end

  (* Derived form (Appendix A): sharing longstrid1 = ... = longstridn shares
     every type constructor specified in all of them, recursively. *)
  fun shareStructures (sigma : sigma, longids, sp) : sigma =
    let
      fun envAt (sigma : sigma, path) =
        case findStr (#env sigma, path) of
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
      fun sharePair ((p1, p2), sigma) =
        List.foldl (fn (rel, sigma : sigma) =>
                       let
                         val id1 = toLongid (p1 @ rel)
                         val id2 = toLongid (p2 @ rel)
                         val f1 = case findTy (#env sigma, id1) of SOME (TyStr {fcn, ...}) => fcn | NONE => Error.bug "shareStructures"
                         val f2 = case findTy (#env sigma, id2) of SOME (TyStr {fcn, ...}) => fcn | NONE => Error.bug "shareStructures"
                       in if fcnEqual (f1, f2) then sigma else shareTypes (sigma, [id1, id2], sp) end)
                   sigma (common (envAt (sigma, p1), envAt (sigma, p2), []))
    in
      List.foldl sharePair sigma (pairs (List.map (fn (p, n) => p @ [n]) longids))
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
  fun moreGeneral (actual : scheme, spec : scheme, what : string, sp) : unit =
    let
      val (specTy, skolems) = skolemize spec
      val printer = newPrinter ()
      fun mismatch reason =
        err (sp, "signature mismatch: " ^ what ^ " has type " ^ toStringWith printer actual
                 ^ " in the structure but " ^ toStringWith printer spec ^ " in the signature" ^ reason)
    in
      (Unify.unify (Unify.instantiate (0, actual), specTy)
       handle Unify.Unify reason => mismatch (" (" ^ reason ^ ")"));
      if mentions (skolems, actual) then mismatch " (the structure's type is less general)" else ()
    end

  fun sameScheme (s1, s2, what, sp) = (moreGeneral (s1, s2, what, sp); moreGeneral (s2, s1, what, sp))

  fun schemeOf (v : valstatus) : scheme =
    case v of
      Val {scheme, ...} => scheme
    | Con {scheme, ...} => scheme
    | Exn {ty, ...} => ty
    | Prim {scheme, ...} => scheme
    | ConAsVal {scheme, ...} => scheme
    | ExnAsVal {ty, ...} => ty

  fun sortedNames (cons : (string * 'a) list) : string list =
    let
      fun ins (x, []) = [x]
        | ins (x, y :: ys) = if String.<= (x, y) then x :: y :: ys else y :: ins (x, ys)
    in List.foldl ins [] (List.map #1 cons) end

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
                   (Val {scheme, ...}, _) => moreGeneral (schemeOf av, scheme, "value " ^ name n, sp)
                 | (Con {scheme, ...}, Con {scheme = sa, ...}) => sameScheme (sa, scheme, "constructor " ^ name n, sp)
                 | (Con _, _) => err (sp, "signature mismatch: " ^ name n ^ " is a constructor in the signature but not in the structure")
                 | (Exn {ty, ...}, Exn {ty = ta, ...}) => sameScheme (ta, ty, "exception " ^ name n, sp)
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
      fun one ((path, n, TyStr {fcn, cons}), phi) =
        case fcn of
          TName c =>
            if isBound (bound, c) andalso not (IntMap.member (phi, #stamp c)) then
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
      val phi = List.foldl one IntMap.empty (tyPaths sigEnv)
      val specE = realizeEnv (phi, sigEnv)
    in
      checkEnrich (specE, actual, [], sp);
      (phi, specE)
    end

  (* Rules 52 and 53. *)
  fun ascribe (sigma as {bound, env} : sigma, actual : env, opaque : bool, sp) : env =
    let val (_, specE) = match (sigma, actual, sp)
    in
      if not opaque then mergeInfo (specE, actual)
      else
        let
          val rho = List.foldl (fn (c, m) => IntMap.insert (m, #stamp c, TName (freshTycon (#name c, #arity c, #eq c))))
                               IntMap.empty bound
        in mergeInfo (realizeEnv (rho, env), actual) end
    end
end
