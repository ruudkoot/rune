(* Source history and adaptations are in PROVENANCE.md; the copying kernel is shared. *)
structure Benchmark =
struct
  val name = "kittmergesort"
  val run = BenchKittSort.run
end
