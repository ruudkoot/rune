(* Graph500's finite nonnegative-label edge-array OCaml Marshal subset, in SML97.
   Format constants/header description: OCaml 4.14.1 caml/intext.h,
   Copyright 1996 INRIA; LGPL 2.1 with the OCaml linking exception.
   This is not a general OCaml object serializer. Original notices are retained. *)
structure BenchGraphMarshal =
struct
  structure W=Word64
  type edge=int*int*real
  val magic:W.word=0wx8495a6be
  fun intLength n=if n<0 then raise Fail "negative graph vertex"
    else if n<64 then 1 else if n<128 then 2 else if n<32768 then 3 else 5
  fun headerLength n=if n<8 then 1
    else if W.<(W.<<(W.fromInt n,0w10),0wx100000000)then 5 else 9
  fun write path(edges:edge array)=
    let val n=Array.length edges
        val bodyLength=Array.foldl(fn((a,b,_),size)=>size+1+intLength a+intLength b+9)
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
           Word8Vector.app(fn b=>byte(Word8.toInt b))(PackReal64Little.toBytes w)))edges
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
          in if code=12 then PackReal64Little.fromBytes payload
             else if code=11 then PackReal64Big.fromBytes payload
             else raise Fail "unsupported graph Marshal real"end
        val edges=Array.tabulate(n,fn _=>
          let val(size,tag)=block()
              val _=if size=3 andalso tag=0 then()else raise Fail "wrong graph edge shape"
              val a=integer()val b=integer()val w=real()
          in(a,b,w)end)
        val _=if !position=Word8Vector.length bytes then()else raise Fail "trailing graph Marshal data"
    in edges end
end
