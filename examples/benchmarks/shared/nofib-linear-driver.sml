functor BenchLinearDriverFn(K:sig
  type number
  val stats:int->int->(int*number*number)BenchStream.stream
  val value:number->real
end) =
struct
  structure W=Word64
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun real text=case Real.fromString text of SOME x=>BenchLinearFloat.round x
    |NONE=>raise Fail "invalid linear metric"
  fun reference text=List.map(fn row=>case String.tokens Char.isSpace row of
      [count,error,residual]=>(BenchInput.integer count,real error,real residual)
    |_=>raise Fail "linear reference expects count/error/residual")
      (String.tokens(fn c=>c= #"\n")text)
  fun number x=
    let val text=String.translate(fn #"~"=>"-"| #"E"=>"e"|c=>String.str c)
          (Real.fmt(StringCvt.GEN(SOME 9))x)
        val result=if List.exists(fn c=>c= #"."orelse c= #"e")(String.explode text)then text else text^".0"
        val _=if Real.isFinite x andalso Real.==(real result,x)then()
          else raise Fail "incorrect result: linear numeric formatting"
    in result end
  fun pad width text=String.implode(List.tabulate(Int.max(0,width-String.size text),fn _=> #" "))^text
  val header="\nIteration   norm (x-soln)   norm r  \n=========   =============   ======= \n"
  fun checksum text=CharVector.foldl(fn(c,h)=>W.+(W.*(h,0w31),W.fromInt(Char.ord c)))(0w0:W.word)text
  fun reverseChecksum text= #1(CharVector.foldr(fn(c,(total,power))=>
       (W.+(total,W.*(W.fromInt(Char.ord c),power)),W.*(power,0w31)))
       ((0w0:W.word),(0w1:W.word))text)
  fun consume expected values=
    let fun loop rows values text count=case(BenchLazy.force values,rows)of
          (BenchStream.Nil,[]) => (String.concat(List.rev text),count)
        |(BenchStream.Cons(value,rest),(wantedIndex,wantedError,wantedResidual)::rows)=>
          let val(index,error,residual)=BenchLazy.force value
              val error=K.value error val residual=K.value residual
              val _=if index=wantedIndex andalso index=count andalso
                  Real.==(error,wantedError)andalso Real.==(residual,wantedResidual)then()
                else raise Fail "incorrect result: linear iteration metrics"
              val row=pad 5(Int.toString index)^"    "^pad 25(number error)^"   "^pad 25(number residual)^"\n"
          in loop rows rest(row::text)(count+1)end
        |_=>raise Fail "incorrect result: linear iteration count"
    in loop expected values[]0 end
  fun run mode[repetitionsText,nText,limitText,path]=
    let val repetitions=BenchInput.between(0,200)(BenchInput.integer repetitionsText)
        val n=BenchInput.between(2,16)(BenchInput.integer nText)
        val limit=BenchInput.between(1,50)(BenchInput.integer limitText)
        val expected=reference(read path)
        fun loop 0 rows characters=Int.toString repetitions^":"^Int.toString rows^":"^Int.toString characters
          |loop left rows characters=
            let val(body,count)=consume expected(K.stats n limit)
                val text="START"^header^body^"\n\nEND"
                val _=if mode="real"then
                    if checksum text=reverseChecksum text then()
                    else raise Fail "incorrect result: linear text hash"
                  else if mode="gc"then()else raise Fail "linear mode must be gc or real"
            in loop(left-1)(rows+count)(characters+String.size text)end
    in loop repetitions 0 0 end
    |run _ _=raise Fail "linear expects repetitions, system size, iteration cap and metric reference"
end
