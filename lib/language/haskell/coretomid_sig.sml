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
     a force made a cast from the suspension to its value; `SuspTypeArg`, a
     use's first type argument a slot's type, a suspension's. *)
  datatype fault = ThunkInSlot | ForceBehindCast | SuspTypeArg

  (* Whether Core to Mid holds what it writes to its own rules, which rhc
     sets at lint level 2 (M10b).

     A use's type argument is a value's type, never one with `susp` at its
     head (D4); the rule is Core to Mid's and not MidLint's, since SML uses
     its polymorphic functions at `T susp`. *)
  val checking : bool ref

  (* A breach of Core to Mid's rules, where `checking` holds: what it is. *)
  exception Breach of string

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

  (* How a value of the top level is in Mid, an ABI fact of its interface.

     A unit that imports it binds it so (H9): a function global, a
     suspension in a global (a CAF), or a literal in a global. *)
  datatype abi = Function | Suspension | Literal

  (* `unit ({fault, imports, makesShared}, p)` is the text of Mid of the
     unit `p` (the haskell98 roadmap's M21).

     Each import of another unit is bound as `imports` says that unit's
     Core to Mid made it, and each newtype of another unit is a box where
     `newtypes` says that unit made it one (an ABI fact, H9); its `boxed`
     says so of each newtype the unit declares itself. Its `names` is the name in the text of each value of the top level,
     the unit's own and its imports, by its Core name; its `abi` how each
     of its own is made. An import is declared in the text as a global of
     its scheme whose expression is a placeholder, which the client drops
     after reading the text, its scheme MidLint's for the import
     (MidLint.importedScheme). The text calls `main` where the unit
     defines it, as `program`'s does.

     Raises: `Unsupported` where `p` needs what Mid has not got, or an
     import `imports` does not give. *)
  val unit : {fault : fault option, imports : (string * abi) list, makesShared : bool, newtypes : (string * bool) list}
             * Core.program
             -> {text : string, names : (string * string) list, abi : (string * abi) list, boxed : (string * bool) list}

  (* `shared` is the globals of every text's prelude that have an
     identity, Core's exceptions, which one unit of a program makes.

     Each is in `unit`'s `names` by itself, and
     in its `abi` where the unit makes them (makesShared), which one unit
     of a program does; in the others' texts they are imports, which their
     client reads as it reads an import's placeholder. *)
  val shared : string list
end
