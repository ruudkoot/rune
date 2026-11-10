(* Mid, the intermediate representation the optimisations will work on
   (docs/ir.md; docs/plans/middle-end.md, D1 and M3): made from Lambda by
   ToMid, checked by MidLint, printed and read back by MidText.

   * A-normal form: every operand of a call, a primitive or a constructor is
     an atom, a variable or a constant, and the datatype says so.
   * Join points: `Join (j, params, body, scope)` binds a label that `scope`
     jumps to, in tail position only, and that no function captures. The
     rest of a match where a rule fails is one without parameters; the rest
     of an expression that branches, one with.
   * Functions take a list of parameters; the calling convention (M8) makes
     them n-ary, and until then each takes one.
   * The top level is a list of definitions, not one term nested once per
     declaration.
   * `Handle` is a region: its body and its handler are expressions in tail
     position of it, and a jump out of its body leaves it. A call in tail
     position of a Handle's body is no tail call.
   * Explicitly typed, in the manner of System F: every binder says its type,
     a polymorphic one the variables it abstracts over, and every use of it
     the types it is used at. Variables are stamps, unique in the program.
   * A function may have a label: the name a person knows it by, which the
     bytecode's function table, a disassembly and a trace show. Every copy of
     a function a pass makes keeps it; a function without one is `fn`. *)
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
    | Const of Literal.const * Ty.ty
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
  withtype fundef = {name : var, label : string option, tyvars : int list, params : (var * Ty.ty) list, result : Ty.ty,
                     body : exp}

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

  (* ---- the parts of a step and of an expression ---- *)

  (* What follows names every form of a step and of an expression, with no
     catch-all, and a walker whose arms would only do what one of these
     does asks it instead (docs/ir.md, Walking Mid): so a form added to
     rhs or exp is a match that is not exhaustive here and in the walkers
     that say more of it, not one that a catch-all takes for a step with no
     atoms, or for an expression with nothing under it. *)

  (* The atoms a step names, in the order it names them. *)
  fun atomsOfRhs (r : rhs) : atom list =
    case r of
      Atom a => [a]
    | App (f, xs) => f :: xs
    | Prim (_, _, xs) => xs
    | Tuple xs => xs
    | Select (_, a) => [a]
    | Con (_, _, a) => [a]
    | Decon (_, _, a) => [a]
    | ConTag a => [a]
    | NewExn _ => []
    | BuiltinExn _ => []
    | MkExn (c, a) => [c, a]
    | ExnCon a => [a]
    | ExnArg (_, a) => [a]
    | SetGlobal (_, a) => [a]

  (* The types a step says, but for those of its atoms: none, or the one it
     names before its atoms. *)
  fun typesOfRhs (r : rhs) : Ty.ty list =
    case r of
      Atom _ => []
    | App _ => []
    | Prim (_, t, _) => [t]
    | Tuple _ => []
    | Select _ => []
    | Con (_, t, _) => [t]
    | Decon (_, t, _) => [t]
    | ConTag _ => []
    | NewExn _ => []
    | BuiltinExn _ => []
    | MkExn _ => []
    | ExnCon _ => []
    | ExnArg (t, _) => [t]
    | SetGlobal _ => []

  (* The step with each of its parts what the members make of it, in the
     order the step names them, so each type before the atom after it: the
     types it says (ty), its atoms (atom), and the global a SetGlobal sets
     (global). *)
  fun mapRhsWith ({ty, atom, global} : {ty : Ty.ty -> Ty.ty, atom : atom -> atom, global : var -> var})
                 (r : rhs) : rhs =
    case r of
      Atom a => Atom (atom a)
    | App (f, xs) => App (atom f, List.map atom xs)
    | Prim (p, t, xs) => Prim (p, ty t, List.map atom xs)
    | Tuple xs => Tuple (List.map atom xs)
    | Select (i, a) => Select (i, atom a)
    | Con (tag, t, a) => Con (tag, ty t, atom a)
    | Decon (tag, t, a) => Decon (tag, ty t, atom a)
    | ConTag a => ConTag (atom a)
    | NewExn _ => r
    | BuiltinExn _ => r
    | MkExn (c, a) => MkExn (atom c, atom a)
    | ExnCon a => ExnCon (atom a)
    | ExnArg (t, a) => ExnArg (ty t, atom a)
    | SetGlobal (g, a) => SetGlobal (global g, atom a)

  (* The step with each atom what f makes of it, in the order it names
     them, and its types and globals as they are. *)
  fun mapRhs (f : atom -> atom) (r : rhs) : rhs = mapRhsWith {ty = fn t => t, atom = f, global = fn g => g} r

  (* What fold gives its members of each part of an expression, with what
     the parts before it have made. *)
  type 'a folder =
    {rhs : rhs * 'a -> 'a,          (* a step: a Let's, or a Return's *)
     atom : atom * 'a -> 'a,        (* an atom outside a step: an If's test, a Jump's argument, a Raise's exception *)
     jump : label * 'a -> 'a,       (* a jump, by its label, after its arguments *)
     fundef : fundef * 'a -> 'a}    (* a function made in the expression: its body is the member's to walk, or not *)

  (* The parts of e given to f's members in the order e names them, from z,
     each given what the one before made: the expressions in e are walked
     in turn -- a Let's body after its step, a join point's body before
     its scope, an If's branches after its test, a Handle's body before its
     handler -- but for the bodies of the functions made in e, which are
     the member fundef's. *)
  fun fold (f : 'a folder) (z : 'a) (e : exp) : 'a =
    let
      fun go (e, acc) =
        case e of
          Let (_, _, r, b) => go (b, #rhs f (r, acc))
        | Fun (fs, b) => go (b, List.foldl (#fundef f) acc fs)
        | Join (_, _, body, sc) => go (sc, go (body, acc))
        | Jump (j, xs) => #jump f (j, List.foldl (#atom f) acc xs)
        | If (a, t, e') => go (e', go (t, #atom f (a, acc)))
        | Handle (a, _, h) => go (h, go (a, acc))
        | Raise a => #atom f (a, acc)
        | Return r => #rhs f (r, acc)
        | Mark (_, a) => go (a, acc)
    in go (e, z) end

  (* Each step of e given to f, in the order e names them, those of the
     functions made in e among them, each at its place. *)
  fun appRhs (f : rhs -> unit) (e : exp) : unit =
    fold {rhs = fn (r, ()) => f r, atom = fn (_, ()) => (), jump = fn (_, ()) => (),
          fundef = fn (g : fundef, ()) => appRhs f (#body g)} () e

  (* Whether p holds of some step of e, a function's made in e among them:
     the steps are asked in the order appRhs gives them, and none after the
     first p holds of. *)
  fun existsRhs (p : rhs -> bool) (e : exp) : bool =
    let exception Found
    in (appRhs (fn r => if p r then raise Found else ()) e; false) handle Found => true end

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
      fun rhs s r = mapRhsWith {ty = fn t => ty (s, t), atom = atom s, global = fn g => g} r
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
      and fundef s ({name, label, tyvars, params, result, body} : fundef) : fundef =
        let val s = bind (s, tyvars)
        in {name = name, label = label, tyvars = tyvars, params = List.map (fn (x, t) => (x, ty (s, t))) params,
            result = ty (s, result), body = exp s body}
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
        | NewExn _ => ()
        | BuiltinExn _ => ()
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

  (* The nodes of an expression, those of the functions made in it among
     them; a position is none. *)
  fun sizeOfExp (e : exp) : int =
    case e of
      Let (_, _, _, b) => 1 + sizeOfExp b
    | Fun (fs, b) => List.foldl (fn (f, n) => n + sizeOfExp (#body f)) (1 + sizeOfExp b) fs
    | Join (_, _, b, s) => 1 + sizeOfExp b + sizeOfExp s
    | Jump _ => 1
    | If (_, t, f) => 1 + sizeOfExp t + sizeOfExp f
    | Handle (a, _, h) => 1 + sizeOfExp a + sizeOfExp h
    | Raise _ => 1
    | Return _ => 1
    | Mark (_, a) => sizeOfExp a

  (* The nodes of a program, for --pass-stats. *)
  fun size (p : program) : int =
    let
      fun def d =
        case d of
          Val (_, _, e) => sizeOfExp e
        | Funs fs => List.foldl (fn (f, n) => n + sizeOfExp (#body f)) 0 fs
        | Do (_, e) => sizeOfExp e
    in List.foldl (fn (d, n) => n + def d) 0 p end
end
