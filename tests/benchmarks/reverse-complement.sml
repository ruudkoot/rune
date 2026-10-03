structure BenchReverseComplementTests =
struct
  val bases = "AaCcGgTtUuMmRrYyKkVvHhDdBbNN"
  val converted = "NNVVHHDD BBMMRRYYKKAAAACCGGTT"
  val _ = T.check("reverse/all-complements",fn () =>
    Benchmark.output(">record\n"^bases^"\n") = ">record\n"^
      String.concat(String.tokens Char.isSpace converted)^"\n")
  val _ = T.check("reverse/odd-centre",fn () => Benchmark.output">r\nACG\n" = ">r\nCGT\n")
  val _ = T.check("reverse/preserve-line-positions",fn () =>
    Benchmark.output">r\nAC\nGTTA\n" = ">r\nTA\nACGT\n")
  val _ = T.check("reverse/growing-buffer",fn () =>
    let val input = String.implode(List.tabulate(2049,fn _ => #"A"))
        val expected = String.implode(List.tabulate(2049,fn _ => #"T"))
    in Benchmark.output(">long\n"^input^"\n") = ">long\n"^expected^"\n" end)
  val _ = T.check("reverse/chunk-header-boundary",fn () =>
    let val left = String.implode(List.tabulate(157,fn _ => #"A"))
        val right = String.implode(List.tabulate(173,fn _ => #"C"))
        val input = ">left\n"^left^"\n>right\n"^right^"\n"
        val expected = ">left\n"^String.map(fn _ => #"T")left^
          "\n>right\n"^String.map(fn _ => #"G")right^"\n"
    in Benchmark.output input = expected end)
end
