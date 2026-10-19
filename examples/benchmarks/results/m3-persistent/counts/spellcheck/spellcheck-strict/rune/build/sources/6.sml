structure Benchmark =
struct
  val name="spellcheck-strict"
  fun calculate tree text=
    let val input=String.tokens BenchSpellCheck.space text
        val missing=List.filter(fn word=>not(BenchWordSet.member word tree))input
    in(missing,List.length input)end
  fun run args=BenchSpellCheck.run calculate args
end
