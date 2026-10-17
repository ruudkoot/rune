functor BenchHartelTypecheckDriverFn(P:sig val calculate:int->(string->unit)->string end)=
struct
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun rows text=
    let val n=String.size text
        fun loop start acc=if start=n then rev acc else
          let fun finish i=if i=n then raise Fail "unterminated type row"
                else if String.sub(text,i)= #"\n"then i+1 else finish(i+1)
              val stop=finish start
          in loop stop(String.substring(text,start,stop-start)::acc)end
    in loop 0[]end
  fun calculate count expected=
    let val checked=ref 0 val lines=rows expected
        val _=if length lines=8 then()else raise Fail "expected eight type rows"
        fun observe row=
          if row=List.nth(lines,!checked mod 8)then checked:= !checked+1
          else raise Fail "incorrect result: inferred type row"
        val result=P.calculate count observe
        val _=if !checked=count*8 then()else raise Fail "incorrect result: type row count"
    in result end
  fun run[count,path]=
    let val count=BenchInput.between(0,25000)(BenchInput.integer count)
        val result=calculate count(read path)
    in String.substring(result,0,String.size result-1)end
    |run _=raise Fail "expected repetition count and inferred-row reference"
end
