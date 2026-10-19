structure BenchDurandKernerFiles =
struct
  structure C=BenchDurandKerner
  type reference={count:int,tolerance:real,roots:C.complex array}
  fun tokens path=let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input;String.tokens Char.isSpace text end
  fun real text=case Real.fromString text of SOME x=>
      if Real.isFinite x then x else raise Fail "nonfinite root reference"
    | NONE=>raise Fail "invalid root reference real"
  fun pairs fields=
    let fun loop [] acc=Array.fromList(List.rev acc)
          | loop(a::b::rest)acc=loop rest((real a,real b)::acc)
          | loop _ _=raise Fail "odd root reference fields"
    in loop fields []end
  fun coefficients path=case tokens path of count::rest=>
    let val size=BenchInput.between(2,98)(BenchInput.integer count)val values=pairs rest
    in if Array.length values=size then values else raise Fail "coefficient count differs"end
    | _=>raise Fail "empty root coefficient input"
  fun reference path=case tokens path of count::bound::rest=>
    let val size=BenchInput.between(1,97)(BenchInput.integer count)
        val tolerance=real bound val roots=pairs rest
        val _=if tolerance>0.0 andalso Array.length roots=size then()else raise Fail "invalid root reference"
        fun loop i j=if i=size then()else if j=size then loop(i+1)(i+2)
          else if C.norm2(C.sub(Array.sub(roots,i),Array.sub(roots,j)))>16.0*tolerance*tolerance
            then loop i(j+1)else raise Fail "root tolerance exceeds separation"
        val _=loop 0 1
    in {count=size,tolerance=tolerance,roots=roots}end
    | _=>raise Fail "missing root reference header"
  fun check({count,tolerance,roots}:reference)actual=
    let val _=if Array.length actual=count then()else raise Fail "root result count differs"
        val used=Array.array(count,false)
        fun checkOne i=
          let val value as(re,im)=Array.sub(actual,i)
              val _=if Real.isFinite re andalso Real.isFinite im then()else raise Fail "nonfinite root result"
              fun nearest j best distance=if j=count then(best,distance)
                else if Array.sub(used,j)then nearest(j+1)best distance
                else let val error=C.norm2(C.sub(value,Array.sub(roots,j)))
                  in if error<distance then nearest(j+1)j error else nearest(j+1)best distance end
              val(index,error)=nearest 0 (~1)Real.posInf
          in if index>=0 andalso error<=tolerance*tolerance then Array.update(used,index,true)
             else raise Fail "root result differs"end
        fun loop i=if i=count then()else(checkOne i;loop(i+1))
    in loop 0 end
end
