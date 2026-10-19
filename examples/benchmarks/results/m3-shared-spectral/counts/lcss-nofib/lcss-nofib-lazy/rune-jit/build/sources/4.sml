structure BenchLCSS =
struct
  fun range(a,b,last)=
    let val step=b-a
        val _=if step=0 then raise Fail "zero sequence step"else()
        fun loop x=if(if step>0 then x>last else x<last)then[]else x::loop(x+step)
    in loop a end
  fun findSplit sums =
    let fun loop(_,best,_,[])=best
          |loop(k,best,largest,(x,y)::xs)=let val value=x+y
            in if value>=largest then loop(k+1,k,value,xs)else loop(k+1,best,largest,xs)end
    in loop(0,0,~1,sums)end
  fun run calculate [a,b,c,d,e,f,reference]=
    let val args=List.map BenchInput.integer[a,b,c,d,e,f]
        val(x,y)=case args of[a,b,c,d,e,f]=>(range(a,b,c),range(d,e,f))|_=>raise Fail "sequence arguments"
        val _=if null x then raise Fail "original empty-first-sequence case is unsupported"else()
        val _=if List.length x<=4000 andalso List.length y<=4000 then()else raise Fail "sequence too large"
        val _=if List.exists(fn p=>p=reference)["expected/smoke.txt","expected/normal.txt","expected/large.txt"]then()else raise Fail "LCSS reference path"
        val input=TextIO.openIn reference val expected=TextIO.inputAll input val _=TextIO.closeIn input
        val result=calculate x y
        val rendered="["^String.concatWith","(List.map Int.toString result)^"]\n"
    in if rendered=expected then Int.toString(List.length result)else raise Fail "LCSS full sequence differs"end
    |run _ _=raise Fail "lcss expects two arithmetic sequences and reference"
end
