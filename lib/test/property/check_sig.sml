(* Running properties: many cases, each from its own seed at a size that
   grows over the run, and a report.

   The seed of a run is a hash of the property's name unless a seed is
   given, so that a run is the same on every machine, and a failure is
   reported with a token that runs its case again.

   Area: Property testing *)
signature CHECK =
sig
  (* How a property is run.

     `seed` is the seed of the run (`NONE`: a hash of the name), `tests` the
     number of cases that must pass, `maxSize` the largest size, and
     `maxDiscards` the number of discarded cases after which the run gives
     up. *)
  type config = {seed : Word64.word option, tests : int, maxSize : int, maxDiscards : int}

  (* 100 cases, sizes up to 100, a seed from the name, giving up after 1000
     discarded cases. *)
  val default : config

  (* What a run found. `Failed`'s `replay` is the token of its case. *)
  datatype result =
      Passed of {tests : int, discarded : int, labels : (string * int) list, short : (string * real * real) list}
    | Failed of {test : int, size : int, class : string, message : string, counterexample : string list,
                 replay : string}
    | GaveUp of {tests : int, discarded : int}

  (* `check c name p` runs `p` as `c` says. *)
  val check : config -> string -> Prop.prop -> result

  (* `replay token p` runs the case of a `Failed` result's `replay` token
     again: its verdict and what it drew, or `NONE` when the token is not
     one. *)
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
