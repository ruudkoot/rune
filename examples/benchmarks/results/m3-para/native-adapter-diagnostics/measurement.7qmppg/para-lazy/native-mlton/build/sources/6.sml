functor BenchParaDriverFn(K:sig val chars:string->char BenchStream.stream
    val formatText:char BenchStream.stream->char BenchStream.stream end) =
struct
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun consume expected output=
    let fun loop index values=case BenchLazy.force values of BenchStream.Nil=>
          if index=String.size expected then index
          else raise Fail "incorrect result: paragraph output length"
        |BenchStream.Cons(c,rest)=>
          if index<String.size expected andalso BenchLazy.force c=String.sub(expected,index)
          then loop(index+1)rest else raise Fail "incorrect result: paragraph output text"
    in loop 0 output end
  fun run[repeatsText,input,reference]=
    let val repeats=BenchInput.between(0,1000)(BenchInput.integer repeatsText)
        val expected=read reference
        fun loop 0 checked=Int.toString repeats^":"^Int.toString checked
          |loop n checked=
            (* Reopen and parse for each source iteration; no shared parse cache. *)
            let val text=read input
                val length=consume expected(K.formatText(K.chars text))
            in loop(n-1)(checked+length)end
    in loop repeats 0 end
    |run _=raise Fail "para expects repetitions, input path and formatted reference"
end
