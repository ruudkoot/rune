structure CompLabPilot=struct
 structure N=BenchCompLabFn(BenchNeed)
 structure E=BenchCompLabFn(BenchStrict)
 fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
 fun write file text=let val f=TextIO.openOut file in TextIO.output(f,text);TextIO.closeOut f end
 fun test selector size threshold mode=
  let val key=Int.toString selector^"-"^Int.toString size^"-"^Int.toString threshold^"-"^(if mode then"zift"else"plain")
      val wanted=read("cases/"^key^".reference")
      val need=N.rendered mode selector size threshold
      val strict=E.rendered mode selector size threshold
      val _=write("need-"^key^".output")need
      val _=write("strict-"^key^".output")strict
      val _=if need=wanted then print("PASS need "^key^" "^N.sumcode need^"\n")else raise Fail("need "^key)
      val _=if strict=wanted then print("PASS strict "^key^" "^E.sumcode strict^"\n")else raise Fail("strict "^key)
  in TextIO.flushOut TextIO.stdOut end
 val _=List.app(fn selector=>List.app(fn t=>List.app(fn mode=>test selector 1 t mode)[true,false])[0,1,10000])[0,1,2,3,4]
 val _=List.app(fn size=>List.app(fn t=>List.app(fn mode=>test 3 size t mode)[true,false])[0,size*256])[2,3,5,9]
end
