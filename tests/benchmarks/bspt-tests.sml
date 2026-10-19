functor BSPTTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string end)=struct
 structure App=BenchBSPTProgramFn(P.D)
 structure Tree=App.T
 structure G=Tree.G
 structure R=G.R
 structure L=BenchLazy
 structure S=BenchStream
 structure Driver=BenchBSPTDriverFn(App)
 val base=""
 fun label text="bspt/"^P.policy^"/"^text
 fun read name=Driver.read(base^name)
 fun signed text=valOf(IntInf.fromString text)
 fun q(n,d)=R.node(R.integer(fn()=>n),R.integer(fn()=>d))
 fun num value=q(signed value,IntInf.fromInt 1)
 fun frac(n,d)=q(IntInf.fromInt n,IntInf.fromInt d)
 val operands=[(frac(1,2),frac(2,3)),(frac(1,1),frac(~4,7)),
    (frac(3,5),frac(2,1)),(frac(0,1),frac(7,9))]
 fun checkRational name value n d=T.check(label name,fn()=>R.numerator value=n andalso R.denominator value=d)
 fun outcome name=
   if name="overflow-add"then R.add(num"9223372036854775807")R.one
   else if name="overflow-mul"then R.mul(num"4611686018427387904")(R.number 4)
   else let val length=String.size name
            val index=Char.ord(String.sub(name,length-1))-Char.ord #"0"
            val(a,b)=List.nth(operands,index)
        in case String.substring(name,0,3)of "add"=>R.add a b|"mul"=>R.mul a b
          |"sub"=>R.sub a b|"div"=>R.divide a b|_=>raise Match end
 val _=List.app(fn line=>case String.tokens Char.isSpace line of[name,n,d]=>
    checkRational name(outcome name)(signed n)(signed d)
   |[name,n]=>T.check(label name,fn()=>
      R.round(case name of"round-pos"=>frac(3,2)|"round-neg"=>frac(~3,2)|_=>frac(1,3))=signed n)
   |["noncanonical",_,_,_,_]=>T.check(label"noncanonical-source-order",fn()=>
      let val a=frac(1,2)val b=frac(2,4)
      in not(R.equal a b)andalso R.lessEqual a b andalso R.less a b andalso not(R.greater a b)end)
   |_=>raise Fail "bad original rational record")
   (String.tokens(fn c=>c= #"\n")(read"rational.reference"))

 fun checkCase name=T.check(label("original-command-"^name),fn()=>
   let val input=read("cases/"^name^".input")val expected=read("cases/"^name^".output")
       val(n,h)=Driver.consume expected(App.prog input)
   in n=String.size expected andalso h=Driver.expectedHash expected end)
 val _=List.app checkCase["quit","polygon","area","classify","partition","render","complement",
   "union","intersection","subtract","null-before-quit"]
 val _=T.check(label"complete-original-batch",fn()=>
   Driver.run["1",base^"commands.txt",base^"batch.render"]="1 9761 2674C83CE2E76A07")
 val _=T.check(label"zero-repetitions",fn()=>
   Driver.run["0",base^"commands.txt",base^"batch.render"]="0 0 0")
 val _=T.check(label"corrupt-output-is-rejected",fn()=>
   ((Driver.consume"wrong"(App.prog"batch\n");false)handle Fail _=>true))
 val _=T.check(label"rational-zero-division",fn()=>
   ((L.force(R.divide R.one R.zero);false)handle Fail _=>true))
 val rect=Tree.build(G.mkPolygon(S.fromList[
    G.integerPoint(200,100),G.integerPoint(400,100),G.integerPoint(400,300),G.integerPoint(200,300)]))
 val _=T.check(label"rectangle-area",fn()=>
   let val a=Tree.area rect in R.numerator a=IntInf.fromInt 40000 andalso R.denominator a=IntInf.fromInt 1 end)
 val _=T.check(label"rectangle-inside",fn()=>Tree.classify(G.integerPoint(300,200))rect=Tree.In)
 val _=T.check(label"rectangle-outside",fn()=>Tree.classify(G.integerPoint(100,200))rect=Tree.Out)
 val _=T.check(label"rectangle-boundary",fn()=>Tree.classify(G.integerPoint(200,200))rect=Tree.On)
 val _=T.check(label"cached-area-is-not-forced-by-classification",fn()=>
   let val cell=L.delay(fn()=>Tree.Cell(Tree.Out,G.renderBorder,L.delay(fn()=>raise Fail "unused area")))
   in Tree.countLeaves cell=1 andalso Tree.classify(G.integerPoint(300,200))cell=Tree.Out end)
 val _=T.check(label"explicit-seq-left-is-preserved",fn()=>
   let val face=G.face(L.delay(fn()=>raise Fail "segment poison"))(G.line(R.one,R.zero,R.number ~200))
   in ((L.force(Tree.build(S.singleton face));false)handle Fail "segment poison"=>true|_=>false)end)
 val _=T.check(label"dummy-par-leaves-fore-tree-delayed",fn()=>
   let val equation=G.line(R.one,R.zero,R.number ~200)
       val first=G.face(L.delay(fn()=>(G.integerPoint(200,0),G.integerPoint(200,1))))equation
       val next=G.face(L.delay(fn()=>(G.integerPoint(300,0),G.integerPoint(300,1))))
         (L.delay(fn()=>raise Fail "unused fore line"))
   in case L.force(Tree.build(S.fromList[first,next]))of Tree.BSP _=>true|_=>false end)
end
structure NeedTests=BSPTTestsFn(struct structure D=BenchNeed val policy="lazy"end)
structure StrictTests=BSPTTestsFn(struct structure D=BenchStrict val policy="strict"end)
structure BSPTCacheTests=struct
 val calls=ref 0
 structure CountingNeed=struct
   type 'a t='a BenchNeed.t
   fun delay f=BenchNeed.delay(fn()=>(calls:= !calls+1;f()))
   val force=BenchNeed.force
 end
 structure App=BenchBSPTProgramFn(CountingNeed)
 structure Driver=BenchBSPTDriverFn(App)
 val _=T.check("bspt/sharing/batch-body-persists-across-calls",fn()=>
   let val expected=Driver.read"batch.render"
       val earlier= !calls
       val _=Driver.consume expected(App.prog"batch\n")
       val afterFirst= !calls
       val _=Driver.consume expected(App.prog"batch\n")
   in afterFirst>earlier andalso !calls=afterFirst end)
end
