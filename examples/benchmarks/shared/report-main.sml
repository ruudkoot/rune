structure BenchReportMain =
struct
  val _ = BenchReport.main () handle e =>
    (TextIO.output (TextIO.stdErr,"bench-report: " ^ General.exnMessage e ^ "\n");
     OS.Process.exit OS.Process.failure)
end
