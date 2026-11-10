(* Haskell 98's type checker (the haskell98 roadmap's M13, D30, D31, D32,
   D33): one inference over the renamed, fixity-resolved trees of a unit,
   the modules of one strongly connected group, joined, so that a binding
   group or a type group may cross its modules, with what it chose
   recorded by node in HsEvidence's table.

   Types by first-order unification with levels; kinds by HsKinds;
   classes, instances and the derived instances' contexts, by the fixpoint
   10.1 allows, in HsClasses; each overloaded use leaves a placeholder,
   resolved at generalisation as a dictionary parameter, an instance's
   dictionary, a superclass's, deferred outward, or defaulted. Declaration
   groups by dependency, explicitly typed bindings apart (Typing Haskell in
   Haskell's split, R21(c)), one context for each implicit group (R21(a)),
   the contexts of a group's signatures identical up to renaming (R21(b)),
   a signature on a pattern binding that is not simple refused (R19), and
   the monomorphism restriction by 4.5.5's simple pattern binding (R18).
   A restricted group's constrained variables stay open, and at the top
   level are defaulted at the end of the module (R20), by the `default` of
   the module their constraints arose in, refused where two modules'
   differ, and refused where another module of the cycle fixes one (D30);
   under `--cycle-default=scc`, by the group's one `default`, and closed at
   the end of the group (an extension). Defaulting by 4.3.4's conditions
   (R22).

   Area: Languages *)
signature HS_INFER =
sig
  (* What the checker knows of the program before a unit: the types of
     its values, its type constructors, classes and instances. *)
  type env

  (* `initial {primitives}` is the environment with the built-in types and
     constructors alone, and the values `primitives`.

     Each primitive has the type `forall a. a`, until the overlay types
     them (M17). *)
  val initial : {primitives : string list} -> env

  (* Where Rule 2 closes and which `default` holds in a cycle (D30). *)
  datatype cycleDefault = PerModule | PerGroup

  (* A module of a unit: its identity, its renamed and resolved tree, and
     whether it is the library's. *)
  type module_ = {id : string, ast : HsAst.module, library : bool}

  (* `check {env, unit, cycleDefault, prelude, evidence}` checks the
     modules of `unit`, recording into `evidence`.

     It gives the environment with the unit's types, constructors,
     classes, instances and values, and the errors. `prelude (space,
     name)` is the key of
     the entity the Prelude exports under `name`, `"t"` for a type or
     class and `"v"` for a value, for what the Report's translations
     name: `Bool`, `Char`, `Integer`, `Double`, `Num`, `Fractional`,
     `Eq`, `Ord`, `Enum`, `Integral`, `Monad`. *)
  val check : {env : env, unit : module_ list, cycleDefault : cycleDefault,
               prelude : string * string -> string option, evidence : HsEvidence.table}
              -> {env : env, errors : (HsSource.span * string) list}

  (* `valueScheme (env, key)` is the type of the value of `key`. *)
  val valueScheme : env * string -> HsTypes.scheme option

  (* `classes env` is the classes and instances of `env`. *)
  val classes : env -> HsClasses.env
end
