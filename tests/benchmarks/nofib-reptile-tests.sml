functor NofibReptileProtocolTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchReptileFn(D)
 fun one(profile,name)=
   let val root="tests/benchmarks/data/nofib-reptile/"
       val actual=K.string(K.program(K.input(BenchApplicationTestIO.read(root^"inputs/"^name))))
       val expected=BenchApplicationTestIO.read(root^"profiles/"^profile^".protocol")
   in BenchApplicationTestIO.compare("nofib-reptile/"^label^"/"^profile^"/protocol",expected,actual)end

 val _=List.app one[("smoke","reptile.faststdin"),("normal","reptile.stdin"),("large","reptile.slowstdin")]
end
structure NeedReptile=NofibReptileProtocolTestsFn(structure D=BenchNeed val label="need")
structure StrictReptile=NofibReptileProtocolTestsFn(structure D=BenchStrict val label="strict")

functor NofibReptileStateTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchReptileFn(D)
 structure L=BenchLazy
 fun array values="["^String.concatWith","values^"]"
 fun sequence f values=
   let fun loop values=case D.force values of K.F.Nil=>[]
         |K.F.Cons(value,rest)=>f value::loop rest
   in array(loop values)end
 fun ints values=sequence K.number values
 fun drawing value=let val(a,b)=D.force value in array[ints a,ints b]end
 fun key value=let val(a,b)=D.force value in array[K.number a,K.number b]end
 fun association value=let val(k,v)=D.force value in array[key k,K.number v]end
 fun state value=let val(d,s,t)=L.force value in array[sequence drawing d,K.number s,sequence association t]end
 fun one(profile,name)=
   let val root="tests/benchmarks/data/nofib-reptile/"
       val input=K.input(BenchApplicationTestIO.read(root^"inputs/"^name))
       fun loop current input=if K.tilequit current input then[]
         else let val(output,next,rest)=L.force(K.tiletrans current input)
              in array[K.signedHash(K.hash output),state next]::loop next rest end
       val actual=array(loop K.initialState input)^"\n"
       val expected=BenchApplicationTestIO.read(root^"states/"^profile^".reference")
   in BenchApplicationTestIO.compare("nofib-reptile/"^label^"/"^profile^"/state",expected,actual)end

 val _=List.app one[("smoke","reptile.faststdin"),("normal","reptile.stdin"),("large","reptile.slowstdin")]
end
structure NeedStates=NofibReptileStateTestsFn(structure D=BenchNeed val label="need")
structure StrictStates=NofibReptileStateTestsFn(structure D=BenchStrict val label="strict")

functor ComponentsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchReptileFn(D)
 fun bytes value=String.concatWith","(List.map(fn c=>Int.toString(Char.ord c))(K.F.toList value))^"\n"
 fun check(name,value)=
   let val actual=bytes value val expected=BenchApplicationTestIO.read("tests/benchmarks/data/nofib-reptile/components/"^name^".reference")
   in BenchApplicationTestIO.compare("nofib-reptile/"^label^"/component/"^name,expected,actual)end

 val _=List.app check [("dpgrid",K.dpgrid),("tpgrid",K.tpgrid),("tmgrid",K.tmgrid),("dmgrid",K.dmgrid),("picgrid",K.picgrid),("setup",K.setup),("todesign",K.todesign),("totile",K.totile),("tofiddle",K.tofiddle),("tohelp",K.tohelp),("invisibletext",K.invisibletext),("line",K.line(K.ints[1,~2,30,40])),("setevent",K.setevent(K.int 3)(K.text"abc\n")),("fillrect",K.fillrect(K.ints[1,2,3,4])),("tile",K.tile(K.int 10)(K.int 20)(K.int 2)(K.int 2)(K.singleton(K.ints[0,0,1,1])))]
 val a=K.pair(K.int 1)(K.int 3)val b=K.pair(K.int 2)(K.int 7)
 val values=[K.radd a b,K.rsub a b,K.rmul a b,K.rdiv a b]
 val expected=[("13","21"),("1","21"),("2","21"),("7","6")]
 val _=ListPair.appEq(fn(value,(x,y))=>
   let val(a,b)=D.force value in T.check("nofib-reptile/"^label^"/rational/"^x^"/"^y,fn()=>K.number a=x andalso K.number b=y)end)(values,expected)
end
structure NeedComponents=ComponentsFn(structure D=BenchNeed val label="need")
structure StrictComponents=ComponentsFn(structure D=BenchStrict val label="strict")
