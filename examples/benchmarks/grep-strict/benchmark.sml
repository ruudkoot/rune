structure Benchmark =
struct
 structure G=BenchGrepFn(BenchStrict)
 val name="grep-strict"
 fun read path=let val file=BinIO.openIn path
                   val data=BinIO.inputAll file
                   val _=BinIO.closeIn file
               in BenchUTF8.decode(Byte.bytesToString data)end
 fun hashLine codes (hash:Word64.word)=List.foldl(fn(c,h)=>Word64.+(Word64.fromInt c,Word64.*(h,0w31)))hash(codes@[10])
 fun run [repetitions,pattern,path,fixture]=
   let val n=BenchInput.between(1,250)(BenchInput.integer repetitions)
       val codes=read path
       val regex=BenchUTF8.decode pattern
       val expected=BenchUTF8.lines(read fixture)
       val count=List.length expected
       fun once ()=
         let val producer=G.compile regex
             fun consume [] rest hash=if List.null rest then Word64.toLargeIntX hash else raise Fail "grep missed lines"
               | consume(line::lines)rest hash=
                   if G.accept producer line then
                     (case rest of want::tail=>
                       if line=want then consume lines tail(hashLine line hash)else raise Fail "grep selected a different line"
                       | []=>raise Fail "grep selected extra lines")
                   else consume lines rest hash
         in consume(BenchUTF8.lines codes)expected 0w0 end
       fun loop 0 total=Int.toString n^":"^Int.toString count^":"^IntInf.toString total
         | loop left total=loop(left-1)(IntInf.+(total,once()))
   in loop n(IntInf.fromInt 0)end
   | run _=raise Fail "grep expects repetitions regexp input fixture"
end
