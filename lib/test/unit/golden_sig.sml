(* Golden files (docs/plans/unit-testing.md, D6): what a test produced,
   compared with a file that holds what it must produce. A difference fails
   the check and says where the two first differ. In accept mode the file is
   written instead, for a person to review before it is committed: an
   accepted file is read line by line, as every expected file is
   (AGENTS.md).

   Area: Unit testing *)
signature GOLDEN =
sig
  (* Whether `check` writes the files instead of comparing them: `false`
     unless a suite was run with `--accept`. *)
  val accept : bool ref

  (* `check (label, {expected, actual})` checks that the file `expected`
     holds exactly the text `actual`.

     A missing file fails the check, unless `accept` is set, when it is
     written. *)
  val check : string * {expected : string, actual : string} -> unit

  (* `difference (expected, actual)` is where two texts first differ, as a
     line number and the two lines, or `NONE` when they are equal.

     Example: `difference ("a\nb\n", "a\nc\n") = SOME (2, "b", "c")` *)
  val difference : string * string -> (int * string * string) option
end
