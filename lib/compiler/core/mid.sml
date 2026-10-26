(* Mid, the intermediate representation the optimisations will work on
   (docs/ir.md; docs/plans/middle-end.md, D1 and M3): made from Lambda by
   ToMid, checked by MidLint, printed and read back by MidText.

   * A-normal form: every operand of a call, a primitive or a constructor is
     an atom, a variable or a constant, and the datatype says so.
   * Join points: `Join (j, params, body, scope)` binds a label that `scope`
     jumps to, in tail position only, and that no function captures. A Try
     of Lambda is one without parameters; the rest of an expression that
     branches, one with.
   * Functions take a list of parameters; the calling convention (M8) makes
     them n-ary, and until then each takes one.
   * The top level is a list of definitions, not one term nested once per
     declaration.
   * `Handle` is a region: its body and its handler are expressions in tail
     position of it, and a jump out of its body leaves it. A call in tail
     position of a Handle's body is no tail call.
   * Explicitly typed, in the manner of System F: every binder says its type,
     a polymorphic one the variables it abstracts over, and every use of it
     the types it is used at. Variables are stamps, unique in the program. *)
structure Mid =
struct
  type var = int
  type label = int

  (* The variables a binder abstracts over (Ty.Gen ids), and its type. *)
  type scheme = int list * Ty.ty

  (* Where code came from: its place in the source, and the functions it was
     inlined from on the way (M10, decision D7), innermost first -- each the
     function's name and the place it was called from in the next, or in
     the function the code is in, for the last; or no place, where it was
     called in tail position, so that it took the place of the next (its
     frame in a trace, as a tail call's does). *)
  type frame = {name : string, site : Source.span option}
  type pos = Source.span * frame list

  datatype atom =
      Var of var * Ty.ty list             (* a local variable, at these types for its variables *)
    | Global of var * Ty.ty list
    | Const of Lambda.const * Ty.ty
    | Con0 of int * Ty.ty                 (* a nullary constructor, by its tag, and its datatype *)
    | Unit

  (* One step, on atoms. *)
  datatype rhs =
      Atom of atom
    | App of atom * atom list
    | Prim of string * Ty.ty * atom list  (* the primitive's type at this use *)
    | Tuple of atom list
    | Select of int * atom
    | Con of int * Ty.ty * atom           (* tag, the datatype made, the argument *)
    | Decon of int * Ty.ty * atom         (* the argument of a value of the datatype the constructor with
                                             the tag made *)
    | ConTag of atom
    | NewExn of string
    | BuiltinExn of int
    | MkExn of atom * atom                (* constructor, payload *)
    | ExnCon of atom
    | ExnArg of Ty.ty * atom              (* the payload, of the type its constructor gives it *)
    | SetGlobal of var * atom             (* unit *)

  datatype exp =
      Let of var * scheme * rhs * exp
    | Fun of fundef list * exp            (* functions, which may call each other *)
    | Join of label * (var * Ty.ty) list * exp * exp  (* label, parameters, body, scope *)
    | Jump of label * atom list
    | If of atom * exp * exp
    | Handle of exp * var * exp           (* body, the variable bound to the exception, handler *)
    | Raise of atom
    | Return of rhs                       (* the value of the expression *)
    | Mark of pos * exp                   (* where in the source what follows came from *)
  withtype fundef = {name : var, tyvars : int list, params : (var * Ty.ty) list, result : Ty.ty, body : exp}

  datatype def =
      Val of var * scheme * exp           (* a global, the value of the expression *)
    | Funs of fundef list                 (* global functions *)
    | Do of (var * scheme) list * exp     (* for its effect, and the globals it sets (SetGlobal) *)

  type program = def list

  (* The type of a function. *)
  fun funTy ({params, result, ...} : fundef) : Ty.ty =
    case params of
      [(_, t)] => Ty.arrow (t, result)
    | _ => Ty.arrow (Ty.tuple (List.map #2 params), result)

  (* The definition with every type it writes made what f makes of it,
     given the type variables in scope there (Mid is System F: a Let's
     scheme binds its own over its type and step, a function's over its
     parameters, result and body, a global's over its definition); and
     whether f changed any, so that one it changes none of is the same
     definition. *)
  fun mapTypesIn (f : unit IntMap.map * Ty.ty -> Ty.ty) (d : def) : def * bool =
    let
      val changed = ref false
      fun ty (s, t) = let val t' = f (s, t) in if Ty.equal (t, t') then t else (changed := true; t') end
      fun bind (s, tvs) = List.foldl (fn (a, s) => IntMap.insert (s, a, ())) s tvs
      fun atom s a =
        case a of
          Var (x, ts) => Var (x, List.map (fn t => ty (s, t)) ts)
        | Global (g, ts) => Global (g, List.map (fn t => ty (s, t)) ts)
        | Const (c, t) => Const (c, ty (s, t))
        | Con0 (tag, t) => Con0 (tag, ty (s, t))
        | Unit => Unit
      fun rhs s r =
        case r of
          Atom a => Atom (atom s a)
        | App (g, xs) => App (atom s g, List.map (atom s) xs)
        | Prim (p, t, xs) => Prim (p, ty (s, t), List.map (atom s) xs)
        | Tuple xs => Tuple (List.map (atom s) xs)
        | Select (i, a) => Select (i, atom s a)
        | Con (tag, t, a) => Con (tag, ty (s, t), atom s a)
        | Decon (tag, t, a) => Decon (tag, ty (s, t), atom s a)
        | ConTag a => ConTag (atom s a)
        | MkExn (c, a) => MkExn (atom s c, atom s a)
        | ExnCon a => ExnCon (atom s a)
        | ExnArg (t, a) => ExnArg (ty (s, t), atom s a)
        | SetGlobal (g, a) => SetGlobal (g, atom s a)
        | NewExn _ => r
        | BuiltinExn _ => r
      fun exp s e =
        case e of
          Let (x, (tvs, t), r, b) => let val s' = bind (s, tvs) in Let (x, (tvs, ty (s', t)), rhs s' r, exp s b) end
        | Fun (fs, b) => Fun (List.map (fundef s) fs, exp s b)
        | Join (j, ps, body, sc) => Join (j, List.map (fn (x, t) => (x, ty (s, t))) ps, exp s body, exp s sc)
        | Jump (j, xs) => Jump (j, List.map (atom s) xs)
        | If (c, t, e') => If (atom s c, exp s t, exp s e')
        | Handle (a, x, h) => Handle (exp s a, x, exp s h)
        | Raise a => Raise (atom s a)
        | Return r => Return (rhs s r)
        | Mark (pos, a) => Mark (pos, exp s a)
      and fundef s ({name, tyvars, params, result, body} : fundef) : fundef =
        let val s = bind (s, tyvars)
        in {name = name, tyvars = tyvars, params = List.map (fn (x, t) => (x, ty (s, t))) params, result = ty (s, result),
            body = exp s body}
        end
      val d' =
        case d of
          Val (g, (tvs, t), e) => let val s = bind (IntMap.empty, tvs) in Val (g, (tvs, ty (s, t)), exp s e) end
        | Funs fs => Funs (List.map (fundef IntMap.empty) fs)
        | Do (gs, e) =>
            let val s = List.foldl (fn ((_, (tvs, _)), s) => bind (s, tvs)) IntMap.empty gs
            in Do (List.map (fn (g, (tvs, t)) => (g, (tvs, ty (s, t)))) gs, exp s e) end
    in
      if !changed then (d', true) else (d, false)
    end

  (* Whether some type a definition writes is one p holds of, given the
     type variables in scope there, as mapTypesIn gives them. *)
  fun existsTypeIn (p : unit IntMap.map * Ty.ty -> bool) (d : def) : bool =
    let
      exception Found
      fun ty (s, t) = if p (s, t) then raise Found else ()
      fun bind (s, tvs) = List.foldl (fn (a, s) => IntMap.insert (s, a, ())) s tvs
      fun atom s a =
        case a of
          Var (_, ts) => List.app (fn t => ty (s, t)) ts
        | Global (_, ts) => List.app (fn t => ty (s, t)) ts
        | Const (_, t) => ty (s, t)
        | Con0 (_, t) => ty (s, t)
        | Unit => ()
      fun rhs s r =
        case r of
          Atom a => atom s a
        | App (g, xs) => (atom s g; List.app (atom s) xs)
        | Prim (_, t, xs) => (ty (s, t); List.app (atom s) xs)
        | Tuple xs => List.app (atom s) xs
        | Select (_, a) => atom s a
        | Con (_, t, a) => (ty (s, t); atom s a)
        | Decon (_, t, a) => (ty (s, t); atom s a)
        | ConTag a => atom s a
        | MkExn (c, a) => (atom s c; atom s a)
        | ExnCon a => atom s a
        | ExnArg (t, a) => (ty (s, t); atom s a)
        | SetGlobal (_, a) => atom s a
        | _ => ()
      fun exp s e =
        case e of
          Let (_, (tvs, t), r, b) => (let val s' = bind (s, tvs) in ty (s', t); rhs s' r end; exp s b)
        | Fun (fs, b) => (List.app (fundef s) fs; exp s b)
        | Join (_, ps, body, sc) => (List.app (fn (_, t) => ty (s, t)) ps; exp s body; exp s sc)
        | Jump (_, xs) => List.app (atom s) xs
        | If (c, t, e') => (atom s c; exp s t; exp s e')
        | Handle (a, _, h) => (exp s a; exp s h)
        | Raise a => atom s a
        | Return r => rhs s r
        | Mark (_, a) => exp s a
      and fundef s ({tyvars, params, result, body, ...} : fundef) =
        let val s = bind (s, tyvars)
        in List.app (fn (_, t) => ty (s, t)) params; ty (s, result); exp s body end
    in
      (case d of
         Val (_, (tvs, t), e) => let val s = bind (IntMap.empty, tvs) in ty (s, t); exp s e end
       | Funs fs => List.app (fundef IntMap.empty) fs
       | Do (gs, e) =>
           let val s = List.foldl (fn ((_, (tvs, _)), s) => bind (s, tvs)) IntMap.empty gs
           in List.app (fn (_, (_, t)) => ty (s, t)) gs; exp s e end;
       false)
      handle Found => true
    end

  (* The nodes of a program, for --pass-stats. *)
  fun size (p : program) : int =
    let
      fun exp e =
        case e of
          Let (_, _, _, b) => 1 + exp b
        | Fun (fs, b) => List.foldl (fn (f, n) => n + exp (#body f)) (1 + exp b) fs
        | Join (_, _, b, s) => 1 + exp b + exp s
        | If (_, t, f) => 1 + exp t + exp f
        | Handle (a, _, h) => 1 + exp a + exp h
        | Mark (_, a) => exp a
        | _ => 1
      fun def d =
        case d of
          Val (_, _, e) => exp e
        | Funs fs => List.foldl (fn (f, n) => n + exp (#body f)) 0 fs
        | Do (_, e) => exp e
    in List.foldl (fn (d, n) => n + def d) 0 p end
end
