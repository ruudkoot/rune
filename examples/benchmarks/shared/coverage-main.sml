structure BenchCoverageMain =
struct
  fun main () =
    let
      val entries=BenchCatalog.load(BenchCatalog.root ^ "manifest.tsv")
      val sources=BenchCoverage.sources(BenchCatalog.root ^ "inventory.tsv")
      val _=BenchCatalog.validate entries
      val _=BenchCoverage.validate sources entries
      val companions=BenchCoverage.companions(BenchCatalog.root ^ "source-variants.tsv")
      val _=BenchCoverage.documentation entries
    in case CommandLine.arguments() of
        ["--check"] => print("bench-coverage: OK (" ^ Int.toString(List.length sources) ^ " primary entries, " ^
            Int.toString companions ^ " companions, " ^ Int.toString(List.length(BenchCoverage.names entries)) ^ " programs)\n")
      | ["--report"] => BenchCoverage.report sources entries
      | _ => raise Fail "usage: bench-coverage --check | --report"
    end
  val _=main() handle e=>
    (TextIO.output(TextIO.stdErr,"bench-coverage: " ^ General.exnMessage e ^ "\n");OS.Process.exit OS.Process.failure)
end
