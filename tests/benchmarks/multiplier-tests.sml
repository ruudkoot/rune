functor MultiplierTestsFn(P:sig val eagerBinary:bool val policy:string end)=struct
 structure K=BenchMultiplierFn(P)
 structure Driver=BenchMultiplierDriverFn(K)
 structure L=BenchLazy
 structure S=BenchStream
 val base=""
 fun label name="multiplier/"^P.policy^"/"^name
 fun read path=Driver.read(base^path)
 fun render xs=String.implode(rev(S.foldl(fn(c,cs)=>c::cs)[]xs))
 val _=List.app(fn(width,cycles)=>T.check(label("original and independent trace "^Int.toString width),fn()=>
   render(K.trace width cycles)="Binary multiplier circuit simulation\n"^
     read("cases/"^Int.toString width^"-"^Int.toString cycles^".trace")))
   [(1,16),(2,32),(4,32),(8,64),(32,16)]
 val _=List.app(fn(width,cycles)=>T.check(label("original ready count "^Int.toString width),fn()=>
   Int.toString(K.readyCount width cycles)^"\n"=
     read("cases/"^Int.toString width^"-"^Int.toString cycles^".count")))
   [(1,16),(2,32),(4,32),(8,64),(32,16)]
 fun bits values=S.fromList values
 val _=T.check(label "both-input AND truth table",fn()=>
   S.take 4(K.and2(bits[0,0,1,1])(bits[0,1,0,1]))=[0,0,0,1])
 val _=T.check(label "OR truth table",fn()=>
   S.take 4(K.or2(bits[0,0,1,1])(bits[0,1,0,1]))=[0,1,1,1])
 val _=T.check(label "XOR truth table",fn()=>
   S.take 4(K.xor(bits[0,0,1,1])(bits[0,1,0,1]))=[0,1,1,0])
 val _=T.check(label "inverter truth table",fn()=>S.take 2(K.inv(bits[0,1]))=[1,0])
 fun poison()=S.cons(L.delay(fn()=>raise Fail "bit forced"),K.zero)
 val _=T.check(label "source unary headstrict",fn()=>
   ((L.force(K.inv(poison()));false)handle Fail why=>why="bit forced"))
 val _=T.check(label "binary head policy",fn()=>
   let val signal=K.and2(poison())K.zero
   in if P.eagerBinary then((L.force signal;false)handle Fail why=>why="bit forced")
      else(case L.force signal of S.Cons _=>true|_=>false)end)
 val _=T.check(label "AND does not short circuit zero input",fn()=>
   ((S.head(K.and2 K.zero(poison()));false)handle Fail why=>why="bit forced"))
 val _=T.check(label "latch output precedes input",fn()=>S.head(K.latch(L.delay(fn()=>raise Fail "unneeded latch input")))=0)
 val _=T.check(label "word combinator tail keeps arguments delayed",fn()=>
   let val word=K.word21 2(fn _=>fn _=>K.zero)(L.delay(fn()=>raise Fail "word input"))(L.delay(fn()=>raise Fail "word input"))
   in S.head(S.head(S.tail word))=0 end)
 val _=T.check(label "wide gate length does not force signal constructors",fn()=>
   let val word=S.cons(L.delay(fn()=>raise Fail "signal constructor"),S.singleton K.zero)
   in S.head(K.wideGate(fn _=>fn _=>K.zero)word)=0 end)
 val _=T.check(label "zero-width adder leaves operands unused",fn()=>
   let val(carry,sum)=K.add 0(L.delay(fn()=>raise Fail "left"))(L.delay(fn()=>raise Fail "right"))K.one
   in S.head carry=1 andalso null(S.take 1 sum)end)
 val _=T.check(label "signed 64-bit conversion wraps",fn()=>
   K.signed(K.bitsi(S.fromList(List.tabulate(64,fn _=>1))))="-1")
 val _=T.check(label "trace consumer",fn()=>Driver.run["32","16",base^"smoke-short.trace"]="32 16 1093")
 val _=T.check(label "count consumer",fn()=>Driver.runCount["32","16",base^"cases/32-16.count"]="32 16 3")
 val _=T.check(label "incorrect trace rejected",fn()=>
   ((Driver.consume "wrong"(K.trace 4 2);false)handle Fail why=>String.isPrefix "incorrect result:"why))
 val _=T.check(label "incorrect count rejected",fn()=>
   ((Driver.runCount["32","16",base^"cases/4-32.count"];false)handle Fail why=>String.isPrefix "incorrect result:"why))
 val _=T.check(label "ready-only consumer leaves product undemanded",fn()=>
   let val(_,_,ready,_,_,product)=K.multsys 4(K.inputs 1)
       val count=S.foldl(fn(bit,total)=>bit+total)0(K.take 32 ready)
   in count=8 andalso(case !product of L.Pending _=>true|_=>false)end)
 val _=T.check(label "memoized wire head",fn()=>
   let val calls=ref 0
       val wire=S.cons(L.delay(fn()=>(calls:= !calls+1;1)),K.zero)
   in S.head wire=1 andalso S.head wire=1 andalso !calls=1 end)
end
structure LazyMultiplierTests=MultiplierTestsFn(struct val eagerBinary=false val policy="lazy"end)
structure StrictMultiplierTests=MultiplierTestsFn(struct val eagerBinary=true val policy="strict"end)
