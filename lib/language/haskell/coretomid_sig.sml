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

   What a later milestone gives is behind one function each: a type
   constructor applied by a variable and a forall inside a type (M28, Mid's
   `Ty` with application and forall), and `Integer` (M31).

   Area: Languages *)
signature CORE_TO_MID =
sig
  (* How suspensions are made and forced: by form C's primitives, or by
     functions of E1's runtime in today's Mid.

     `FormC` is the roadmap's M9: `thunk_make`, `thunk_force`,
     `thunk_blackhole` and `thunk_self_update`, force one primitive node.
     `Runtime` is for a tree that has not got them. *)
  datatype form = FormC | Runtime

  (* A fault made on purpose, for the tests of what catches it.

     They are the roadmap's rhc's mutants of Core to Mid: `ThunkInSlot`, a
     suspension used where its value is wanted, unforced; `ForceBehindCast`,
     a force made a cast from the suspension to its value. *)
  datatype fault = ThunkInSlot | ForceBehindCast

  (* A construct Core has and the Mid of this tree cannot say yet: what it
     waits on, and where. *)
  exception Unsupported of string

  (* `program ({form, fault}, p)` is the text of Mid of the Core program
     `p`, which CoreLint passed, with the fault made where it is `SOME`.

     The text's `do` calls `main`, and prints what an exception no handler
     takes is, as Core's interpreter does, and ends with status 1.

     Raises: `Unsupported` where `p` needs what Mid has not got. *)
  val program : {form : form, fault : fault option} * Core.program -> string
end
