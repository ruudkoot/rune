fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
functor ComponentsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchReptileFn(D)
 fun bytes value=String.concatWith","(List.map(fn c=>Int.toString(Char.ord c))(K.F.toList value))^"\n"
 fun check(name,value)=
   let val actual=bytes value val expected=read("tests/out/benchmarks/nofib-reptile-originals/component-data/"^name^".reference")
   in if actual=expected then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut("tests/out/benchmarks/nofib-reptile-originals/component-data/"^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("component "^name)end end
 val _=List.app check [("dpgrid",K.dpgrid),("tpgrid",K.tpgrid),("tmgrid",K.tmgrid),("dmgrid",K.dmgrid),("picgrid",K.picgrid),("setup",K.setup),("todesign",K.todesign),("totile",K.totile),("tofiddle",K.tofiddle),("tohelp",K.tohelp),("invisibletext",K.invisibletext),("line",K.line(K.ints[1,~2,30,40])),("setevent",K.setevent(K.int 3)(K.text"abc\n")),("fillrect",K.fillrect(K.ints[1,2,3,4])),("tile",K.tile(K.int 10)(K.int 20)(K.int 2)(K.int 2)(K.singleton(K.ints[0,0,1,1])))]
 val a=K.pair(K.int 1)(K.int 3)val b=K.pair(K.int 2)(K.int 7)
 val values=[K.radd a b,K.rsub a b,K.rmul a b,K.rdiv a b]
 val expected=[("13","21"),("1","21"),("2","21"),("7","6")]
 val _=ListPair.appEq(fn(value,(x,y))=>
   let val(a,b)=D.force value in if K.number a=x andalso K.number b=y then print("PASS "^label^" rational\n")else raise Fail"rational"end)(values,expected)
end
structure NeedComponents=ComponentsFn(structure D=BenchNeed val label="need")
structure StrictComponents=ComponentsFn(structure D=BenchStrict val label="strict")
