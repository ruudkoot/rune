functor BenchCompressDriverFn
  (C : sig val compress : string -> string end) =
struct
  fun file path =
    let val stream = BinIO.openIn path
        val bytes = BinIO.inputAll stream
        val _ = BinIO.closeIn stream
    in Byte.bytesToString bytes end
  fun twoDigits n = if n<10 then "0"^Int.toString n else Int.toString n
  fun run [path,iterations,reference] =
    let
      val repetitions = BenchInput.between (1,500) (BenchInput.integer iterations)
      val input = file path
      val fixtures = Vector.tabulate(31,fn cut =>
        file(reference^"/cut-"^twoDigits cut^".bin"))
      fun loop i total = if i>repetitions then IntInf.toString total else
        let val cut = i mod 31
            val size = Int.max(0,String.size input-cut)
            val bytes = C.compress(String.substring(input,0,size))
            val expected = Vector.sub(fixtures,cut)
            val _ = if bytes=expected then () else raise Fail "compressed bytes differ"
            val hash = Word64.toLargeIntX(BenchNofibHash.hash bytes)
        in loop(i+1)(IntInf.+(total,hash)) end
    in loop 1 0 end
    | run _ = raise Fail "compress expects input repetitions reference-directory"
end
