structure RegexProbe =
struct
  val expression="[a-l][a-l][a-l][a-l][1-1]abcdefghijklmnopqrstuvwxy"
  val(hash,n)=Benchmark.calculate(BenchRegex.parse expression)
  val _=print("HASH "^IntInf.toString(Word64.toLargeIntX hash)^" LENGTH "^Int.toString n^"\n")
  val _=print "SUMMARY 0 checks, 0 failed\n"
end
