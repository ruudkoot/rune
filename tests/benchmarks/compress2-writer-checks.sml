structure Compress2WriterTests =
struct
 structure B=BenchCompress2Bits
 fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f in TextIO.closeIn f;s end
 fun show xs="["^String.concatWith ","(List.map Int.toString xs)^"]"
 fun rendered events=let val r=B.outputCodes(B.S.fromList events) in "("^show(List.map Char.ord(B.S.toList(B.characters r)))^","^show(B.S.toList(B.sizes r))^")\n"end
 val _=T.check("compress2/writer-0",fn()=>rendered[]=read "writer-0.expected")
 val _=T.check("compress2/writer-1",fn()=>rendered[B.Code(B.value 65)]=read "writer-1.expected")
 val _=T.check("compress2/writer-2",fn()=>rendered[B.Code(B.value 0),B.Code(B.value 1),B.Code(B.value 2),B.Code(B.value 3),B.Code(B.value 4),B.Code(B.value 5),B.Code(B.value 6),B.Code(B.value 7)]=read "writer-2.expected")
 val _=T.check("compress2/writer-3",fn()=>rendered[B.Code(B.value 0),B.Code(B.value 1),B.Code(B.value 2),B.Code(B.value 3),B.Code(B.value 4),B.Code(B.value 5),B.Code(B.value 6),B.Code(B.value 7),B.Code(B.value 8),B.Code(B.value 9)]=read "writer-3.expected")
 val _=T.check("compress2/writer-4",fn()=>rendered[B.NewWordSize,B.Code(B.value 65)]=read "writer-4.expected")
 val _=T.check("compress2/writer-5",fn()=>rendered[B.Clear]=read "writer-5.expected")
 val _=T.check("compress2/writer-6",fn()=>rendered[B.Code(B.value 65),B.Code(B.value 66),B.Code(B.value 67),B.Code(B.value 68),B.Clear,B.Code(B.value 69)]=read "writer-6.expected")
 val _=T.check("compress2/writer-7",fn()=>rendered[B.NewWordSize,B.NewWordSize,B.NewWordSize,B.NewWordSize,B.NewWordSize,B.NewWordSize,B.NewWordSize,B.Code(B.value 65535)]=read "writer-7.expected")
 val _=T.check("compress2/size-does-not-force-code",fn()=>let val r=B.outputCodes(B.S.fromList[B.Code(B.N.delay(fn()=>raise Fail "unused"))]) in B.S.head(B.sizes r)=0 end)
end
