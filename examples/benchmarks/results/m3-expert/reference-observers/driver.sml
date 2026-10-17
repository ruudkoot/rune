functor BenchExpertDriverFn(P:sig val process:string->char BenchStream.stream->char BenchStream.stream end)=
struct
  structure L=BenchLazy
  structure S=BenchStream
  fun read path=let val f=TextIO.openIn path val str=TextIO.inputAll f val _=TextIO.closeIn f in str end
  fun consume reference output=
    let fun loop index xs=case L.force xs of S.Nil=>if index=String.size reference then index
              else raise Fail "incorrect result: short expert dialog"
          |S.Cons(c,rest)=>if index<String.size reference andalso L.force c=String.sub(reference,index)
              then loop(index+1)rest else raise Fail "incorrect result: expert dialog character"
    in loop 0 output end
  fun take n xs=L.delay(fn()=>if n<=0 then S.Nil else case L.force xs of S.Nil=>S.Nil
    |S.Cons(c,rest)=>S.Cons(c,take(n-1)rest))
  fun run[repetitions,knowledge,input,reference]=
    let val count=BenchInput.between(0,1000000)(BenchInput.integer repetitions)
        val animals=read knowledge
        val contents=S.fromList(String.explode(read input))
        val expected=read reference
        fun loop index total=if index>count then total else
          loop(index+1)(total+IntInf.fromInt(consume expected(P.process animals(take(index+9999)contents))))
    in Int.toString count^" "^IntInf.toString(loop 1 0)end
    |run _=raise Fail "expected repetitions, knowledge, answers and dialog reference"
end
