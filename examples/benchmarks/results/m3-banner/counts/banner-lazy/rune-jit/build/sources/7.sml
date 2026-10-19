structure Benchmark =
struct
 structure D=BenchBannerNeed
 structure K=BenchBannerFn(D)
 val name="banner-lazy"
 fun read path=let val input=BinIO.openIn path
                   val bytes=BinIO.inputAll input
                   val _=BinIO.closeIn input
               in Byte.bytesToString bytes end
 fun run [count,path,fixture]=
   let val n=BenchInput.between(0,180000)(BenchInput.integer count)
       val input=read path
       val expected=read fixture
       val width=String.size expected
       val _=if String.size input>0 andalso String.sub(input,String.size input-1)= #"\n"
                 andalso width>0 andalso List.all(fn c=>Char.ord c<128)(String.explode input)
             then()else raise Fail "banner profiles require an ASCII line-terminated template"
       val total=n*width
       fun consume stream position(hash:Word32.word)=case D.force stream of K.Q.Nil=>(position,hash)
         | K.Q.Cons(c,rest)=>let val value=D.force c
             in if position<total andalso value=String.sub(expected,position mod width)then
               consume rest(position+1)(Word32.+(Word32.*(hash,0w131),Word32.fromInt(Char.ord value)))
             else raise Fail "banner output differs"end
       fun lines stream position hash=case D.force stream of K.Q.Nil=>
             if position=total then Int.toString position^":"^Word32.toString hash else raise Fail "banner output length differs"
         | K.Q.Cons(line,rest)=>let val(next,h)=consume(K.say(D.force line))position hash
                              in lines rest next h end
   in lines(K.lines(K.repeatInput n input))0 0w0 end
   | run _=raise Fail "banner expects template-repetitions input-template output-template"
end
