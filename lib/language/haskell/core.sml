(* Core: its terms and types, and what is done to types (core_sig.sml). *)
structure Core : CORE =
struct
  datatype kind = Star | Unlifted | Arrow of kind * kind

  datatype ty =
      TVar of string
    | TCon of string
    | TApp of ty * ty
    | TFun of ty * ty
    | TForall of string * kind * ty
    | TEval of ty
    | TUTuple of ty list

  datatype lit =
      LInt of IntInf.int
    | LInteger of IntInf.int
    | LChar of int
    | LDouble of string
    | LFloat of string
    | LStr of string

  datatype atom = Var of string | Lit of lit

  datatype arg = TyArg of ty | ValArg of atom

  datatype binder = TyBinder of string * kind | ValBinder of string * ty

  datatype exp =
      Atom of atom
    | App of exp * arg list
    | Lam of binder list * exp
    | Let of string * ty * exp * exp
    | LetRec of (string * ty * exp) list * exp
    | Case of exp * string * alt list
    | Con of string * ty list * atom list
    | Prim of string * ty list * atom list
    | UTuple of atom list
    | Cast of exp * ty
  and alt =
      AltCon of string * string list * exp
    | AltLit of lit * exp
    | AltUTuple of string list * exp
    | AltDefault of exp

  datatype decl =
      Data of string * (string * kind) list * (string * ty list) list
    | Newtype of string * (string * kind) list * string * ty
    | Val of string * ty * exp
    | Import of string * ty

  type program = decl list

  val builtinTypes =
    [("Int", Star), ("Integer", Star), ("Char", Star), ("Double", Star), ("Float", Star), ("Str", Star),
     ("Exn", Star), ("Bool", Star), ("World", Unlifted), ("Ref", Arrow (Star, Star)),
     ("Arr", Arrow (Star, Star)), ("->", Arrow (Star, Arrow (Star, Star)))]

  val builtinData = [Data ("Bool", [], [("False", []), ("True", [])])]

  fun stripEval (TEval t) = t
    | stripEval t = t

  fun isEval (TEval _) = true
    | isEval _ = false

  fun spine t =
    let
      fun go (TApp (f, a), args) = go (f, a :: args)
        | go (h, args) = (h, args)
    in go (t, []) end

  (* `f` applied to `a`: the function type where `->` has both its
     arguments, so that a type holds one form of it *)
  fun app (TApp (TCon "->", x), a) = TFun (x, a)
    | app (f, a) = TApp (f, a)
  fun apply (t, args) = List.foldl (fn (a, f) => app (f, a)) t args

  fun member (x, xs) = List.exists (fn y => y = x) xs

  fun freeTyVars t =
    let
      fun go (bound, t, acc) =
        case t of
          TVar a => if member (a, bound) orelse member (a, acc) then acc else a :: acc
        | TCon _ => acc
        | TApp (f, a) => go (bound, a, go (bound, f, acc))
        | TFun (a, b) => go (bound, b, go (bound, a, acc))
        | TForall (a, _, b) => go (a :: bound, b, acc)
        | TEval a => go (bound, a, acc)
        | TUTuple ts => List.foldl (fn (t, acc) => go (bound, t, acc)) acc ts
    in List.rev (go ([], t, [])) end

  (* a name like `a`, not among `used`: `a1`, `a2`, ... *)
  fun fresh (a, used) =
    let fun try n = let val b = a ^ Int.toString n in if member (b, used) then try (n + 1) else b end
    in try 1 end

  fun substTy (s, t) =
    case s of
      [] => t
    | _ =>
        case t of
          TVar a => (case List.find (fn (b, _) => b = a) s of SOME (_, u) => u | NONE => t)
        | TCon _ => t
        | TApp (f, a) => app (substTy (s, f), substTy (s, a))
        | TFun (a, b) => TFun (substTy (s, a), substTy (s, b))
        | TEval a => TEval (substTy (s, a))
        | TUTuple ts => TUTuple (List.map (fn t => substTy (s, t)) ts)
        | TForall (a, k, b) =>
            let
              val s' = List.filter (fn (c, _) => c <> a) s
              val free = List.concat (List.map (fn (_, u) => freeTyVars u) s')
            in
              if member (a, free) then
                let val a' = fresh (a, free @ freeTyVars b @ List.map #1 s')
                in TForall (a', k, substTy ((a, TVar a') :: s', b)) end
              else TForall (a, k, substTy (s', b))
            end

  fun equalTy (a, b) =
    let
      (* env pairs the variables bound on the left with those on the right *)
      fun eq (env, TVar x, TVar y) =
            (case List.find (fn (l, r) => l = x orelse r = y) env of
               SOME (l, r) => l = x andalso r = y
             | NONE => x = y)
        | eq (_, TCon x, TCon y) = x = y
        | eq (env, TApp (TApp (TCon "->", p), r), t) = eq (env, TFun (p, r), t)
        | eq (env, t, TApp (TApp (TCon "->", p), r)) = eq (env, t, TFun (p, r))
        | eq (env, TApp (f, x), TApp (g, y)) = eq (env, f, g) andalso eq (env, x, y)
        | eq (env, TFun (p, r), TFun (q, s)) = eq (env, p, q) andalso eq (env, r, s)
        | eq (env, TForall (x, k, s), TForall (y, l, t)) = k = l andalso eq ((x, y) :: env, s, t)
        | eq (env, TEval s, TEval t) = eq (env, s, t)
        | eq (env, TUTuple ss, TUTuple ts) =
            List.length ss = List.length ts andalso ListPair.all (fn (s, t) => eq (env, s, t)) (ss, ts)
        | eq _ = false
    in eq ([], a, b) end

  fun litTy l =
    case l of
      LInt _ => TCon "Int"
    | LInteger _ => TCon "Integer"
    | LChar _ => TCon "Char"
    | LDouble _ => TCon "Double"
    | LFloat _ => TCon "Float"
    | LStr _ => TCon "Str"

  fun lamTy (binders, t) =
    List.foldr (fn (TyBinder (a, k), t) => TForall (a, k, t) | (ValBinder (_, p), t) => TFun (p, t)) t binders
end
