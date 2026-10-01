structure BenchCatalogTests =
struct
  val entries = BenchCatalog.load "examples/benchmarks/manifest.tsv"
  val base = hd entries
  fun rejected needle f = (f (); false) handle Fail message => String.isSubstring needle message
  val _ = T.check ("benchmark.catalog/valid", fn () => (BenchCatalog.validate entries; not (List.null entries)))
  val _ = T.check ("benchmark.catalog/duplicate", fn () =>
    rejected "duplicate" (fn () => BenchCatalog.validate (base :: entries)))
  val _ = T.check ("benchmark.catalog/missing-profile", fn () =>
    rejected "missing benchmark profile" (fn () => BenchCatalog.validate (tl entries)))
  fun changed profile sources : BenchCatalog.entry =
    {name = #name base, profile = profile, upstream = #upstream base,
     sourcePath = #sourcePath base, args = #args base, expected = #expected base,
     sources = sources, seconds = #seconds base, memory = #memory base, tags = #tags base, inputFiles = #inputFiles base,
     resultCheck = #resultCheck base, status = #status base}
  val _ = T.check ("benchmark.catalog/profile", fn () =>
    rejected "invalid benchmark profile" (fn () => BenchCatalog.validate (changed "unknown" (#sources base) :: tl entries)))
  val _ = T.check ("benchmark.catalog/escape", fn () =>
    rejected "invalid relative" (fn () => BenchCatalog.validate (changed "smoke" ["../kernel.sml"] :: tl entries)))
end
