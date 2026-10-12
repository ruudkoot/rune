(* Tests as values (docs/plans/unit-testing.md, D2): a tree of named tests
   that can be listed, filtered and asked what it needs before any of it
   runs.

   A leaf is a test and a group names a subtree. The path of a test is the
   names from the root down to it joined by `/`, as `lib/basis/word64`, and
   is how filters, exclusions and resumption name it. The tree is
   polymorphic in its leaves: the tests that run in this process have
   functions as leaves, and a runner can put descriptions of jobs there and
   keep the listing, the filters and the metadata.

   Area: Unit testing *)
signature TEST =
sig
  (* A tree of tests whose leaves are of type `'a`. *)
  type 'a tree

  (* What a test says about itself, inherited from the groups above it.

     Its tags; the time it may take; the capabilities it needs (programs
     and systems outside Rune, which a doctor can look for); the CPUs and the
     megabytes of memory it takes; and, for a test that is not run, why. A
     group's tags add to its tests', and for the rest the nearest says. *)
  type meta = {tags : string list, timeout : Time.time option, requires : string list,
               cpus : int option, memory : int option, pending : string option}

  (* Tests that run in this process: each is a function that fails by
     raising, or by failing a check of `Expect`. *)
  type test = (unit -> unit) tree

  (* `it name x` is a test named `name` whose leaf is `x`.

     Example: `List.map #path (leaves (it "one" ())) = ["one"]` *)
  val it : string -> 'a -> 'a tree

  (* `describe name ts` is the group of the tests `ts`, its name before
     each of their paths.

     Example: `List.map #path (leaves (describe "lib" [it "json" (), it "digest" ()])) = ["lib/json", "lib/digest"]` *)
  val describe : string -> 'a tree list -> 'a tree

  (* `tag t tree` gives every test of `tree` the tag `t`.

     Example: `List.map (#tags o #meta) (leaves (tag "slow" (it "big" ()))) = [["slow"]]` *)
  val tag : string -> 'a tree -> 'a tree

  (* `timeout t tree` says that a test of `tree` may take `t`. A runner
     ends a test that takes longer; a suite run in one process cannot, and
     only lists it. *)
  val timeout : Time.time -> 'a tree -> 'a tree

  (* `requires cs tree` says that the tests of `tree` need the capabilities
     `cs`, as `"tmux"` or `"mlton"`. *)
  val requires : string list -> 'a tree -> 'a tree

  (* `resources {cpus, memory} tree` says that a test of `tree` takes
     `cpus` processors and `memory` megabytes, for a runner's scheduler. *)
  val resources : {cpus : int, memory : int} -> 'a tree -> 'a tree

  (* `pending reason tree` keeps the tests of `tree` listed but not run,
     and says why.

     Example: `List.map (#pending o #meta) (leaves (pending "a bug" (it "x" ()))) = [SOME "a bug"]` *)
  val pending : string -> 'a tree -> 'a tree

  (* `ways ws tree` makes every test of `tree` once for each way of `ws`,
     a name and a value (D7).

     The test of the way `(n, w)` has the name `name[n]`, the tag `way:n`,
     and the leaf `f w`.

     Example: `List.map #path (leaves (ways [("a", 1), ("b", 2)] (it "t" (fn w => w)))) = ["t[a]", "t[b]"]` *)
  val ways : (string * 'w) list -> ('w -> 'a) tree -> 'a tree

  (* `map f tree` is `tree` with `f` applied to every leaf. *)
  val map : ('a -> 'b) -> 'a tree -> 'b tree

  (* `leaves tree` is every test of `tree` with its path and its metadata,
     in the order they were written. *)
  val leaves : 'a tree -> {path : string, meta : meta, leaf : 'a} list

  (* `property name p` is a test that checks the property `p ()` with
     `Check.default` (D5).

     When the property does not hold, the test fails with its report: the
     shrunk counterexample and the replay token. *)
  val property : string -> (unit -> Prop.prop) -> test

  (* `golden name {expected, actual}` is a test that checks that the file
     `expected` holds the text `actual ()` (`Golden.check`). *)
  val golden : string -> {expected : string, actual : unit -> string} -> test
end
