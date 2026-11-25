(* The Core simplifier (the haskell98 roadmap's M23; D47, D48, D49): rhc's
   optimiser, on Core, at -O2; Mid's passes run below it unchanged (D47).

   Its passes, in order, each a function of a program to a program whose
   every rewrite keeps the program well typed (CoreLint) and keeps what is
   shared and what is bottom:

   - `simplify`: inlining of small functions and of bindings used once,
     beta, a case of a known constructor or literal, a case of a case,
     floating of lets, the folding of primitives and of `fromInteger` and
     `fromRational` of literals at the Prelude's instances (Augustsson 1993,
     §4.3), and with the whole program the values main does not reach
     dropped (CoreSimplifySimp);
   - `specialise`: each overloaded function applied to closed types and
     constant dictionaries copied at them, local overloaded bindings too,
     under fuel, with `simplify` after (D49's C; CoreSimplifySpec);
   - `eta`: lambdas added where an expression takes more arguments at no
     cost, under the pedantic rule (D48's C) or GHC's default (D48's D, to
     be measured; CoreSimplifyEta);
   - `cheap`: a let of a cheap and total expression made a case, its value
     made at once and no suspension built (D51's C; CoreSimplifyCheap).

   What it refuses of GHC's: foldr/build, which `seq` makes unsound (Hudak
   et al. 2007, §10.3); general full laziness, which changes strictness
   (Pałka 2012); eta through a case, and through `IO`, the state hack,
   but as D's option. A thunk is never copied where it may run twice: a
   binding is inlined into a lambda only where it is a value.

   Area: Languages *)
signature CORE_SIMPLIFY =
sig
  (* How eta-expansion is done: by the pedantic rule (D48's C), or as GHC
     does by default, through a case and through `IO` (D48's D, built to be
     measured). *)
  datatype eta = Pedantic | Ghc

  (* What the passes are given: what is asked before each rewrite, whether
     the program is whole, the eta rule, and whether cheap eagerness runs.

     `spend` is asked before each rewrite (Pass.spend, so that --fuel stops
     them); with `whole` a value main does not reach may go. `cheap` is
     rhc's default, which --no-cheap-eagerness turns off. `library` is the
     names of the program's library, whose Prelude's and Ratio's entities
     the simplifier knows. *)
  type options = {spend : unit -> bool, whole : bool, eta : eta, cheap : bool, library : HsLibraryNames.t}

  (* `passes ()` is each pass, by its name for --dump-after, in the order
     they run: core-simplify, core-specialise, core-eta, core-strict,
     core-cheap, core-simplify-2. *)
  val passes : unit -> (string * (options -> Core.program -> Core.program)) list

  (* `simplify opts p` is p simplified, its rounds run until one makes no
     rewrite or so many have run. *)
  val simplify : options -> Core.program -> Core.program

  (* `specialise opts p` is p with its overloaded functions specialised at
     the constant dictionaries they are given, each round simplified. *)
  val specialise : options -> Core.program -> Core.program

  (* `eta opts p` is p eta-expanded by the rule of `opts`, then
     simplified. *)
  val eta : options -> Core.program -> Core.program

  (* `counts ()` is each kind of rewrite made since `resetCounts`, with how
     many, in the order they were first made.

     `eta-refused` (or `eta-ghc-candidate`) counts what GHC's default would
     expand and the pedantic rule does not. *)
  val counts : unit -> (string * int) list

  (* `resetCounts ()` forgets the counts. *)
  val resetCounts : unit -> unit

  (* `unfoldings p` is the values of p a client of p's unit may inline or
     specialise, as Core declarations.

     They are its small functions, its dictionaries and its overloaded
     functions, each `(val x TYPE EXP)` of p, in p's order: HsIface's section
     of unfoldings (D44, M21), whose text is CoreText's. *)
  val unfoldings : Core.program -> Core.decl list
end
