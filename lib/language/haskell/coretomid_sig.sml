(* Core to Mid (the haskell98 roadmap, M10): a Core program as a program
   of Mid's text, which rhc reads with Mid's own reader and gives to the
   passes from Mid on (MidPipeline), its list without expand.

   A lazy position of type T is `T susp` in Mid and an evaluated one `T`:
   a binder, a parameter, a field and a component of an unboxed tuple of
   type `!T` is the value, one of a lifted `T` a suspension. A function
   takes each argument in its slot and returns its value evaluated, so a
   datatype-typed variable of Mid is evaluated. A `let` of a value -- a
   lambda, a constructor, a literal -- binds the value, and of anything else
   a suspension, whose code says it is under evaluation first and updates
   it with its value last. A `case` forces its scrutinee and tests its tag;
   a value given to a lazy slot is cast into it. A `letrec` of values goes
   through cells (D6's A), and a value of the top level that is no function
   is a suspension in a global, a CAF. The state token is erased (D25): an
   action of Core, `World -> (utuple World T)`, is `unit -> T` in Mid, its
   order the order of its lets.

   An `Integer` is Mid's `IntInf.int`, an immediate within 63 bits and a
   sign and a magnitude past them (M31, D20's D), each literal a global made
   once. A type variable applied and a forall inside a type are Mid's own
   (M28): a lazy field of a forall holds a suspension at every type, the
   forall outside it, and a newtype given fewer arguments than its
   parameters is a box, as one that reaches itself is.

   Area: Languages *)
signature CORE_TO_MID =
sig
  (* A fault made on purpose, for the tests of what catches it.

     They are the roadmap's rhc's mutants of Core to Mid: `ThunkInSlot`, a
     suspension used where its value is wanted, unforced; `ForceBehindCast`,
     a force made a cast from the suspension to its value. *)
  datatype fault = ThunkInSlot | ForceBehindCast

  (* A construct Core has and Core to Mid does not lower: what it is, and
     where. *)
  exception Unsupported of string

  (* `program ({fault}, p)` is the text of Mid of the Core program `p`,
     which CoreLint passed, with the fault made where it is `SOME`.

     A suspension is form C's (the roadmap's M9): made by `thunk_make`,
     forced by one `thunk_force` node, its code saying `thunk_blackhole`
     first and `thunk_self_update` last.

     The text's `do` calls `main`, and prints what an exception no handler
     takes is, as Core's interpreter does, an IOError's text as the
     library's Show IOError gives it, and ends with status 1.

     Raises: `Unsupported` where `p` needs what Mid has not got. *)
  val program : {fault : fault option} * Core.program -> string
end
