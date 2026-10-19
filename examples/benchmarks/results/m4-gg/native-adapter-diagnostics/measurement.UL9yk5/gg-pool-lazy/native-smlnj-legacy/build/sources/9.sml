(* Exact graph text checks with explicit numeric-operand allowances.
   Whole-stream forward hashing is checked against per-line reverse hashes. *)
structure BenchGGCheck =
struct
 structure W=Word64
 structure L=BenchLazy
 structure S=BenchStream
 datatype row=Row of string*W.word*W.word
 fun reverseHash text=
   let fun loop i power sum=if i<0 then sum else
         loop(i-1)(W.*(power,0w31))
           (W.+(sum,W.*(power,W.fromInt(Char.ord(String.sub(text,i))))))
   in loop(String.size text-1)0w1 0w0 end
 fun power length=
   let fun loop 0 result=result|loop n result=loop(n-1)(W.*(result,0w31))
   in loop length 0w1 end
 fun rows text=
   let val size=String.size text
       fun stop i=if i=size orelse String.sub(text,i)= #"\n"then i else stop(i+1)
       fun loop i=if i=size then[]else
         let val last=stop i val next=if last=size then last else last+1
             val line=String.substring(text,i,next-i)
         in Row(line,reverseHash line,power(String.size line))::loop next end
   in loop 0 end
 fun integer text=
   let val chars=String.explode text
       val digits=case chars of #"-"::rest=>rest| #"~"::rest=>rest|_=>chars
   in not(List.null digits)andalso List.all Char.isDigit digits end
 fun numeric(a,b)=
   if integer b then integer a andalso
     (case(IntInf.fromString a,IntInf.fromString b)of(SOME x,SOME y)=>x=y|_=>false)
   else case(Real.fromString a,Real.fromString b)of(SOME x,SOME y)=>
       if Real.isNan y then Real.isNan x
       else if not(Real.isFinite y)then not(Real.isFinite x)andalso not(Real.isNan x)
         andalso Real.signBit x=Real.signBit y
       else BenchInput.closeReal(x,y,1.0E~12,1.0E~12)
     |_=>false
 fun equivalent actual expected=
   if actual=expected then true else
     case(String.fields(fn c=>c= #" ")actual,String.fields(fn c=>c= #" ")expected)of
       ([x,y,command],[a,b,wanted])=>command=wanted andalso
         (command="scale\n"orelse command="moveto\n")andalso numeric(x,a)andalso numeric(y,b)
     |_=>false
 fun consume text expected=
   let
     fun checked line wanted=
       case wanted of []=>raise Fail "incorrect result: extra GRIP graph line"
       |Row(reference,hash,factor)::rest=>
         if line=reference then(hash,factor,rest)
         else if equivalent line reference then(reverseHash line,power(String.size line),rest)
         else raise Fail "incorrect result: GRIP graph text or numeric operands"
     fun loop chars wanted buffer count forward combined=
       case L.force chars of S.Nil=>
         let val(count,combined,wanted)=if List.null buffer then(count,combined,wanted)
               else let val line=String.implode(List.rev buffer)
                        val(hash,factor,rest)=checked line wanted
                    in(count+1,W.+(W.*(combined,factor),hash),rest)end
         in if not(List.null wanted)then raise Fail "incorrect result: missing GRIP graph lines"
            else if forward<>combined then raise Fail "incorrect result: GRIP output hash"
            else count end
       |S.Cons(first,tail)=>
         let val c=L.force first
             val hash=W.+(W.*(forward,0w31),W.fromInt(Char.ord c))
         in if c= #"\n"then
              let val line=String.implode(List.rev(c::buffer))
                  val(lineHash,factor,rest)=checked line wanted
              in loop tail rest[](count+1)hash(W.+(W.*(combined,factor),lineHash))end
            else loop tail wanted(c::buffer)count hash combined end
   in loop text expected[]0 0w0 0w0 end
end
