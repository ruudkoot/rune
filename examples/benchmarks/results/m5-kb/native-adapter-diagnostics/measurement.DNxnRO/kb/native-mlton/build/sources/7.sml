functor BenchSandmarkKBDriverFn(K:sig
  val complete: (BenchSandmarkKBTerms.term*BenchSandmarkKBTerms.term->bool)->
    BenchSandmarkKBTerms.rule list->BenchSandmarkKBTerms.rule list->BenchSandmarkKBTerms.rule list
end) =
struct
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun run[repeatsText,path]=
    let val repeats=BenchInput.between(0,1000)(BenchInput.integer repeatsText)
        val expected=read path
        fun loop 0 count=Int.toString repeats^":"^Int.toString count
          |loop n count=
             let val rules=K.complete BenchSandmarkKBOrder.greater[]BenchSandmarkKBData.rules
                 val text=String.concat(List.map BenchSandmarkKBTerms.canonicalRule rules)
             in if text=expected then loop(n-1)(count+List.length rules)
                else raise Fail "incorrect result: Sandmark KB completed rules"end
    in loop repeats 0 end
    |run _=raise Fail "Sandmark KB expects repetitions and completed-rule reference"
end
