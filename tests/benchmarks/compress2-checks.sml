structure Compress2Tests =
struct
 structure L=BenchCompress2Fn(BenchNeed)
 structure E=BenchCompress2Fn(BenchStrict)
 fun file path=let val input=BinIO.openIn path val data=BinIO.inputAll input in BinIO.closeIn input;Byte.bytesToString data end
 val input=file "smoke.input"
 fun digits n=if n<10 then "0"^Int.toString n else Int.toString n
 fun selected cut=String.substring(input,0,Int.max(0,String.size input-cut))
 val _=T.check("compress2/lazy-all31cut-fixtures",fn()=>List.all(fn cut=>L.compress(selected cut)=file("smoke-cuts/cut-"^digits cut^".bin"))(List.tabulate(31,fn i=>i)))
 val _=T.check("compress2/strict-dictionary-all31cut-fixtures",fn()=>List.all(fn cut=>E.compress(selected cut)=file("smoke-cuts/cut-"^digits cut^".bin"))(List.tabulate(31,fn i=>i)))
 val _=T.check("compress2/empty-source-tail-byte",fn()=>L.compress ""=String.implode[Char.chr 31,Char.chr 157,Char.chr 144,Char.chr 0]andalso L.compress ""=E.compress "")
 val _=T.check("compress2/width-marker-at513",fn()=>let val symbols=String.implode(List.tabulate(256,Char.chr)) val input=symbols^symbols in L.compress input=E.compress input end)
end
structure Compress2ControlTests =
struct
 structure C=BenchCompress2Fn(BenchNeed)
 structure B=BenchCompress2Bits
 structure S=B.S
 fun code stream=case S.head stream of B.Code n=>BenchNeed.force n | _=> ~1
 val _=T.check("compress2/width-marker-does-not-read-feedback",fn()=>
   case S.head(C.encode(3,1,10000,0,513,513)C.initial(BenchNeed.delay(fn()=>raise Fail "unused sizes"))"a"0)of B.NewWordSize=>true | _=>false)
 val _=T.check("compress2/full-dictionary-ratio-improves",fn()=>
   code(C.encode(1000,10000,10000,0,65537,0)C.initial(S.fromList[0,0,0])"a"0)=97)
 val _=T.check("compress2/clear-resets-to-initial-dictionary",fn()=>
   let val stream=C.encode(1000,10000,10000,2561,65537,0)C.initial(S.fromList[0,0,0])"a"0
   in case S.head stream of B.Clear=>code(S.tail stream)=97 | _=>false end)
end
structure Compress2SharingTests =
struct
 structure B=BenchCompress2Bits
 structure L=BenchCompress2Fn(BenchNeed)
 val _=T.check("compress2/code-payload-shared-by-writer-components",fn()=>
   let val calls=ref 0
       val payload=BenchNeed.delay(fn()=>(calls:= !calls+1;511))
       val output=B.outputCodes(B.S.fromList[B.Code payload])
       val _=B.S.toList(B.characters output)
       val _=B.S.toList(B.sizes output)
   in !calls=1 end)
 val _=T.check("compress2/eof-does-not-force-dictionary",fn()=>
   let val result=L.searchWrite ""0(BenchNeed.delay(fn()=>0))0 257(BenchNeed.delay(fn()=>raise Fail "unused trie"))
       val(index,code,count)=BenchNeed.force(L.dataOf result)
   in index=0 andalso BenchNeed.force code=0 andalso count=0 end)
end
