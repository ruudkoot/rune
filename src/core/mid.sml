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
    | Decon of int * atom                 (* the argument of a value the constructor with the tag made *)
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
      [(_, t)] => Ty.Arrow (t, result)
    | _ => Ty.Arrow (Ty.Tuple (List.map #2 params), result)

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
