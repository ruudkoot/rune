structure Benchmark =
struct
  val name="spellcheck-lazy"
  fun calculate tree text=
    let val(missing,n)=BenchStream.foldl(fn(word,(bad,n))=>
          (if BenchWordSet.member word tree then bad else word::bad,n+1))([],0)(BenchSpellCheck.words text)
    in(List.rev missing,n)end
  fun run args=BenchSpellCheck.run calculate args
end
