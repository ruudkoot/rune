(* Running properties: many cases, each from its own seed at a size that
   grows over the run, and a report.

   The seed of a run is a hash of the property's name unless a seed is
   given, so that a run is the same on every machine, and a failure is
   reported with a token that runs its case again.

   A failing case is shrunk before it is reported. The shrinker changes the
   words the case read: it deletes, joins and swaps the elements of lists,
   makes generated functions constants, and lowers words towards 0, the
   simplest. It keeps a change only when the case still fails with the same
   class and has become simpler (fewer words read, or smaller ones), so that
   a `Div` never turns into an `Overflow` and the shrinking ends.

   Area: Property testing *)
signature CHECK =
sig
  (* How a property is run.

     `seed` is the seed of the run (`NONE`: a hash of the name), `tests` the
     number of cases that must pass, `maxSize` the largest size,
     `maxDiscards` the number of discarded cases after which the run gives
     up, `maxShrinks` the number of runs the shrinker may make, and
     `exhaustiveBelow` the most cases a property may have for every one of
     them to be run instead (0: never), and `smallScope` the number of cases
     of the small scope that are run before the random ones (0: none).

     A property has finitely many cases when every word its case reads has
     finitely many values (a `bool`, a `char`, an `Int8.int`, a choice among
     a list, and tuples of these), and no length: exhaustive mode then runs
     them all, at size `maxSize`, simplest first, and a failure found is the
     simplest there is, with no shrinking.

     Otherwise the small scope is run first: the cases in which every word
     read is 0, 1 or 2 (integers 0, ~1 and 1, lengths up to 2, the first
     characters, both booleans), simplest first, as many as `smallScope`
     allows. A failure there is reported as exhaustive mode reports one; the
     cases that pass are not counted in `tests`. A property whose values need
     each other's bounds (an index one past the end of a string drawn beside
     it) fails there where random cases rarely meet it. *)
  type config = {seed : Word64.word option, tests : int, maxSize : int, maxDiscards : int, maxShrinks : int,
                 exhaustiveBelow : int, smallScope : int}

  (* 100 cases at sizes up to 100, from a seed that is a hash of the name.

     A run gives up after 1000 discarded cases and shrinks in at most 5000
     runs. It runs every case of a property with at most 65536 of them
     (docs/plans/quickcheck.md, P9), and otherwise first 100 cases of the
     small scope (P13). *)
  val default : config

  (* What a run found.

     `Failed` has the shrunk case: `counterexample` is what it drew, as
     shown, and `calls` the calls of each of its generated functions, with
     `shrinks` the runs that the shrinking took. `replay` is the token of the
     case as it was drawn. `Passed`'s `exhaustive` says that its cases were
     every case there is. *)
  datatype result =
      Passed of {tests : int, discarded : int, exhaustive : bool, labels : (string * int) list,
                 short : (string * real * real) list}
    | Failed of {test : int, size : int, class : string, message : string, counterexample : string list,
                 calls : string list list, shrinks : int, replay : string}
    | GaveUp of {tests : int, discarded : int}

  (* `check c name p` runs `p` as `c` says. *)
  val check : config -> string -> Prop.prop -> result

  (* `replay token p` runs the case of a `Failed` result's `replay` token again, shrunk as the run shrank it.

     It is the case's verdict and what it drew, or `NONE` when the token is
     not one. *)
  val replay : string -> Prop.prop -> Prop.result option

  (* `report name r` is the report of a run: a first line `PASS name` or
     `FAIL name`, and what the run found. *)
  val report : string -> result -> string

  (* `passed r` is `true` for a run that passed and had the coverage it asked
     for. *)
  val passed : result -> bool

  (* `main ps` runs each named property with `default`, prints its report,
     and ends the program with failure if one did not pass. *)
  val main : (string * Prop.prop) list -> unit

  (* `laws ls` runs the laws of a program of `runedoc --laws`, each named, and ends the program with failure if one did not pass.

     Before each law it prints `LAW name`, so that a run a watchdog stops
     names the law it was in, and after it the law's report. The
     environment chooses how they run (docs/plans/quickcheck.md, D9 and
     D13): `RUNE_PROPERTY_DEEP` runs 10000 cases for each seed from 1 to
     1000 until one fails; `RUNE_PROPERTY_ONLY` runs the law of that name
     alone; `RUNE_PROPERTY_AT` the laws at the structure of that name;
     `RUNE_PROPERTY_AFTER` runs the laws after the one of that name,
     where a run that was stopped goes on; `RUNE_PROPERTY_REPLAY` runs the
     case of that replay token, shrunk, and prints it. The last line counts
     the laws that passed and failed. *)
  val laws : (string * (unit -> Prop.prop)) list -> unit
end
