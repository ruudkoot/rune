(* What earlier runs found (docs/plans/unit-testing.md, D13): per test, the
   last wall times, the last outcome and how often it flipped, in a table of
   tab-separated lines that each run rewrites. A fresh tree reads a seed
   instead, which only a run of every test may write, since a test missing
   from it would look cheap (HOL4's rule).

   Area: Running tests *)
signature HISTORY =
sig
  (* A test's record: its path, its last wall times, its last verdict and
     how often its verdict changed.

     The wall times are in seconds, newest first, at most five; `flips`
     counts the runs whose verdict was not the one before. *)
  type entry = {path : string, walls : real list, passed : bool, flips : int}

  (* A history: the records of the tests, by path. *)
  type history

  (* The empty history.

     Example: `not (isSome (cost (empty, "any")))` *)
  val empty : history

  (* `read file` is the history in `file`, or `empty` when there is none. *)
  val read : string -> history

  (* `write (file, h)` writes `h` to `file`, replacing it. *)
  val write : string * history -> unit

  (* `record (h, {path, wall, passed})` is `h` with the run of a test
     added: its wall time first among its five, and its flips counted.

     Example: `Real.== (valOf (cost (record (empty, {path = "t", wall = 2.0, passed = true}), "t")), 2.0)` *)
  val record : history * {path : string, wall : real, passed : bool} -> history

  (* `cost (h, path)` is what the test of `path` is expected to take: the
     longest of its last wall times, or `NONE` for a test never run. *)
  val cost : history * string -> real option

  (* `failedLast (h, path)` says whether the test of `path` failed the last
     time it ran.

     Example: `failedLast (record (empty, {path = "t", wall = 1.0, passed = false}), "t") = true` *)
  val failedLast : history * string -> bool

  (* `entries h` is every record of `h`, by path. *)
  val entries : history -> entry list
end
