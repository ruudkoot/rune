(* Strictness (the haskell98 roadmap's M24, D50's C): one backward analysis
   with signatures, and its result in Core's types.

   A function's signature says, for each of its value parameters, whether
   a call with all of them evaluates it, and whether such a call diverges.
   It is found backwards from the body: a variable is strict in an
   expression where evaluating the expression to its head evaluates the
   variable, along every way it may go; a function the analysis knows is
   given its arguments' demands by its signature; a `case` evaluates its
   scrutinee and then one alternative; and a recursive group starts from
   the most strict signatures and is weakened until it holds (Peyton Jones
   et al. 2006, head strictness alone, no absence). It does not look inside
   a data type.

   A precise exception (D50, D25): an I/O action may end the program, or
   raise what `catch` sees, so what the source evaluates after an action is
   not evaluated before it. A `case` that takes an action's result apart
   (its alternative an unboxed tuple, or its scrutinee a primitive whose
   result holds the state token) makes nothing strict, and nothing
   divergent, of what its alternatives do: GHC's rule, Note [Precise
   exceptions and strictness analysis] (`GHC/Types/Demand.hs`).

   The result goes into Core's types by a worker and a wrapper: a function
   of the top level strict in a parameter of a lifted type that is no
   newtype's becomes a worker, `%w:f`, whose parameter is `!T`, and a
   wrapper `f`, of `f`'s type, which evaluates the parameter and calls the
   worker. The simplifier inlines the wrapper where `f` is applied, so the
   caller evaluates the argument and passes its value: Core to Mid lowers
   the parameter to `T` and not to `susp T` (D3), and Mid's `workers`
   takes it from there; nothing changes in Rune (D50).

   Area: Languages *)
signature CORE_STRICT =
sig
  (* A function's signature: for each value parameter, whether it is
     strict, and whether a call of all of them diverges. *)
  type strictness = {params : bool list, bottom : bool}

  (* `signatures p` is the signature of each function of the top level of
     `p`, by its name. *)
  val signatures : Core.program -> strictness CoreMap.map

  (* `program (spend, p)` is `p` with each function of the top level strict
     in a parameter a worker and a wrapper; `spend ()` is asked before each
     (the simplifier's fuel). *)
  val program : (unit -> bool) * Core.program -> Core.program

  (* `show s` is a signature as text, `S` or `L` for each parameter and
     `b` after them where a call diverges. *)
  val show : strictness -> string

  (* `read text` is the signature `show` wrote as `text`, or NONE where
     `text` is none of its. *)
  val read : string -> strictness option

  (* `enabled` is whether `program` makes workers and wrappers: false for
     `--strictness=off`, the measurement's A. *)
  val enabled : bool ref
end
