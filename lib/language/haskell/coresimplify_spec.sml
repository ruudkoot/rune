(* Specialisation at known dictionaries (coresimplify_sig.sml; the
   haskell98 roadmap's M23, D49's C, with what Augustsson 1993 adds).

   An overloaded function is a lambda whose binders are types, then
   dictionaries, then the rest. Where it is applied to closed types and to
   dictionaries that are constants of the top level, the application is
   made one of a copy of it at those types and dictionaries, made once for
   them: the copy is the function's body with its types and dictionaries
   given, simplified as an inlined body is, so that a method selected from
   a dictionary it now knows is the instance's function. A dictionary
   function applied so is a dictionary made once, a constant itself, and
   the functions given it are specialised in turn.

   A local overloaded binding, a let or letrec of an overloaded lambda, is
   copied the same way beside itself where its scope applies it to closed
   types and constant dictionaries: a specialised `sum` whose local `sum'`
   stayed overloaded "is hardly an improvement" (Augustsson 1993, §5.4).

   Fuel bounds it, since polymorphic recursion makes the dictionaries a
   function is given without end (Augustsson 1993, fig 9; Jones 1995): so
   many copies in all, and so many of one function. *)
structure CoreSimplifySpec =
struct
  open Core
  structure B = CoreSimplifyBase
  structure S = CoreSimplifySimp

  (* the copies made in all, and of one function *)
  val maxCopies = 3000
  val maxPerFunction = 24

  (* an overloaded lambda: its type binders, its dictionary binders, the
     binders after them and its body *)
  type overloaded = {tybs : int, dicts : int, binders : binder list, body : exp, ty : ty}

  fun overloadedOf (dt : B.datatypes) (t : ty, e : exp) : overloaded option =
    case e of
      Lam (bs, body) =>
        let
          fun tys (TyBinder _ :: rest, n) = tys (rest, n + 1)
            | tys (rest, n) = (rest, n)
          fun dicts (ValBinder (_, t) :: rest, n) = if B.isDictTy dt t then dicts (rest, n + 1) else n
            | dicts (_, n) = n
          val (afterTys, n) = tys (bs, 0)
          val k = dicts (afterTys, 0)
        in
          if k = 0 then NONE else SOME {tybs = n, dicts = k, binders = bs, body = body, ty = t}
        end
    | _ => NONE

  (* t at the types tys, without its first k parameters *)
  fun instantiateTy (t : ty, tys : ty list, k : int) : ty =
    let
      fun foralls (TForall (a, _, b), u :: us) = foralls (substTy ([(a, u)], b), us)
        | foralls (t, []) = t
        | foralls (_, _) = raise Fail "CoreSimplify: a type given more types than it binds"
      fun params (t, 0) = t
        | params (TFun (_, r), n) = params (r, n - 1)
        | params (_, _) = raise Fail "CoreSimplify: a type given more dictionaries than it takes"
    in params (foralls (stripEval t, tys), k) end

  (* the types and dictionaries an application gives an overloaded
     function, and what it gives after them; NONE where it gives fewer *)
  fun split (ov : overloaded, args : arg list) : (ty list * atom list * arg list) option =
    let
      fun tys (0, rest, acc) = SOME (List.rev acc, rest)
        | tys (n, TyArg t :: rest, acc) = tys (n - 1, rest, t :: acc)
        | tys (_, _, _) = NONE
      fun dicts (0, rest, acc) = SOME (List.rev acc, rest)
        | dicts (n, ValArg a :: rest, acc) = dicts (n - 1, rest, a :: acc)
        | dicts (_, _, _) = NONE
    in
      case tys (#tybs ov, args, []) of
        NONE => NONE
      | SOME (ts, rest) =>
          case dicts (#dicts ov, rest, []) of
            NONE => NONE
          | SOME (ds, rest') => SOME (ts, ds, rest')
    end

  fun member (x, xs) = List.exists (fn y => y = x) xs

  (* ---- A round ---- *)

  (* `round p` is p with each application of an overloaded value of the top
     level, or of a local one, to closed types and constant dictionaries
     made one of a copy; how many copies it made *)
  fun round (p : program) : program * int =
    let
      val dt = B.datatypes p
      val () = S.prepare p
      val overloads = ref (List.foldl (fn (Val (x, t, e), m) =>
                                           (case overloadedOf dt (t, e) of SOME ov => CoreMap.insert (m, x, ov) | NONE => m)
                                         | (_, m) => m)
                                      CoreMap.empty p)
      fun constantTy t = B.isDictTy dt t andalso null (freeTyVars t)
                         andalso (case stripEval t of TForall _ => false | TFun _ => false | _ => true)
      val constants = ref (List.foldl (fn (Val (x, t, _), m) => if constantTy t then CoreMap.insert (m, x, true) else m
                                        | (Import (x, t), m) => if constantTy t then CoreMap.insert (m, x, true) else m
                                        | (_, m) => m)
                                      CoreMap.empty p)
      val taken = ref (List.foldl (fn (Val (x, _, _), m) => CoreMap.insert (m, x, true)
                                    | (Import (x, _), m) => CoreMap.insert (m, x, true)
                                    | (_, m) => m)
                                  CoreMap.empty p)
      val memo = ref (CoreMap.empty : string CoreMap.map)
      val perFunction = ref (CoreMap.empty : int CoreMap.map)
      val made = ref ([] : decl list)
      val copies = ref 0
      fun isConstant (Var g) = CoreMap.member (!constants, g)
        | isConstant (Lit _) = false
      fun closed tys = List.all (fn t => null (freeTyVars t)) tys
      fun keyOf (f, tys, ds) =
        String.concatWith "\t" (f :: List.map CoreText.showTy tys @ List.map (fn Var g => g | Lit l => CoreText.showLit l) ds)
      fun nameFor (f, tys) =
        let val n = f ^ "{" ^ String.concatWith "," (List.map CoreText.showTy tys) ^ "}"
        in if CoreMap.member (!taken, n) then B.fresh n else n end
      fun budget f =
        !copies < maxCopies andalso getOpt (CoreMap.find (!perFunction, f), 0) < maxPerFunction
      fun spend f =
        (copies := !copies + 1; perFunction := CoreMap.insert (!perFunction, f, getOpt (CoreMap.find (!perFunction, f), 0) + 1))

      (* ---- The walk ---- *)

      (* e with its specialisable applications made those of copies; tvs
         the type variables in scope *)
      fun walk (tvs : string list) (e : exp) : exp =
        case e of
          Atom _ => e
        | App (Atom (Var f), args) => (case global (f, args) of SOME e' => e' | NONE => e)
        | App (f, args) => App (walk tvs f, args)
        | Lam (bs, b) => Lam (bs, walk (List.foldl (fn (TyBinder (a, _), acc) => a :: acc | (_, acc) => acc) tvs bs) b)
        | Let (x, t, r, b) =>
            let val r' = walk tvs r
                val b' = walk tvs b
            in localLet (tvs, x, t, r', b') end
        | LetRec (bs, b) =>
            let val bs' = List.map (fn (x, t, r) => (x, t, walk tvs r)) bs
                val b' = walk tvs b
            in localRec (tvs, bs', b') end
        | Case (s, b, alts) => Case (walk tvs s, b, List.map (S.mapRhs (walk tvs)) alts)
        | Cast (e, t) => Cast (walk tvs e, t)
        | _ => e

      (* an application of the global f, to its copy where it has one or
         may be given one *)
      and global (f : string, args : arg list) : exp option =
        case CoreMap.find (!overloads, f) of
          NONE => NONE
        | SOME ov =>
            case split (ov, args) of
              NONE => NONE
            | SOME (tys, ds, rest) =>
                if not (closed tys andalso List.all isConstant ds) then NONE
                else
                  let
                    val key = keyOf (f, tys, ds)
                    val name =
                      case CoreMap.find (!memo, key) of
                        SOME n => SOME n
                      | NONE =>
                          if budget f andalso not (S.losesEval (#binders ov, #body ov, List.map TyArg tys @ List.map ValArg ds))
                             andalso B.tick "specialise"
                          then SOME (copy (f, ov, tys, ds, key)) else NONE
                  in
                    case name of
                      SOME n => SOME (case rest of [] => Atom (Var n) | _ => App (Atom (Var n), rest))
                    | NONE => NONE
                  end

      (* the copy of f at tys and ds, named, made and walked in turn *)
      and copy (f, ov : overloaded, tys, ds, key) : string =
        let
          val name = nameFor (f, tys)
          val () = memo := CoreMap.insert (!memo, key, name)
          val () = taken := CoreMap.insert (!taken, name, true)
          val () = spend f
          val t = instantiateTy (#ty ov, tys, #dicts ov)
          val () = if constantTy t then constants := CoreMap.insert (!constants, name, true) else ()
          val body = S.instantiate ([f, name], #binders ov, #body ov, List.map TyArg tys @ List.map ValArg ds)
          (* the copy is itself overloaded no more; what it applies is
             specialised in turn *)
          val body = walk [] body
          val () = made := Val (name, t, body) :: !made
        in name end

      (* a let of an overloaded lambda, with copies beside it for its body's
         applications to closed types and constant dictionaries *)
      and localLet (tvs, x, t, r, b) =
        case overloadedOf dt (t, r) of
          NONE => Let (x, t, r, b)
        | SOME ov =>
            let
              val copies = ref []
              val b' = rewrite (x, localSpec (tvs, x, ov, copies)) b
            in
              Let (x, t, r, List.foldl (fn ((y, ty, e), body) => Let (y, ty, e, body)) b' (!copies))
            end

      (* a letrec, with copies of its overloaded lambdas in the group *)
      and localRec (tvs, bs, b) =
        let
          val overloadedHere = List.mapPartial (fn (x, t, r) => Option.map (fn ov => (x, ov)) (overloadedOf dt (t, r))) bs
        in
          case overloadedHere of
            [] => LetRec (bs, b)
          | _ =>
              let
                val copies = ref []
                val rewrites = List.map (fn (x, ov) => (x, localSpec (tvs, x, ov, copies))) overloadedHere
                fun rewriteAll e = List.foldl (fn ((x, f), e) => rewrite (x, f) e) e rewrites
                (* the group's rhs and body rewritten, then each new copy's,
                   until none is made *)
                val bs' = List.map (fn (x, t, r) => (x, t, rewriteAll r)) bs
                val b' = rewriteAll b
                fun settle (done, n) =
                  let val now = !copies
                  in
                    if length now = n then done
                    else
                      let
                        val fresh = List.take (now, length now - n)
                        val again = List.map (fn (y, t, e) => (y, t, rewriteAll e)) fresh
                      in
                        (* the rewritten copies stand for those made *)
                        settle (done @ again, length now)
                      end
                  end
                val made = settle ([], 0)
              in LetRec (bs' @ made, b') end
        end

      (* what an application of the local overloaded x becomes: one of its
         copy at closed types and constant dictionaries, made beside it *)
      and localSpec (tvs, x, ov : overloaded, copies) : arg list -> exp option =
        let
          val memoL = ref (CoreMap.empty : string CoreMap.map)
          val count = ref 0
        in
          fn args =>
            case split (ov, args) of
              NONE => NONE
            | SOME (tys, ds, rest) =>
                if not (List.all (fn t => List.all (fn a => member (a, tvs)) (freeTyVars t)) tys andalso List.all isConstant ds)
                then NONE
                else
                  let
                    val key = keyOf (x, tys, ds)
                    val name =
                      case CoreMap.find (!memoL, key) of
                        SOME n => SOME n
                      | NONE =>
                          if !count < maxPerFunction
                             andalso not (S.losesEval (#binders ov, #body ov, List.map TyArg tys @ List.map ValArg ds))
                             andalso B.tick "specialise-local" then
                            let
                              val y = B.fresh x
                              val () = memoL := CoreMap.insert (!memoL, key, y)
                              val () = count := !count + 1
                              val t = instantiateTy (#ty ov, tys, #dicts ov)
                              val e = S.instantiate ([], #binders ov, #body ov, List.map TyArg tys @ List.map ValArg ds)
                              val () = copies := (y, t, e) :: !copies
                            in SOME y end
                          else NONE
                  in
                    case name of
                      SOME n => SOME (case rest of [] => Atom (Var n) | _ => App (Atom (Var n), rest))
                    | NONE => NONE
                  end
        end

      (* e with each application of x given to f, made what f makes of it *)
      and rewrite (x : string, f : arg list -> exp option) (e : exp) : exp =
        let
          fun go e =
            case e of
              App (Atom (Var y), args) => if y = x then getOpt (f args, e) else e
            | App (g, args) => App (go g, args)
            | Lam (bs, b) => Lam (bs, go b)
            | Let (y, t, r, b) => Let (y, t, go r, go b)
            | LetRec (bs, b) => LetRec (List.map (fn (y, t, r) => (y, t, go r)) bs, go b)
            | Case (s, b, alts) => Case (go s, b, List.map (S.mapRhs go) alts)
            | Cast (e, t) => Cast (go e, t)
            | _ => e
        in go e end

      fun decl d =
        case d of
          Val (x, t, e) => Val (x, t, walk [] e)
        | _ => d
      val p' = List.map decl p
    in
      (p' @ List.rev (!made), !copies)
    end
end
