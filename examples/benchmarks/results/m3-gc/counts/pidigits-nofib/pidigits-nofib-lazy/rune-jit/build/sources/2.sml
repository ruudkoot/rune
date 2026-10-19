structure BenchNofibPi =
struct
  fun next(k,n,a,d)=let val big=IntInf.fromInt k val y=IntInf.fromInt(2*k+1)
    in(IntInf.*(n,big),IntInf.*(IntInf.+(a,IntInf.*(n,2)),y),IntInf.*(d,y))end
  fun candidate(n,a,d)=IntInf.divMod(IntInf.+(IntInf.*(n,3),a),d)
  fun format digits =
    let fun split(0,xs,chars)=(List.rev chars,xs)
          |split(_,[],chars)=(List.rev chars,[])
          |split(n,x::xs,chars)=split(n-1,xs,x::chars)
        fun blocks([],_,acc)=String.concat(List.rev acc)
          |blocks(xs,index,acc)=let val(chars,rest)=split(10,xs,[])
              val count=List.length chars
              val block=String.implode chars
              val padded=block^String.implode(List.tabulate(10-count,fn _=> #" "))
              val line=padded^"\t:"^Int.toString(index+count)^"\n"
            in blocks(rest,index+count,line::acc)end
    in blocks(digits,0,[])end
  fun run calculate[size,reference]=
    let val n=BenchInput.between(1,22000)(BenchInput.integer size)
        val _=if List.exists(fn p=>p=reference)["expected/smoke.txt","expected/normal.txt","expected/large.txt"]then()else raise Fail "pi reference path"
        val f=TextIO.openIn reference val expected=TextIO.inputAll f val _=TextIO.closeIn f
        val actual=format(calculate n)
    in if actual=expected then Int.toString(String.size actual)else raise Fail "pi complete digits or block formatting differs"end
    |run _ _=raise Fail "pidigits expects digit-count reference"
end
