(* The strict Takeuchi recurrence shared by classic tak, tak-mlkit and
   tak-nofib-strict.
   Extracted unchanged from tak/benchmark.sml; see tak/LICENSE and the
   retained MLton and nofib sources for notices and provenance. *)
structure BenchTak =
struct
  fun tak (x, y, z) =
    if not (y < x) then z
    else tak (tak (x - 1, y, z),
              tak (y - 1, z, x),
              tak (z - 1, x, y))
end
