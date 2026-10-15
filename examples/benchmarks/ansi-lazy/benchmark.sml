structure Benchmark =
struct
 structure K = BenchAnsiFn(BenchNeed)
 val name = "ansi-lazy"
 fun run [size,path] =
   let val n=BenchInput.between(0,900)(BenchInput.integer size)
       val file=TextIO.openIn path
       val expected=TextIO.inputAll file
       val _=TextIO.closeIn file
       fun loop input i (hash:Word32.word) = case BenchNeed.force input of K.Q.Nil =>
             if i=String.size expected then Int.toString i^":"^Word32.toString hash
             else raise Fail "ANSI output length differs"
         | K.Q.Cons(c,rest) => let val value=BenchNeed.force c
             in if i<String.size expected andalso value=String.sub(expected,i)then
               loop rest(i+1)(Word32.+(Word32.*(hash,0w131),Word32.fromInt(Char.ord value)))
             else raise Fail "ANSI output differs"end
   in loop(K.run n(K.Q.empty()))0 0w0 end
   | run _=raise Fail "ansi expects composition-count fixture"
end
