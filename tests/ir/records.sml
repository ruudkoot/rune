(* dump: --dump-after=translate *)
(* A record is a tuple in the order of its labels, its fields evaluated in
   the order of the source: b before a, each held in a let. *)
val r = {b = 1 + 1, a = 2 + 2}
