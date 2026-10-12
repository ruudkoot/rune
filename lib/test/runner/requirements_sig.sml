(* What a test needs of the machine (docs/plans/unit-testing.md, D18): a
   capability is a name, a probe and an install hint. A test names the
   capabilities it needs (`Test.requires`); the runner probes each once, and
   a test whose capability is missing is skipped with the hint, or fails in
   a run that must be complete, as the tier check is.

   RUNE_TEST_WITHOUT names capabilities to take as missing, separated by
   commas, so that what a machine without them gets can be seen on one
   that has them.

   Area: Running tests *)
signature REQUIREMENTS =
sig
  (* A capability: its name, a command of the shell that exits with 0 when
     it is there, and how to get it. *)
  type capability = {name : string, probe : string, hint : string}

  (* `present (cs, name)` says whether the capability `name` of `cs` is
     there, probing it once; one that `cs` does not name is not. *)
  val present : capability list * string -> bool

  (* `missing (cs, names)` is the capabilities among `names` that are not
     there, each with its hint. *)
  val missing : capability list * string list -> (string * string) list
end
