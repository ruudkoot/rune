structure BenchPiDigitsFive =
struct
  type state=IntInf.int*IntInf.int*IntInf.int
  val three=IntInf.fromInt 3 val four=IntInf.fromInt 4 val ten=IntInf.fromInt 10
  val initial:state=(IntInf.fromInt 1,IntInf.fromInt 1,IntInf.fromInt 0)
  fun extract(num,den,acc)nth=IntInf.toInt(IntInf.quot(IntInf.+(IntInf.*(nth,num),acc),den))
  fun produce(num,den,acc)digit=
    let val nextAcc=IntInf.*(ten,IntInf.-(acc,IntInf.*(den,IntInf.fromInt digit)))
        val nextNum=IntInf.*(ten,num)
    in(nextNum,den,nextAcc)end
  fun consume(num,den,acc)k=
    let val k2=IntInf.fromInt(2*k+1)
        val nextAcc=IntInf.*(k2,IntInf.+(IntInf.+(acc,num),num))
        val nextDen=IntInf.*(k2,den)
        val nextNum=IntInf.*(IntInf.fromInt k,num)
    in(nextNum,nextDen,nextAcc)end
  fun run count emit=
    let fun spaces n=String.implode(List.tabulate(n,fn _=> #" "))
        fun digits k state left row col=
          if left=0 then emit(spaces(10-col)^"\t:"^Int.toString(row+col)^"\n")
          else let val candidate=extract state three
            in if extract state four=candidate then
              if col=10 then
                let val nextRow=row+col
                in emit("\t:"^Int.toString nextRow^"\n"^Int.toString candidate);
                   digits k(produce state candidate)(left-1)nextRow 1 end
              else(emit(Int.toString candidate);digits k(produce state candidate)(left-1)row(col+1))
              else digits(k+1)(consume state k)left row col end
    in digits 1 initial count 0 0 end
  fun check count expected=
    let val position=ref 0
        fun emit text=
          let val n=String.size text
          in if !position+n<=String.size expected andalso
            String.substring(expected,!position,n)=text then position:= !position+n
            else raise Fail "incorrect result: pi digits or layout differ"end
        val _=run count emit
    in if !position=String.size expected then()else raise Fail "incorrect result: missing pi output"end
end
