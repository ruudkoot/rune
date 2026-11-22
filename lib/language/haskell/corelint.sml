(* CoreLint: the rules of corelint_sig.sml. A type is checked where it is
   written, by where it stands (a slot, which may be `!`, or inside a type,
   which may not); an expression's type is worked out from its parts, and
   compared with what its place wants by `sub`, under which an evaluated
   value stands where a lazy one is wanted. *)
structure CoreLint : CORE_LINT =
struct
  open Core

  exception Error of string

  val rules =
    [("decl", "a name declared once; a newtype's field without !"),
     ("scope", "every variable bound"),
     ("tyscope", "every type variable bound, none with a type constructor's name, none bound again in its scope"),
     ("tycon", "every type constructor declared or built in"),
     ("kind", "every type of the kind its place wants"),
     ("eval", "! only at a binder, a parameter, a field or a component of an unboxed tuple, of a lifted type"),
     ("instantiate", "a type argument a lifted type without !, of its variable's kind"),
     ("app", "a function applied to the types and values its type takes"),
     ("force", "an atom given where an evaluated value is wanted is evaluated"),
     ("lit", "a literal in its type's range"),
     ("lambda", "a lambda binds something, each name once"),
     ("let", "a let of a lifted type, bound to an expression of it"),
     ("case", "alternatives of the scrutinee's type, that cover it and agree on their type"),
     ("con", "a constructor of a data type, given its types and fields"),
     ("prim", "a primitive of CorePrim, saturated"),
     ("cast", "a cast into or out of a newtype at its head"),
     ("val", "a value of the top level of its type"),
     ("main", "main of type World -> (utuple World T)")]

  datatype shape = Builtin | DataT of (string * ty list) list | NewT of string * ty
  type tycon = {kind : kind, params : (string * kind) list, shape : shape}
  type con = {tycon : string, params : (string * kind) list, fields : ty list}

  (* what the program declares *)
  type globals = {tycons : tycon CoreMap.map, cons : con CoreMap.map, vals : ty CoreMap.map}
  (* where a check is: the declaration, for the message *)
  type env = {g : globals, where' : string, vals : ty CoreMap.map, tyvars : kind CoreMap.map}

  val ty = CoreText.showTy
  fun breach (env : env, rule, msg) = raise Error ("[" ^ rule ^ "] " ^ #where' env ^ ": " ^ msg)

  fun showK k = CoreText.showKind k

  (* ---- Types where they are written ---- *)

  (* the kind of t, inside a type, where no ! stands at its head *)
  fun inner (env : env, what) t : kind =
    case t of
      TVar a =>
        (case CoreMap.find (#tyvars env, a) of
           SOME k => k
         | NONE => breach (env, "tyscope", "the type variable " ^ a ^ " of " ^ what ^ " is not bound"))
    | TCon c =>
        (case CoreMap.find (#tycons (#g env), c) of
           SOME {kind, ...} => kind
         | NONE => breach (env, "tycon", "the type constructor " ^ c ^ " of " ^ what ^ " is not declared"))
    | TApp (f, a) =>
        (case inner (env, what) f of
           Arrow (k1, k2) =>
             let val k = arg (env, what) a
             in if k = k1 then k2
                else breach (env, "kind", ty f ^ " takes a type of kind " ^ showK k1 ^ ", and " ^ ty a ^ " in " ^ what
                                         ^ " is of kind " ^ showK k)
             end
         | k => breach (env, "kind", ty f ^ " in " ^ what ^ " is of kind " ^ showK k ^ ", and is applied"))
    | TFun (a, b) => (value (env, what ^ "'s parameter") a; result (env, what) b; Star)
    | TForall (a, k, b) =>
        let
          val () = fresh (env, a)
          val env' = {g = #g env, where' = #where' env, vals = #vals env, tyvars = CoreMap.insert (#tyvars env, a, k)}
        in
          case inner (env', what) b of
            Star => Star
          | k => breach (env, "kind", "the body of a forall in " ^ what ^ " is of kind " ^ showK k)
        end
    | TEval _ => breach (env, "eval", "! inside " ^ what ^ ": " ^ ty t)
    | TUTuple ts => (List.app (value (env, "a component of " ^ what)) ts; Unlifted)

  (* a type argument of a type constructor: no !, and lifted *)
  and arg (env, what) t =
    case t of
      TEval _ => breach (env, "eval", "! on an argument of a type constructor in " ^ what ^ ": " ^ ty t)
    | _ => inner (env, what) t

  (* a function's result: no ! at its head, the type of a value *)
  and result (env, what) t =
    case t of
      TEval _ => breach (env, "eval", "! at the result of a function in " ^ what ^ ": " ^ ty t)
    | _ => valueKind (env, what) (inner (env, what) t)

  (* a slot: a binder, a parameter, a field or a component, which may be ! *)
  and slot (env, what) t : kind =
    case t of
      TEval u =>
        (case u of
           TEval _ => breach (env, "eval", "! twice in " ^ what)
         | _ => case inner (env, what) u of
                  Star => Star
                | k => breach (env, "eval", "! on " ^ ty u ^ " in " ^ what ^ ", of kind " ^ showK k))
    | _ => inner (env, what) t

  (* the type of a value in a slot: of kind * or # *)
  and value (env, what) t = valueKind (env, what) (slot (env, what) t)

  and valueKind (env, what) k =
    case k of
      Arrow _ => breach (env, "kind", what ^ " is of kind " ^ showK k ^ ", which is not a value's")
    | _ => ()

  (* a type variable bound where a type constructor has its name *)
  and fresh (env : env, a) =
    if CoreMap.member (#tycons (#g env), a)
    then breach (env, "tyscope", "the type variable " ^ a ^ " has the name of a type constructor")
    else ()

  (* a type of a lifted binding: inside a type, of kind * *)
  fun lifted (env, what, rule) t =
    case t of
      TEval _ => breach (env, "eval", "! on " ^ what ^ ", which is lazy: " ^ ty t)
    | _ =>
        case inner (env, what) t of
          Star => ()
        | k => breach (env, rule, what ^ " is of kind " ^ showK k ^ ": " ^ ty t)

  (* a type argument for a variable of kind k *)
  fun tyArg (env, what, k) t =
    case t of
      TEval _ => breach (env, "instantiate", what ^ " is instantiated at an evaluated type " ^ ty t)
    | _ =>
        let val k' = inner (env, what) t
        in
          if k' = Unlifted then breach (env, "instantiate", what ^ " is instantiated at an unlifted type " ^ ty t)
          else if k' <> k then breach (env, "instantiate", what ^ ", of kind " ^ showK k ^ ", is instantiated at "
                                                          ^ ty t ^ ", of kind " ^ showK k')
          else ()
        end

  (* ---- Types compared ---- *)

  fun member (x, xs) = List.exists (fn y => y = x) xs

  fun freshName (a, used) =
    let fun try n = let val b = a ^ "'" ^ Int.toString n in if member (b, used) then try (n + 1) else b end
    in try 1 end

  (* whether a value of type a stands where one of type e is wanted: the
     same type, but that an evaluated value stands for a lazy one at the
     head, in a component of an unboxed tuple, and in a function's result *)
  fun sub (a, e) =
    case (a, e) of
      (TEval a', TEval e') => equalTy (a', e')
    | (TEval a', _) => subInner (a', e)
    | (_, TEval _) => false
    | _ => subInner (a, e)
  and subInner (a, e) =
    case (a, e) of
      (TUTuple xs, TUTuple ys) => length xs = length ys andalso ListPair.all sub (xs, ys)
    | (TFun (p, r), TFun (q, s)) => equalTy (p, q) andalso subInner (r, s)
    | (TForall (x, k, b), TForall (y, l, c)) =>
        k = l andalso
        let val z = freshName ("v", x :: y :: freeTyVars b @ freeTyVars c)
        in subInner (substTy ([(x, TVar z)], b), substTy ([(y, TVar z)], c)) end
    | _ => equalTy (a, e)

  (* t without ! where sub lets an evaluated value stand for a lazy one *)
  fun relax t =
    case t of
      TEval u => relax u
    | TUTuple ts => TUTuple (List.map relax ts)
    | TFun (p, r) => TFun (p, relax r)
    | _ => t

  (* ---- Expressions ---- *)

  fun bindVal (env : env, x, t) =
    if x = "_" then env else {g = #g env, where' = #where' env, vals = CoreMap.insert (#vals env, x, t), tyvars = #tyvars env}
  (* a type variable bound by a lambda or a declaration: not one in scope
     already, whose name the types of the variables in scope may hold, which
     would then mean the new one *)
  fun bindTy (env : env, a, k) =
    (fresh (env, a);
     if CoreMap.member (#tyvars env, a) then breach (env, "tyscope", "the type variable " ^ a ^ " is bound again in its own scope")
     else ();
     {g = #g env, where' = #where' env, vals = #vals env, tyvars = CoreMap.insert (#tyvars env, a, k)})

  fun litCheck (env, l) =
    case l of
      LInt i => ((ignore (Int.fromLarge i); ()) handle Overflow => breach (env, "lit", "the Int " ^ IntInf.toString i ^ " is past Int's range"))
    | LChar c => if c < 0 orelse c > 1114111 then breach (env, "lit", "the Char " ^ Int.toString c ^ " is past Unicode's range") else ()
    | LDouble s => if isSome (Real.fromString s) then () else breach (env, "lit", "the Double " ^ s ^ " is not a number")
    | LFloat s => if isSome (Real.fromString s) then () else breach (env, "lit", "the Float " ^ s ^ " is not a number")
    | LInteger _ => ()
    | LStr _ => ()

  fun atomTy (env : env, a) =
    case a of
      Var x =>
        (case CoreMap.find (#vals env, x) of
           SOME t => t
         | NONE => breach (env, "scope", "the variable " ^ x ^ " is not bound"))
    | Lit l => (litCheck (env, l); TEval (litTy l))

  fun atomText (Var x) = x
    | atomText (Lit l) = CoreText.showLit l

  (* atom a given where a value of type p is wanted, the rule of a mismatch
     being `rule` *)
  fun give (env, rule, what) (a, p) =
    let val t = atomTy (env, a)
    in
      if sub (t, p) then ()
      else if isEval p andalso not (isEval t) andalso equalTy (relax t, relax (stripEval p))
      then breach (env, "force", atomText a ^ ", of type " ^ ty t ^ ", may be unevaluated where " ^ ty p
                                ^ " is wanted, " ^ what)
      else breach (env, rule, atomText a ^ " has type " ^ ty t ^ " where " ^ ty p ^ " is wanted, " ^ what)
    end

  (* the type of a function of type f applied to args *)
  fun applied (env, rule, what) (f, args) =
    List.foldl
      (fn (TyArg t, f) =>
            (case stripEval f of
               TForall (a, k, body) => (tyArg (env, "the type variable " ^ a ^ " of " ^ what, k) t; substTy ([(a, t)], body))
             | f => breach (env, rule, what ^ ", of type " ^ ty f ^ ", is given the type " ^ ty t))
        | (ValArg a, f) =>
            (case stripEval f of
               TFun (p, r) => (give (env, rule, "an argument of " ^ what) (a, p); r)
             | f => breach (env, rule, what ^ ", of type " ^ ty f ^ ", is given " ^ atomText a)))
      f args

  (* the head of an application, for messages *)
  fun headText e = case e of Atom a => atomText a | _ => "a function"

  fun lookupCon (env : env, rule, c) =
    case CoreMap.find (#cons (#g env), c) of
      SOME info => info
    | NONE => breach (env, rule, "the constructor " ^ c ^ " is not declared")

  (* the arguments of a data type or newtype at t, if it is one *)
  fun dataOf (env : env, t) =
    case spine t of
      (TCon c, args) =>
        (case CoreMap.find (#tycons (#g env), c) of
           SOME (info as {params, ...}) => if length params = length args then SOME (c, info, args) else NONE
         | NONE => NONE)
    | _ => NONE

  fun instFields (params : (string * kind) list, args, fields) =
    List.map (fn f => substTy (ListPair.map (fn ((a, _), t) => (a, t)) (params, args), f)) fields

  (* the type t unfolded once, where a newtype is at its head *)
  fun unfold (env, t) =
    case dataOf (env, t) of
      SOME (_, {params, shape = NewT (_, field), ...}, args) => SOME (hd (instFields (params, args, [field])))
    | _ => NONE

  fun isUnlifted (env : env, t) =
    case t of
      TUTuple _ => true
    | TCon c => (case CoreMap.find (#tycons (#g env), c) of SOME {kind = Unlifted, ...} => true | _ => false)
    | _ => false

  fun typeOf (env : env) (e : exp) : ty =
    case e of
      Atom a => atomTy (env, a)
    | App (f, args) =>
        if null args then breach (env, "app", headText f ^ " is applied to nothing")
        else applied (env, "app", headText f) (typeOf env f, args)
    | Lam (bs, body) =>
        let
          val () = if null bs then breach (env, "lambda", "a lambda binds nothing") else ()
          fun names [] = ()
            | names (b :: rest) =
                let val x = case b of TyBinder (a, _) => a | ValBinder (x, _) => x
                in
                  if x <> "_" andalso List.exists (fn TyBinder (a, _) => a = x | ValBinder (y, _) => y = x) rest
                  then breach (env, "lambda", "a lambda binds " ^ x ^ " twice")
                  else names rest
                end
          val () = names bs
          val env' = List.foldl (fn (TyBinder (a, k), env) => bindTy (env, a, k)
                                  | (ValBinder (x, t), env) => (value (env, "the binder " ^ x) t; bindVal (env, x, t)))
                                env bs
        in lamTy (bs, stripEval (typeOf env' body)) end
    | Let (x, t, rhs, body) =>
        let
          val () = lifted (env, "the binder " ^ x ^ " of a let", "let") t
          val r = typeOf env rhs
          val () = if sub (r, t) then ()
                   else breach (env, "let", "the let of " ^ x ^ ", of type " ^ ty t ^ ", is bound to an expression of type " ^ ty r)
        in stripEval (typeOf (bindVal (env, x, t)) body) end
    | LetRec (bs, body) =>
        let
          fun dup [] = ()
            | dup ((x, _, _) :: rest) =
                if List.exists (fn (y, _, _) => y = x) rest then breach (env, "let", "a letrec binds " ^ x ^ " twice")
                else dup rest
          val () = dup bs
          val () = List.app (fn (x, t, _) => lifted (env, "the binder " ^ x ^ " of a letrec", "let") t) bs
          val env' = List.foldl (fn ((x, t, _), env) => bindVal (env, x, t)) env bs
          val () = List.app (fn (x, t, rhs) =>
                               let val r = typeOf env' rhs
                               in if sub (r, t) then ()
                                  else breach (env, "let", "the letrec's " ^ x ^ ", of type " ^ ty t
                                                           ^ ", is bound to an expression of type " ^ ty r)
                               end) bs
        in stripEval (typeOf env' body) end
    | Case (scrut, b, alts) => caseOf env (scrut, b, alts)
    | Con (c, tys, atoms) =>
        let
          val {tycon, params, fields} = lookupCon (env, "con", c)
          val () = case CoreMap.find (#tycons (#g env), tycon) of
                     SOME {shape = NewT _, ...} => breach (env, "con", c ^ " is a newtype's constructor: cast to " ^ tycon)
                   | _ => ()
          val () = if length tys = length params then ()
                   else breach (env, "con", c ^ " takes " ^ Int.toString (length params) ^ " types, and is given "
                                            ^ Int.toString (length tys))
          val () = ListPair.app (fn ((a, k), t) => tyArg (env, "the parameter " ^ a ^ " of " ^ c, k) t) (params, tys)
          val fs = instFields (params, tys, fields)
          val () = if length atoms = length fs then ()
                   else breach (env, "con", c ^ " has " ^ Int.toString (length fs) ^ " fields, and is given "
                                            ^ Int.toString (length atoms))
          val () = ListPair.app (give (env, "con", "a field of " ^ c)) (atoms, fs)
        in apply (TCon tycon, tys) end
    | Prim (p, tys, atoms) =>
        let
          val {ty = pt, ...} =
            case CorePrim.find p of SOME prim => prim | NONE => breach (env, "prim", "no primitive is called " ^ p)
          fun foralls (TForall (_, _, b)) = 1 + foralls b | foralls _ = 0
          fun params (TFun (_, r)) = 1 + params r | params _ = 0
          val () = if length tys = foralls pt then ()
                   else breach (env, "prim", p ^ " takes " ^ Int.toString (foralls pt) ^ " types, and is given "
                                            ^ Int.toString (length tys))
          val inst = List.foldl (fn (_, TForall (_, _, b)) => b | (_, t) => t) pt tys
          val () = if length atoms = params inst then ()
                   else breach (env, "prim", p ^ " takes " ^ Int.toString (params inst) ^ " arguments, and is given "
                                            ^ Int.toString (length atoms))
        in applied (env, "prim", p) (pt, List.map TyArg tys @ List.map ValArg atoms) end
    | UTuple atoms => TUTuple (List.map (fn a => atomTy (env, a)) atoms)
    | Cast (e, t) =>
        let
          val () = lifted (env, "the type of a cast", "cast") t
          val te = stripEval (typeOf env e)
          fun to (a, b) = case unfold (env, a) of SOME u => equalTy (u, b) | NONE => false
        in
          if to (te, t) orelse to (t, te) then t
          else breach (env, "cast", "a cast from " ^ ty te ^ " to " ^ ty t ^ " unfolds no newtype at its head")
        end

  and caseOf env (scrut, b, alts) =
    let
      val st = stripEval (typeOf env scrut)
      val unlifted = isUnlifted (env, st)
      val env' = bindVal (env, b, if unlifted then st else TEval st)
      val (heads, default) =
        case List.rev alts of
          AltDefault rhs :: rest => (List.rev rest, SOME rhs)
        | _ => (alts, NONE)
      val () = if List.exists (fn AltDefault _ => true | _ => false) heads
               then breach (env, "case", "a default alternative that is not the last") else ()
      fun none what = if null heads then () else breach (env, "case", "a case on " ^ ty st ^ ", " ^ what ^ ", has alternatives other than _")
      (* each alternative's type, after the binders it binds *)
      val types =
        case dataOf (env, st) of
          SOME (c, {shape = DataT cons, params, ...}, args) =>
            let
              fun one (AltCon (k, xs, rhs), seen) =
                    (case List.find (fn (k', _) => k' = k) cons of
                       NONE => breach (env, "case", k ^ " is not a constructor of " ^ c)
                     | SOME (_, fields) =>
                         let
                           val fs = instFields (params, args, fields)
                           val () = if member (k, seen) then breach (env, "case", "two alternatives of " ^ k) else ()
                           val () = if length xs = length fs then ()
                                    else breach (env, "case", "the alternative of " ^ k ^ " binds " ^ Int.toString (length xs)
                                                             ^ " fields of " ^ Int.toString (length fs))
                           val env'' = ListPair.foldl (fn (x, f, env) => bindVal (env, x, f)) env' (xs, fs)
                         in (typeOf env'' rhs, k :: seen) end)
                | one (_, _) = breach (env, "case", "an alternative of a case on " ^ ty st ^ " is not a constructor's")
              val (ts, seen) = List.foldl (fn (a, (ts, seen)) => let val (t, seen) = one (a, seen) in (t :: ts, seen) end)
                                          ([], []) heads
              val missing = List.filter (fn (k, _) => not (member (k, seen))) cons
              val () = if isSome default orelse null missing then ()
                       else breach (env, "case", "the case on " ^ ty st ^ " has no alternative of " ^ #1 (hd missing))
            in List.rev ts end
        | SOME (c, {shape = NewT _, ...}, _) => breach (env, "case", "a case on " ^ c ^ ", a newtype: cast it")
        | _ =>
            case st of
              TUTuple comps =>
                (case heads of
                   [] => []
                 | [AltUTuple (xs, rhs)] =>
                     if length xs = length comps
                     then [typeOf (ListPair.foldl (fn (x, t, env) => bindVal (env, x, t)) env' (xs, comps)) rhs]
                     else breach (env, "case", "the alternative of an unboxed tuple of " ^ Int.toString (length comps)
                                              ^ " binds " ^ Int.toString (length xs))
                 | _ => breach (env, "case", "a case on an unboxed tuple has one alternative, (utuple x ...)"))
            | TCon k =>
                if member (k, ["Int", "Char", "Integer"]) then
                  let
                    val pairs = List.map (fn AltLit (l, rhs) => (l, rhs)
                                           | _ => breach (env, "case", "an alternative of a case on " ^ k ^ " is not a literal"))
                                         heads
                    val lits = List.map #1 pairs
                    val () = List.app (fn l => (litCheck (env', l);
                                                if equalTy (litTy l, st) then ()
                                                else breach (env, "case", "the literal " ^ CoreText.showLit l ^ " is not of type " ^ k)))
                                      lits
                    fun dups [] = ()
                      | dups (l :: rest) = if member (l, rest) then breach (env, "case", "two alternatives of " ^ CoreText.showLit l)
                                           else dups rest
                    val () = dups lits
                    val () = if isSome default orelse null heads then ()
                             else breach (env, "case", "a case on literals of " ^ k ^ " has no default alternative")
                  in List.map (fn (_, rhs) => typeOf env' rhs) pairs end
                else (none "which has no constructors"; [])
            | _ => (none "which has no constructors"; [])
      val types = types @ (case default of SOME rhs => [typeOf env' rhs] | NONE => [])
    in
      case types of
        [] => breach (env, "case", "a case with no alternative")
      | t :: rest =>
          (* the first's type, or, where another is lazier, its type relaxed *)
          let val r = if List.all (fn u => sub (u, t)) rest then stripEval t else relax t
          in
            List.app (fn u => if sub (u, r) then ()
                              else breach (env, "case", "an alternative of type " ^ ty u ^ " where the first is of type " ^ ty r))
                     (t :: rest);
            r
          end
    end

  (* ---- Declarations ---- *)

  fun check (program : program) =
    let
      val decls = builtinData @ program
      val start : globals =
        {tycons = List.foldl (fn ((c, k), m) =>
                                if List.exists (fn Data (d, _, _) => d = c | _ => false) builtinData then m
                                else CoreMap.insert (m, c, {kind = k, params = [], shape = Builtin}))
                             CoreMap.empty builtinTypes,
         cons = CoreMap.empty, vals = CoreMap.empty}
      fun env0 (g, where') = {g = g, where' = where', vals = #vals g, tyvars = CoreMap.empty} : env
      fun params (env, ps) =
        let
          fun go ([], env) = env
            | go ((a, k) :: rest, env) =
                if List.exists (fn (b, _) => b = a) rest then breach (env, "decl", "the parameter " ^ a ^ " twice")
                else go (rest, bindTy (env, a, k))
        in go (ps, env) end
      fun kindOf ps = List.foldr (fn ((_, k), r) => Arrow (k, r)) Star ps
      (* the names: type constructors, constructors, values *)
      fun declare (d, g : globals) =
        let
          fun dupTy t = if CoreMap.member (#tycons g, t) then breach (env0 (g, "in data " ^ t), "decl", "the type " ^ t ^ " is declared twice")
                        else ()
          fun dupCon (g : globals, t, c) =
            if CoreMap.member (#cons g, c) then breach (env0 (g, "in data " ^ t), "decl", "the constructor " ^ c ^ " is declared twice")
            else ()
        in
          case d of
            Data (t, ps, cs) =>
              let
                val () = dupTy t
                val g = {tycons = CoreMap.insert (#tycons g, t, {kind = kindOf ps, params = ps, shape = DataT cs}),
                         cons = #cons g, vals = #vals g}
              in
                List.foldl (fn ((c, fields), g : globals) =>
                              (dupCon (g, t, c);
                               {tycons = #tycons g, cons = CoreMap.insert (#cons g, c, {tycon = t, params = ps, fields = fields}),
                                vals = #vals g}))
                           g cs
              end
          | Newtype (t, ps, c, field) =>
              (dupTy t; dupCon (g, t, c);
               {tycons = CoreMap.insert (#tycons g, t, {kind = kindOf ps, params = ps, shape = NewT (c, field)}),
                cons = CoreMap.insert (#cons g, c, {tycon = t, params = ps, fields = [field]}), vals = #vals g})
          | Val (x, t, _) =>
              if CoreMap.member (#vals g, x) then breach (env0 (g, "in val " ^ x), "decl", "the value " ^ x ^ " is declared twice")
              else {tycons = #tycons g, cons = #cons g, vals = CoreMap.insert (#vals g, x, t)}
          | Import (x, t) =>
              if CoreMap.member (#vals g, x) then breach (env0 (g, "in import " ^ x), "decl", "the value " ^ x ^ " is declared twice")
              else {tycons = #tycons g, cons = #cons g, vals = CoreMap.insert (#vals g, x, t)}
        end
      val g = List.foldl declare start decls
      fun one d =
        case d of
          Data (t, ps, cs) =>
            let val env = params (env0 (g, "in data " ^ t), ps)
            in List.app (fn (c, fields) => List.app (fn f => case slot (env, "a field of " ^ c) f of
                                                                Star => ()
                                                              | k => breach (env, "kind", "a field of " ^ c ^ " is of kind " ^ showK k))
                                                    fields) cs
            end
        | Newtype (t, ps, c, field) =>
            let val env = params (env0 (g, "in newtype " ^ t), ps)
            in
              case field of
                TEval _ => breach (env, "decl", "the field of the newtype's " ^ c ^ " is !")
              | _ => case inner (env, "the field of " ^ c) field of
                       Star => ()
                     | k => breach (env, "kind", "the field of " ^ c ^ " is of kind " ^ showK k)
            end
        | Import (x, t) =>
            (* a value of another unit: its type as a value's of the top
               level is, its definition the unit's that exports it *)
            let val env = env0 (g, "in import " ^ x)
            in lifted (env, "the type of " ^ x, "val") t end
        | Val (x, t, e) =>
            let
              val env = env0 (g, "in val " ^ x)
              val () = lifted (env, "the type of " ^ x, "val") t
              val r = typeOf env e
              val () = if sub (r, t) then ()
                       else breach (env, "val", x ^ " is declared of type " ^ ty t ^ ", and its expression is of type " ^ ty r)
              val () =
                if x <> "main" then ()
                else case t of
                       TFun (TCon "World", TUTuple [TCon "World", _]) => ()
                     | _ => breach (env, "main", "main is of type " ^ ty t ^ ", where World -> (utuple World T) is wanted")
            in () end
    in List.app one decls end
end
