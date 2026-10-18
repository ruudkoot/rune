structure BenchCountsMain =
struct
  val _ = BenchCounts.main () handle e =>
    (TextIO.output (TextIO.stdErr,"bench-counts: " ^ General.exnMessage e ^ "\n");
     OS.Process.exit OS.Process.failure)
end
