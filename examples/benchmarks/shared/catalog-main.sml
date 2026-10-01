structure BenchCatalogMain =
struct
  fun main () =
    let
      val entries = BenchCatalog.load "examples/benchmarks/manifest.tsv"
      val _ = BenchCatalog.validate entries
      val routine = BenchCatalog.routine entries
    in
      case CommandLine.arguments () of
        ["--check"] => print ("bench-catalog: OK (" ^ Int.toString (List.length entries) ^ " profiles)\n")
      | ["--list", profile, filter] => List.app BenchCatalog.emit (BenchCatalog.selected entries profile filter)
      | ["--routine", filter] => List.app BenchCatalog.emit (BenchCatalog.selected routine "smoke" filter)
      | _ => raise Fail "usage: bench-catalog --check | --list PROFILE FILTER"
    end
  val _ = main () handle e =>
    (TextIO.output (TextIO.stdErr, "bench-catalog: " ^ General.exnMessage e ^ "\n");
     OS.Process.exit OS.Process.failure)
end
