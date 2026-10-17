functor EventTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string val strict:bool end)=struct
 structure K=BenchEventFn(P.D)
 structure Driver=BenchEventDriverFn(K)
 structure L=BenchLazy
 structure S=BenchStream
 val base=""
 fun label name="event/"^P.policy^"/"^name
 fun read path=Driver.read(base^path)
 fun trace finish=String.concat(rev(S.foldl(fn(e,rows)=>
   (Int.toString(K.time e)^" "^Int.toString(K.wire e)^" "^String.str(K.show(K.what e))^"\n")::rows)[]
   (K.simulate K.initialEvents K.initialState finish)))
 val _=List.app(fn finish=>T.check(label("original and independent state "^Int.toString finish),fn()=>
   K.benchmark finish=read("cases/"^Int.toString finish^".state")))
   [0,1,3,25,26,28,29,50,51,100,200,1000]
 val _=List.app(fn finish=>T.check(label("original and independent event sequence "^Int.toString finish),fn()=>
   trace finish=read("cases/"^Int.toString finish^".trace")))
   [0,1,3,25,26,28,29,50,51,100,200,1000]
 fun join []=""|join[x]=Int.toString x|join(x::xs)=Int.toString x^" "^join xs
 val _=T.check(label "original dependency construction",fn()=>
   String.concat(List.tabulate(13,fn i=>join(K.F.toList(K.dependencies i))^"\n"))=read"cases/dependencies.txt")
 val _=T.check(label "NAND three-state truth table",fn()=>
   let val values=[K.X,K.Low,K.High]
   in List.concat(List.map(fn a=>List.map(fn b=>K.nand(L.delay(fn()=>a))(L.delay(fn()=>b)))values)values)=
     [K.X,K.High,K.X,K.High,K.High,K.High,K.X,K.High,K.Low]end)
 val _=T.check(label "low NAND input avoids unused right",fn()=>
   K.nand(L.delay(fn()=>K.Low))(L.delay(fn()=>raise Fail "unused right"))=K.High)
 val _=T.check(label "end-time cutoff precedes wire and state demand",fn()=>
   let val e=K.At(L.delay(fn()=>10),L.delay(fn()=>raise Fail "unused wire"),L.delay(fn()=>raise Fail "unused value"))
   in null(S.take 1(K.simulate(S.singleton e)(L.delay(fn()=>raise Fail "unused state"))10))end)
 val _=T.check(label "stable pending-event tie ordering",fn()=>
   let val left=S.fromList[K.at 1 0 K.Low,K.at 3 1 K.High]
       val right=S.fromList[K.at 1 2 K.High,K.at 3 3 K.Low]
   in List.map K.wire(S.take 4(K.merge K.compareEvents left right))=[0,2,1,3]end)
 val _=T.check(label "persistent state update",fn()=>
   let val old=K.initialState val next=K.update old 1(L.delay(fn()=>K.High))
   in K.stateAt old 1=K.X andalso K.stateAt next 1=K.High andalso K.stateAt next 0=K.X end)
 val _=T.check(label "finite-state evaluation policy",fn()=>
   let val first=K.update K.initialState 0(L.delay(fn()=>raise Fail "overwritten value"))
       val second=K.update first 0(L.delay(fn()=>K.High))
   in if P.strict then((K.stateAt second 0;false)handle Fail why=>why="overwritten value")
      else K.stateAt second 0=K.High end)
 val _=T.check(label "no events leave initial state undemanded",fn()=>
   let val state=L.delay(fn()=>raise Fail "unused state")
   in K.findLastState(S.empty())state=state end)
 val _=T.check(label "source recalculate callback",fn()=>
   let fun f x y time wire state=K.at(time+x+y)wire K.High
       val event=K.recalculate(K.Fn(f,2,3))10 5 K.initialState
   in K.time event=15 andalso K.wire event=5 andalso K.what event=K.High end)
 val _=T.check(label "fresh state across cached clock runs",fn()=>
   K.benchmark 200=read"cases/200.state"andalso K.benchmark 1=read"cases/1.state")
 val _=T.check(label "consumer",fn()=>Driver.run["2","200",base^"cases/200.state"]="2 28 HHxLLHHLLHHLH")
 val _=T.check(label "wrong result rejected",fn()=>
   ((Driver.run["1","200",base^"cases/1.state"];false)handle Fail why=>String.isPrefix "incorrect result:"why))
end
structure LazyEventTests=EventTestsFn(struct structure D=BenchNeed val policy="lazy"val strict=false end)
structure StrictEventTests=EventTestsFn(struct structure D=BenchStrict val policy="strict"val strict=true end)
