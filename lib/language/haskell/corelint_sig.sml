(* CoreLint (the haskell98 roadmap, D2, D54): the check of a Core program.
   Core is explicitly typed, so the check is syntax-directed and unifies
   nothing: it works out the type of every expression from its parts and
   holds each to what its place wants. rhc runs it on Core read as text,
   at each boundary, and last before the crossing into Mid, where `Any`
   leaves MidLint weaker; a forgotten force, a lazy atom where `!T` is
   wanted, is the breach it is for above all.

   Each rule has a name, which its breach's message starts with in
   brackets: `[force] in val main: ...`.

   Area: Languages *)
signature CORE_LINT =
sig
  (* A breach of a rule: its message, `[RULE] in val NAME: what is wrong`. *)
  exception Error of string

  (* `rules` is each rule's name and what it holds, in the order they are
     documented:

     - `decl`, a name declared once, a newtype's field without `!`;
     - `scope`, every variable bound;
     - `tyscope`, every type variable bound, none with the name of a type
       constructor, and none that a lambda binds bound already;
     - `tycon`, every type constructor declared or built in;
     - `kind`, every type of the kind its place wants;
     - `eval`, `!` only at a binder, a parameter, a field or a component of
       an unboxed tuple, of a lifted type;
     - `instantiate`, a type argument a lifted type without `!`, of its
       variable's kind;
     - `app`, a function applied to types and values its type takes;
     - `force`, an atom given where an evaluated value is wanted evaluated;
     - `lit`, a literal in its type's range;
     - `lambda`, a lambda that binds something, each name once;
     - `let`, a `let` of a lifted type, bound to an expression of it;
     - `case`, alternatives of the scrutinee's type, that cover it and agree;
     - `con`, a constructor of a data type, given its types and fields;
     - `prim`, a primitive of CorePrim, saturated;
     - `cast`, a cast into or out of a newtype at its head;
     - `val`, a value of the top level of its type;
     - `main`, `main` of type `World -> (utuple World T)`. *)
  val rules : (string * string) list

  (* `check program` is `()` where `program` keeps every rule.

     Raises: `Error` at the first breach. *)
  val check : Core.program -> unit
end
