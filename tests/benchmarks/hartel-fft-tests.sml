structure NeedFft=BenchHartelFftFn(BenchNeed)
structure StrictFft=BenchHartelFftFn(BenchStrict)
structure NeedDriver=BenchHartelFftDriverFn(NeedFft)
structure StrictDriver=BenchHartelFftDriverFn(StrictFft)
structure FftTests =
struct
  structure N=NeedFft
  structure R=StrictFft
  fun number s=case Real.fromString s of SOME x=>x|NONE=>raise Fail "invalid real"
  fun reference profile=
    let val f=TextIO.openIn(profile^".values") val raw=TextIO.inputAll f val _=TextIO.closeIn f
        fun scan([],_,iaa,rll)=(List.rev iaa,List.rev rll)
          |scan(line::rest,section,iaa,rll)=case String.tokens Char.isSpace line of
             ["INPUT"]=>scan(rest,0,iaa,rll)|["IAA"]=>scan(rest,1,iaa,rll)|["RLL"]=>scan(rest,2,iaa,rll)
            |[a,b]=>let val value=(number a,number b)in
               if section=1 then scan(rest,section,value::iaa,rll)
               else if section=2 then scan(rest,section,iaa,value::rll)
               else scan(rest,section,iaa,rll)end
            |_=>raise Fail "invalid reference line"
    in scan(String.tokens(fn c=>c= #"\n")raw,0,[],[])end
  fun close((a,b),(c,d))=Real.isFinite a andalso Real.isFinite b
    andalso Real.abs(a-c)<=2.0E~7+2.0E~12*Real.abs c
    andalso Real.abs(b-d)<=2.0E~7+2.0E~12*Real.abs d
  fun agrees([],[])=true|agrees(a::xs,b::ys)=close(a,b)andalso agrees(xs,ys)|agrees _=false
  fun needValues xs=case BenchNeed.force xs of N.Nil=>[]|N.Cons(x,xs)=>BenchNeed.force x::needValues xs
  fun strictValues xs=case BenchStrict.force xs of R.Nil=>[]|R.Cons(x,xs)=>BenchStrict.force x::strictValues xs
  fun multiply((a:real,b:real),(c,d))=(a*c-b*d,a*d+b*c)
  fun add((a:real,b:real),(c,d))=(a+c,b+d)
  fun custom n=List.tabulate(n,fn i=>(Real.fromInt((i*17)mod 29-14),Real.fromInt((i*13)mod 19-9)))
  fun dft input=
    let val n=List.length input
    in List.tabulate(n,fn k=>
      let fun sum([],_,acc)=acc|sum(x::xs,j,acc)=
        let val angle=2.0*Math.pi*Real.fromInt(k*j)/Real.fromInt n
        in sum(xs,j+1,add(acc,multiply(x,(Math.cos angle,Math.sin angle))))end
      in sum(input,0,(0.0,0.0))end)end
  val _=T.check("fft/lazy-smoke-arrayMain-source-values",fn()=>agrees(needValues(N.arrayMain(N.input 1)),#1(reference "smoke")))
  val _=T.check("fft/lazy-smoke-listMain-source-values",fn()=>agrees(needValues(N.listMain(N.input 1)),#2(reference "smoke")))
  val _=T.check("fft/lazy-smoke-analytic-and-status",fn()=>N.run 1(N.reference 1)="14976/128")
  val _=T.check("fft/lazy-smoke-repeat",fn()=>NeedDriver.run["1","2"]="2:14976/128:20")
  val _=T.check("fft/strict-smoke-arrayMain-source-values",fn()=>agrees(strictValues(R.arrayMain(R.input 1)),#1(reference "smoke")))
  val _=T.check("fft/strict-smoke-listMain-source-values",fn()=>agrees(strictValues(R.listMain(R.input 1)),#2(reference "smoke")))
  val _=T.check("fft/strict-smoke-analytic-and-status",fn()=>R.run 1(R.reference 1)="14976/128")
  val _=T.check("fft/strict-smoke-repeat",fn()=>StrictDriver.run["1","2"]="2:14976/128:20")
  val _=T.check("fft/lazy-normal-arrayMain-source-values",fn()=>agrees(needValues(N.arrayMain(N.input 3)),#1(reference "normal")))
  val _=T.check("fft/lazy-normal-listMain-source-values",fn()=>agrees(needValues(N.listMain(N.input 3)),#2(reference "normal")))
  val _=T.check("fft/lazy-normal-analytic-and-status",fn()=>N.run 3(N.reference 3)="59904/512")
  val _=T.check("fft/lazy-normal-repeat",fn()=>NeedDriver.run["3","2"]="2:59904/512:20")
  val _=T.check("fft/strict-normal-arrayMain-source-values",fn()=>agrees(strictValues(R.arrayMain(R.input 3)),#1(reference "normal")))
  val _=T.check("fft/strict-normal-listMain-source-values",fn()=>agrees(strictValues(R.listMain(R.input 3)),#2(reference "normal")))
  val _=T.check("fft/strict-normal-analytic-and-status",fn()=>R.run 3(R.reference 3)="59904/512")
  val _=T.check("fft/strict-normal-repeat",fn()=>StrictDriver.run["3","2"]="2:59904/512:20")
  val _=T.check("fft/lazy-large-arrayMain-source-values",fn()=>agrees(needValues(N.arrayMain(N.input 5)),#1(reference "large")))
  val _=T.check("fft/lazy-large-listMain-source-values",fn()=>agrees(needValues(N.listMain(N.input 5)),#2(reference "large")))
  val _=T.check("fft/lazy-large-analytic-and-status",fn()=>N.run 5(N.reference 5)="239616/2048")
  val _=T.check("fft/lazy-large-repeat",fn()=>NeedDriver.run["5","2"]="2:239616/2048:24")
  val _=T.check("fft/strict-large-arrayMain-source-values",fn()=>agrees(strictValues(R.arrayMain(R.input 5)),#1(reference "large")))
  val _=T.check("fft/strict-large-listMain-source-values",fn()=>agrees(strictValues(R.listMain(R.input 5)),#2(reference "large")))
  val _=T.check("fft/strict-large-analytic-and-status",fn()=>R.run 5(R.reference 5)="239616/2048")
  val _=T.check("fft/strict-large-repeat",fn()=>StrictDriver.run["5","2"]="2:239616/2048:24")
  val _=T.check("fft/lazy-nonuniform-8-arrayMain-direct-dft",fn()=>let val input=custom 8 in agrees(needValues(N.arrayMain(N.fromList input)),dft input)end)
  val _=T.check("fft/lazy-nonuniform-8-listMain-direct-dft",fn()=>let val input=custom 8 in agrees(needValues(N.listMain(N.fromList input)),dft input)end)
  val _=T.check("fft/strict-nonuniform-8-arrayMain-direct-dft",fn()=>let val input=custom 8 in agrees(strictValues(R.arrayMain(R.fromList input)),dft input)end)
  val _=T.check("fft/strict-nonuniform-8-listMain-direct-dft",fn()=>let val input=custom 8 in agrees(strictValues(R.listMain(R.fromList input)),dft input)end)
  val _=T.check("fft/lazy-nonuniform-16-arrayMain-direct-dft",fn()=>let val input=custom 16 in agrees(needValues(N.arrayMain(N.fromList input)),dft input)end)
  val _=T.check("fft/lazy-nonuniform-16-listMain-direct-dft",fn()=>let val input=custom 16 in agrees(needValues(N.listMain(N.fromList input)),dft input)end)
  val _=T.check("fft/strict-nonuniform-16-arrayMain-direct-dft",fn()=>let val input=custom 16 in agrees(strictValues(R.arrayMain(R.fromList input)),dft input)end)
  val _=T.check("fft/strict-nonuniform-16-listMain-direct-dft",fn()=>let val input=custom 16 in agrees(strictValues(R.listMain(R.fromList input)),dft input)end)
  val _=T.check("fft/lazy-nonuniform-32-arrayMain-direct-dft",fn()=>let val input=custom 32 in agrees(needValues(N.arrayMain(N.fromList input)),dft input)end)
  val _=T.check("fft/lazy-nonuniform-32-listMain-direct-dft",fn()=>let val input=custom 32 in agrees(needValues(N.listMain(N.fromList input)),dft input)end)
  val _=T.check("fft/strict-nonuniform-32-arrayMain-direct-dft",fn()=>let val input=custom 32 in agrees(strictValues(R.arrayMain(R.fromList input)),dft input)end)
  val _=T.check("fft/strict-nonuniform-32-listMain-direct-dft",fn()=>let val input=custom 32 in agrees(strictValues(R.listMain(R.fromList input)),dft input)end)
  val _=T.check("fft/source-comparison-half-inclusive",fn()=>N.sourceCompare((0.0,0.0),(0.5,~0.5)))
  val _=T.check("fft/source-comparison-half-exceeded",fn()=>not(N.sourceCompare((0.0,0.0),(0.5000001,0.0))))
  val _=T.check("fft/strong-check-rejects-legacy-tolerance-perturbation",fn()=>
    N.sourceCompare((0.0,0.0),(0.1,0.0))andalso((N.checkValue((0.1,0.0),(0.0,0.0));false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("fft/inside-bound",fn()=>(N.checkValue((0.5E~7,~0.5E~7),(0.0,0.0));true))
  val _=T.check("fft/reject-outside-bound",fn()=>((N.checkValue((2.0E~7,0.0),(0.0,0.0));false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("fft/reject-nan",fn()=>((N.checkValue((0.0/0.0,0.0),(0.0,0.0));false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("fft/reject-infinity",fn()=>((N.checkValue((1.0/0.0,0.0),(0.0,0.0));false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("fft/input-copies-share-complex-cell",fn()=>
    let val input=N.input 1 fun nth xs 0=(case BenchNeed.force xs of N.Cons(x,_)=>x|_=>raise Empty)
          |nth xs n=(case BenchNeed.force xs of N.Cons(_,rest)=>nth rest(n-1)|_=>raise Empty)
    in nth input 0=nth input 64 end)
  val _=T.check("fft/numerical-input-head-is-memoized",fn()=>
    let val count=ref 0 val value=BenchNeed.delay(fn()=>(count:= !count+1;(3.0,4.0)))
        val source=BenchNeed.delay(fn()=>N.Cons(value,N.empty()))
        val _=needValues(N.arrayMain source) val _=needValues(N.listMain source)
    in !count=1 end)
end
