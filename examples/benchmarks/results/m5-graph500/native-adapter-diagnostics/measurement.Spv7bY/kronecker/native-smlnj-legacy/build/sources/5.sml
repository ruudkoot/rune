(* Graph500's finite nonnegative-label edge-array OCaml Marshal subset, in SML97.
   Format constants/header description: OCaml 4.14.1 caml/intext.h,
   Copyright 1996 INRIA; LGPL 2.1 with the OCaml linking exception.
   This is not a general OCaml object serializer. Original notices are retained. *)
structure BenchGraphMarshal =
struct
  structure W=Word64
  type edge=int*int*real
  val magic:W.word=0wx8495a6be
  (* Optional PACK_REAL structure names are not common to all supported hosts.
     Use one SML97 finite-binary64 representation algorithm on every compiler. *)
  val fractionUnit=valOf(IntInf.fromString "4503599627370496")
  val signMask:W.word=0wx8000000000000000
  fun realBits x=
    if not(Real.isFinite x)then raise Fail "nonfinite graph weight"else
    let val sign=if Real.signBit x then signMask else(0w0:W.word)
        val magnitude=Real.abs x
    in if Real.==(magnitude,0.0)then sign else
       let val{man,exp}=Real.toManExp magnitude
           val biased=exp+1022
           val bits=if biased<=0 then W.fromLargeInt(Real.toLargeInt IEEEReal.TO_NEAREST
                 (Real.fromManExp{man=magnitude,exp=1074}))
             else let val significand=Real.toLargeInt IEEEReal.TO_NEAREST(man*9007199254740992.0)
                  in W.orb(W.<<(W.fromInt biased,0w52),W.fromLargeInt(IntInf.-(significand,fractionUnit)))end
       in W.orb(sign,bits)end end
  fun bitsReal bits=
    let val exponent=W.toInt(W.andb(W.>>(bits,0w52),0wx7ff))
        val fraction=W.toLargeInt(W.andb(bits,0wxfffffffffffff))
        val _=if exponent=2047 then raise Fail "nonfinite graph weight"else()
        val magnitude=if exponent=0 then
             Real.fromManExp{man=Real.fromLargeInt fraction,exp= ~1074}
           else Real.fromManExp{man=Real.fromLargeInt(IntInf.+(fractionUnit,fraction)),exp=exponent-1075}
    in if W.andb(bits,signMask)<>0w0 then ~magnitude else magnitude end
  fun realBytes x=
    let val bits=realBits x
    in Word8Vector.tabulate(8,fn i=>Word8.fromInt(W.toInt(W.andb(W.>>(bits,Word.fromInt(8*i)),0w255))))end
  fun bytesReal little bytes=
    let fun loop i acc=if i=8 then bitsReal acc else
          let val offset=if little then 7-i else i
              val b=W.fromInt(Word8.toInt(Word8Vector.sub(bytes,offset)))
          in loop(i+1)(W.orb(W.<<(acc,0w8),b))end
    in loop 0(0w0:W.word)end
  fun intLength n=if n<0 orelse n>2097151 then raise Fail "graph vertex outside selected domain"
    else if n<64 then 1 else if n<128 then 2 else if n<32768 then 3 else 5
  fun headerLength n=if n<8 then 1
    else if W.<(W.<<(W.fromInt n,0w10),0wx100000000)then 5 else 9
  fun write path(edges:edge array)=
    let val n=Array.length edges
        val bodyLength=Array.foldl(fn((a,b,w),size)=>if Real.isFinite w then size+1+intLength a+intLength b+9 else raise Fail "nonfinite graph weight")
          (headerLength n)edges
        val out=BinIO.openOut path
        val buffer=Word8Array.array(65536,0w0)
        val used=ref 0 val count=ref 0 val hash=ref(0w0:W.word)
        fun flush()=if !used=0 then()else
          (BinIO.output(out,Word8ArraySlice.vector(Word8ArraySlice.slice(buffer,0,SOME(!used))));used:=0)
        fun byte n=
          let val b=Word8.fromInt n
              val _=Word8Array.update(buffer,!used,b)
              val _=used:= !used+1 val _=count:= !count+1
              val _=hash:=W.+(W.*(!hash,0w31),W.fromInt n)
          in if !used=65536 then flush()else()end
        fun word bytes(value:W.word)=
          let fun loop shift=if shift<0 then()else
            (byte(W.toInt(W.andb(W.>>(value,Word.fromInt(shift*8)),0w255)));loop(shift-1))
          in loop(bytes-1)end
        fun integer n=if n<64 then byte(64+n)
          else if n<128 then(byte 0;byte n)
          else if n<32768 then(byte 1;word 2(W.fromInt n))
          else(byte 2;word 4(W.fromInt n))
        val _=word 4 magic
        val _=word 4(W.fromInt bodyLength)
        val _=word 4(W.fromInt(if n=0 then 0 else 2*n+1))
        val _=word 4(W.fromInt(if n=0 then 0 else 8*n+1))
        val _=word 4(W.fromInt(if n=0 then 0 else 7*n+1))
        val header=W.<<(W.fromInt n,0w10)
        val _=if n<8 then byte(128+16*n)
          else if W.<(header,0wx100000000)then(byte 8;word 4 header)
          else(byte 19;word 8 header)
        val _=Array.app(fn(a,b,w)=>
          (byte 176;integer a;integer b;byte 12;
           Word8Vector.app(fn b=>byte(Word8.toInt b))(realBytes w)))edges
        val _=flush()val _=BinIO.closeOut out
    in (!count,!hash)end
  fun read path=
    let val f=BinIO.openIn path val bytes=BinIO.inputAll f val _=BinIO.closeIn f
        val position=ref 0
        fun byte()=if !position<Word8Vector.length bytes then
          let val value=Word8.toInt(Word8Vector.sub(bytes,!position))
          in position:= !position+1;value end
          else raise Fail "short graph Marshal input"
        fun word n=
          let fun loop 0 acc=acc|loop n acc=loop(n-1)(W.+(W.<<(acc,0w8),W.fromInt(byte())))
          in loop n(0w0:W.word)end
        fun int value=W.toInt value
        val _=if word 4=magic then()else raise Fail "unsupported graph Marshal header"
        val bodyLength=int(word 4)val objects=int(word 4)
        val size32=int(word 4)val size64=int(word 4)
        val _=if bodyLength=Word8Vector.length bytes-20 then()else raise Fail "wrong graph Marshal byte length"
        fun block()=
          let val code=byte()
          in if code>=128 then((code div 16)mod 8,code mod 16)
             else if code=8 orelse code=19 then
               let val header=word(if code=8 then 4 else 8)
               in(int(W.>>(header,0w10)),int(W.andb(header,0w255)))end
             else raise Fail "unsupported graph Marshal block"end
        val(n,tag)=block()
        val _=if n<=(Word8Vector.length bytes- !position)div 12 then()else raise Fail "impossible graph edge count"
        val _=if tag=0 andalso objects=(if n=0 then 0 else 2*n+1)
            andalso size32=(if n=0 then 0 else 8*n+1)
            andalso size64=(if n=0 then 0 else 7*n+1)
          then()else raise Fail "wrong graph Marshal object counts"
        fun integer()=
          let val code=byte()
          in if code>=64 andalso code<128 then code-64
             else if code=0 then let val n=byte()in if n<128 then n else raise Fail "negative graph vertex"end
             else if code=1 then let val n=int(word 2)in if n<32768 then n else raise Fail "negative graph vertex"end
             else if code=2 then int(word 4)
             else raise Fail "unsupported graph Marshal integer"end
        fun real()=
          let val code=byte()
              val payload=Word8Vector.tabulate(8,fn _=>Word8.fromInt(byte()))
          in if code=12 then bytesReal true payload
             else if code=11 then bytesReal false payload
             else raise Fail "unsupported graph Marshal real"end
        val edges=Array.tabulate(n,fn _=>
          let val(size,tag)=block()
              val _=if size=3 andalso tag=0 then()else raise Fail "wrong graph edge shape"
              val a=integer()val b=integer()val w=real()
          in(a,b,w)end)
        val _=if !position=Word8Vector.length bytes then()else raise Fail "trailing graph Marshal data"
    in edges end
end
