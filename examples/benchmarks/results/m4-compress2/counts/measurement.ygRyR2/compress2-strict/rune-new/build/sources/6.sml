(* Port of pinned nofib real/compress2; retain original sources and
   program/dataset notice status in each workload PROVENANCE.md. *)
(* Shared delayed output pairs preserve the byte-count feedback knot. *)
structure BenchCompress2Bits =
struct
  structure N=BenchNeed
  structure S=BenchCellSequenceFn(BenchNeed)
  datatype event=Code of int N.t | NewWordSize | Clear
  type codes=event S.sequence
  type result=(int S.sequence*int S.sequence)N.t
  fun value x=N.delay(fn()=>x)
  fun bytes(result:result)=N.delay(fn()=>N.force(#1(N.force result)))
  fun sizes(result:result)=N.delay(fn()=>N.force(#2(N.force result)))
  fun intAnd(x,y)=Word.toInt(Word.andb(Word.fromInt x,Word.fromInt y))
  fun intOr(x,y)=Word.toInt(Word.orb(Word.fromInt x,Word.fromInt y))
  fun left(x,n)=Word.toInt(Word.<<(Word.fromInt x,Word.fromInt n))
  fun right(x,n)=Word.toInt(Word.>>(Word.fromInt x,Word.fromInt n))
  fun padding count=S.replicate count(value 255)
  fun output nbits still offset previous(codes:codes):result=N.delay(fn()=>
    case N.force codes of
      S.Nil=>(S.cons previous(S.empty()),S.fromList[1])
    | S.Cons(head,tail)=>case N.force head of
        NewWordSize=>
          let val rest=output(nbits+1)8 0(value 0)tail
          in(bytes rest,S.cons(value 0)(sizes rest))end
      | Clear=>
          let val rest=output 9 8 0(value 0)tail
              val outBits=if still<>8 then nbits else 0
              val padBits=nbits-((9-still)*2)
              val count=if padBits<0 then 1 else padBits
              val prefix=S.cons previous(S.cons(value 1)(padding count))
          in(S.append prefix(bytes rest),S.cons(value outBits)(sizes rest))end
      | Code code=>
          if still=0 then N.force(output nbits 8 0(value 0)codes)
          else
            let val nextOffset=8-offset
                val byte1=N.delay(fn()=>intOr(N.force previous,left(N.force code,offset)))
                val byte2=N.delay(fn()=>right(N.force code,nextOffset))
                val byte3=N.delay(fn()=>right(N.force byte2,8))
                val outBits=if still=1 then nbits else 0
                val split=nbits+offset>=16
                val rest=output nbits(still-1)((offset+nbits)mod 8)(if split then byte3 else byte2)tail
                val body=if split then S.cons byte1(S.cons byte2(bytes rest))
                         else S.cons byte1(bytes rest)
            in(body,S.cons(value outBits)(sizes rest))end)
  fun outputCodes codes=output 9 8 0(value 0)codes
  fun characters result=S.map(fn n=>Char.chr(intAnd(255,n)))(bytes result)
end
