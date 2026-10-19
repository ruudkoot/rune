(* Copyright (c) Clark Gaebel 2012; Johan Tibel 2012.
   BSD-style license; full containers sources/notices retained with provenance. *)
(* containers 0.6.7, Data.IntMap/IntSet.Internal and Utils.BitUtil.
   Original sources and BSD notices accompany the benchmark provenance. *)
structure BenchDomWord =
struct
  structure W=Word64
  val sign:W.word=W.<<(0w1,0w63)
  fun word n=W.fromInt n
  fun integer w=W.toIntX w
  fun zero key mask=W.andb(key,mask)=0w0
  fun mask key branch=W.andb(key,W.xorb(W.notb(W.-(branch,0w1)),branch))
  fun match key prefix branch=mask key branch=prefix
  fun shorter a b=W.>(a,b)
  fun highest value=
    let val x1=W.orb(value,W.>>(value,0w1))
        val x2=W.orb(x1,W.>>(x1,0w2))
        val x3=W.orb(x2,W.>>(x2,0w4))
        val x4=W.orb(x3,W.>>(x3,0w8))
        val x5=W.orb(x4,W.>>(x4,0w16))
        val x6=W.orb(x5,W.>>(x5,0w32))
    in W.xorb(x6,W.>>(x6,0w1))end
  fun branch a b=highest(W.xorb(a,b))
  fun bit i=W.<<(0w1,Word.fromInt i)
  fun lowestIndex value=
    let fun narrow width offset bits=if width=1 then offset else
          let val half=width div 2
              val lower=W.-(bit half,0w1)
          in if W.andb(bits,lower)<>0w0 then narrow half offset bits
             else narrow half(offset+half)(W.>>(bits,Word.fromInt half))end
    in if value=0w0 then raise Fail "zero bit index"else narrow 64 0 value end
  fun highestIndex value=
    let fun narrow width offset bits=if width=1 then offset else
          let val half=width div 2 val upper=W.>>(bits,Word.fromInt half)
          in if upper=0w0 then narrow half offset bits else narrow half(offset+half)upper end
    in if value=0w0 then raise Fail "zero bit index"else narrow 64 0 value end
end
