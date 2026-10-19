functor ParaTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string end)=struct
 structure D=P.D
 val policy=P.policy

 structure K=BenchParaFn(D)
 structure Driver=BenchParaDriverFn(K)
 fun label s="para/"^policy^"/"^s
 val base=""
 fun read name=Driver.read(base^name)
 fun output text=K.formatText(K.chars text)
 fun check(index,status)=T.check(label("source-case-"^index),fn()=>
   let val input=read("cases/"^index^".input")
       val expected=read("cases/"^index^".stdout")
   in if status then Driver.consume expected(output input)=String.size expected
      else((BenchStream.foldl(fn(_,n)=>n+1)0(output input);false)handle _=>true)end)
 val _=List.app check [("0",true),("1",false),("2",false),("3",true),("4",true),("5",true),("6",true),("7",true),("8",true),("9",true),("10",false),("11",true),("12",true),("13",true),("14",true),("15",true),("16",true),("17",true),("18",true),("19",true),("20",true),("21",true),("22",true),("23",true),("24",true),("25",true),("26",true),("27",true),("28",true),("29",true),("30",true),("31",true),("32",true),("33",true),("34",true),("35",true),("36",true),("37",true),("38",true),("39",true),("40",true)]
 val _=T.check(label"smoke-complete-bytes",fn()=>
   Driver.consume(read"small.reference")(output(read"small.input"))=String.size(read"small.reference"))
 val _=T.check(label"source-suboptimal-counterexample",fn()=>
   Driver.consume(read"anomaly-observer.reference")(output(read"anomaly.input"))=136)
 val _=T.check(label"changed-reference-is-rejected",fn()=>
   ((Driver.consume"wrong\n"(output"right");false)handle Fail _=>true))
 val _=T.check(label"short-reference-is-rejected",fn()=>
   ((Driver.consume""(output"word");false)handle Fail _=>true))
 val _=T.check(label"extra-reference-is-rejected",fn()=>
   ((Driver.consume"word\nextra"(output"word");false)handle Fail _=>true))
 val _=T.check(label"zero-iterations",fn()=>Driver.run["0",base^"small.input",base^"small.reference"]="0:0")
 fun list queue=
   let val(x,y)=queue
   in BenchStream.take 100 x@List.rev(BenchStream.take 100 y)end
 val _=List.app(fn n=>T.check(label("queue-rebalance-"^Int.toString n),fn()=>
   let val q=List.foldl(fn(i,q)=>K.consSym i q)(BenchStream.empty(),BenchStream.empty())
          (List.tabulate(n,fn i=>i))
       val wanted=List.rev(List.tabulate(n,fn i=>i))
       fun drain q []=K.nullSym q
         |drain q(x::xs)=K.headSym q=x andalso list q=x::xs andalso drain(K.tailSym q)xs
       fun trim q []=K.nullSym q
         |trim q xs=K.lastSym q=List.last xs andalso trim(K.initSym q)(List.take(xs,List.length xs-1))
   in list q=wanted andalso drain q wanted andalso trim q wanted end))[0,1,2,3,4,7,16,31]

end
structure NeedTests=ParaTestsFn(struct structure D=BenchNeed val policy="lazy"end)
structure StrictTests=ParaTestsFn(struct structure D=BenchStrict val policy="strict"end)

structure ParaDemandTests=struct
 structure K=BenchParaFn(BenchNeed)
 val _=T.check("para/demand/unused-candidate-fields",fn()=>
   let val unused=BenchNeed.delay(fn()=>raise Fail "unused candidate number")
       val p=K.P(unused,unused,K.number 0)
   in K.lengthTail p=0 end)
 val _=T.check("para/demand/symmetric-queue-skips-unused-tail",fn()=>
   let val rest=BenchLazy.delay(fn()=>raise Fail "unused queue tail")
       val xs=BenchStream.cons(BenchLazy.delay(fn()=>7),rest)
   in K.headSym(xs,BenchStream.empty())=7 end)
end
