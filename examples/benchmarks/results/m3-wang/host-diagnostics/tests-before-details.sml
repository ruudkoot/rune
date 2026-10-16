structure NeedWang = BenchWangFn (BenchNeed)
structure StrictWang = BenchWangFn (BenchStrict)
structure NeedDriver = BenchWangDriverFn (NeedWang)
structure StrictDriver = BenchWangDriverFn (StrictWang)
structure WangTests =
struct
  structure N = NeedWang
  structure R = StrictWang
  fun read path = let val f=TextIO.openIn path val raw=TextIO.inputAll f val _=TextIO.closeIn f in raw end
  fun number s = case Real.fromString s of SOME v=>v | NONE=>raise Fail "invalid reference number"
  fun reference path = List.map number (String.tokens Char.isSpace (read path))
  fun close (a,b) = Real.isFinite a andalso Real.isFinite b andalso Real.abs(a-b)<=1.0E~12*(1.0+Real.abs b)
  fun agrees ([],[]) = true | agrees (a::xs,b::ys) = close(a,b) andalso agrees(xs,ys) | agrees _ = false
  fun split n xs = if n=0 then ([],xs) else case xs of []=>raise Fail "short matrix input" | x::xs=> let val(first,rest)=split(n-1)xs in (x::first,rest)end
  fun rowsLazy [] = N.empty ()
    | rowsLazy(x::xs) = N.cons (x,rowsLazy xs)
  fun numbersLazy xs = case BenchNeed.force xs of N.Nil=>[] | N.Cons(x,xs)=>BenchNeed.force x::numbersLazy xs
  fun outputLazy xs = case BenchNeed.force xs of N.Nil=>[] | N.Cons(x,xs)=>numbersLazy(BenchNeed.force x)::outputLazy xs
  fun matrixLazy n input =
    let fun row [a,b,c,r] = N.row(a,b,c,r) | row _ = raise Fail "matrix tuple arity"
        val rows=List.map(row o List.map number o String.tokens Char.isSpace)(String.tokens(fn c=>c= #"\n")(read input))
        fun blocks [] = N.empty () | blocks xs =
          let val(block,rest)=split(n+1)xs in N.cons(BenchNeed.delay(fn()=>rowsLazy block),blocks rest)end
    in blocks rows end
  fun uniformLazy n path =
    let val output=outputLazy(N.values n)
    in List.length output=n andalso List.all(fn row=>List.length row=n+1)output
       andalso agrees(List.concat output,reference path)end
  fun nonuniformLazy n =
    let val stem="nonuniform-"^Int.toString n
    in agrees(List.concat(outputLazy(N.solution(matrixLazy n (stem^".input")))),reference(stem^".values"))end
  fun rowsStrict [] = R.empty ()
    | rowsStrict(x::xs) = R.cons (x,rowsStrict xs)
  fun numbersStrict xs = case BenchStrict.force xs of R.Nil=>[] | R.Cons(x,xs)=>BenchStrict.force x::numbersStrict xs
  fun outputStrict xs = case BenchStrict.force xs of R.Nil=>[] | R.Cons(x,xs)=>numbersStrict(BenchStrict.force x)::outputStrict xs
  fun matrixStrict n input =
    let fun row [a,b,c,r] = R.row(a,b,c,r) | row _ = raise Fail "matrix tuple arity"
        val rows=List.map(row o List.map number o String.tokens Char.isSpace)(String.tokens(fn c=>c= #"\n")(read input))
        fun blocks [] = R.empty () | blocks xs =
          let val(block,rest)=split(n+1)xs in R.cons(BenchStrict.delay(fn()=>rowsStrict block),blocks rest)end
    in blocks rows end
  fun uniformStrict n path =
    let val output=outputStrict(R.values n)
    in List.length output=n andalso List.all(fn row=>List.length row=n+1)output
       andalso agrees(List.concat output,reference path)end
  fun nonuniformStrict n =
    let val stem="nonuniform-"^Int.toString n
    in agrees(List.concat(outputStrict(R.solution(matrixStrict n (stem^".input")))),reference(stem^".values"))end
  val _=T.check("wang/lazy-smoke-full-values",fn()=>uniformLazy 25 "smoke.values")
  val _=T.check("wang/lazy-smoke-source-checksum",fn()=>N.run 25="66805/1375")
  val _=T.check("wang/lazy-smoke-repeat-output",fn()=>NeedDriver.run["25","2"]="2:66805/1375:22")
  val _=T.check("wang/strict-smoke-full-values",fn()=>uniformStrict 25 "smoke.values")
  val _=T.check("wang/strict-smoke-source-checksum",fn()=>R.run 25="66805/1375")
  val _=T.check("wang/strict-smoke-repeat-output",fn()=>StrictDriver.run["25","2"]="2:66805/1375:22")
  val _=T.check("wang/lazy-normal-full-values",fn()=>uniformLazy 80 "normal.values")
  val _=T.check("wang/lazy-normal-source-checksum",fn()=>N.run 80="631490/13200")
  val _=T.check("wang/lazy-normal-repeat-output",fn()=>NeedDriver.run["80","2"]="2:631490/13200:26")
  val _=T.check("wang/strict-normal-full-values",fn()=>uniformStrict 80 "normal.values")
  val _=T.check("wang/strict-normal-source-checksum",fn()=>R.run 80="631490/13200")
  val _=T.check("wang/strict-normal-repeat-output",fn()=>StrictDriver.run["80","2"]="2:631490/13200:26")
  val _=T.check("wang/lazy-large-full-values",fn()=>uniformLazy 150 "large.values")
  val _=T.check("wang/lazy-large-source-checksum",fn()=>N.run 150="2181430/45750")
  val _=T.check("wang/lazy-large-repeat-output",fn()=>NeedDriver.run["150","2"]="2:2181430/45750:28")
  val _=T.check("wang/strict-large-full-values",fn()=>uniformStrict 150 "large.values")
  val _=T.check("wang/strict-large-source-checksum",fn()=>R.run 150="2181430/45750")
  val _=T.check("wang/strict-large-repeat-output",fn()=>StrictDriver.run["150","2"]="2:2181430/45750:28")
  val _=T.check("wang/lazy-nonuniform-2-source-pairing-and-reciprocals",fn()=>nonuniformLazy 2)
  val _=T.check("wang/strict-nonuniform-2-source-pairing-and-reciprocals",fn()=>nonuniformStrict 2)
  val _=T.check("wang/lazy-nonuniform-3-source-pairing-and-reciprocals",fn()=>nonuniformLazy 3)
  val _=T.check("wang/strict-nonuniform-3-source-pairing-and-reciprocals",fn()=>nonuniformStrict 3)
  val _=T.check("wang/lazy-nonuniform-4-source-pairing-and-reciprocals",fn()=>nonuniformLazy 4)
  val _=T.check("wang/strict-nonuniform-4-source-pairing-and-reciprocals",fn()=>nonuniformStrict 4)
  val _=T.check("wang/lazy-nonuniform-5-source-pairing-and-reciprocals",fn()=>nonuniformLazy 5)
  val _=T.check("wang/strict-nonuniform-5-source-pairing-and-reciprocals",fn()=>nonuniformStrict 5)
  val _=T.check("wang/lazy-nonuniform-7-source-pairing-and-reciprocals",fn()=>nonuniformLazy 7)
  val _=T.check("wang/strict-nonuniform-7-source-pairing-and-reciprocals",fn()=>nonuniformStrict 7)
  val _=T.check("wang/source-el31-diagonal-over-residual",fn()=>agrees(numbersLazy(N.el31(rowsLazy[N.row(0.0,6.0,2.0,5.0)])(N.row(0.0,2.0,0.0,3.0))),[3.0,1.5]))
  val _=T.check("wang/source-el3-diagonal-over-residual",fn()=>agrees(numbersLazy(N.el3(N.row(0.0,2.0,0.0,4.0),rowsLazy[N.row(1.0,6.0,2.0,8.0)],N.row(0.0,4.0,0.0,6.0))),[2.0,1.5]))
  val _=T.check("wang/memoized-elimination-factor",fn()=>
    let val count=ref 0 val x=BenchNeed.delay(fn()=>(N.real 0.0,BenchNeed.delay(fn()=>(count:= !count+1;3.0)),N.real 2.0,N.real 5.0))
        val changed=N.head(N.tail(N.el21(rowsLazy[x,N.row(2.0,3.0,2.0,7.0)])))
        val _=N.b changed val _=N.rhs changed val _=N.b changed
    in !count=1 end)
  val _=T.check("wang/unused-right-hand-side",fn()=>
    let val x=BenchNeed.delay(fn()=>(N.real 0.0,N.real 3.0,N.real 2.0,BenchNeed.delay(fn()=>raise Fail "unused RHS")))
    in Real.==(N.b(N.head(N.el21(rowsLazy[x]))),3.0)end)
  val _=T.check("wang/inside-bound",fn()=>(N.checkValue(1.0+0.5E~10);true))
  val _=T.check("wang/reject-outside-bound",fn()=>((N.checkValue(1.0+2.0E~10);false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("wang/reject-wrong-zero",fn()=>((N.checkValue(0.0);false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("wang/reject-nan",fn()=>((N.checkValue(0.0/0.0);false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("wang/reject-infinity",fn()=>((N.checkValue(1.0/0.0);false)handle Fail s=>String.isPrefix "incorrect result:" s))
end
