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
     up, and `maxShrinks` the number of runs the shrinker may make. *)
  type config = {seed : Word64.word option, tests : int, maxSize : int, maxDiscards : int, maxShrinks : int}

  (* 100 cases, sizes up to 100, a seed from the name, giving up after 1000
     discarded cases, shrinking in at most 5000 runs. *)
  val default : config

  (* What a run found.

     `Failed` has the shrunk case: `counterexample` is what it drew, as
     shown, and `calls` the calls of each of its generated functions, with
     `shrinks` the runs that the shrinking took. `replay` is the token of the
     case as it was drawn. *)
  datatype result =
      Passed of {tests : int, discarded : int, labels : (string * int) list, short : (string * real * real) list}
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
end
