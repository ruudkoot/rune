structure PuzzleTests =
struct
  structure L=BenchPuzzleFn(BenchNeed)
  structure E=BenchPuzzleFn(BenchStrict)
  fun file path = let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input; text end
  val expected=file "minimum.expected"
  val histogramExpected=file "histogram.expected"
  fun histogram times =
    let val counts=Array.array(151,0)
        val _=List.app(fn t=>Array.update(counts,t,Array.sub(counts,t)+1))times
        fun fields n = if n=151 then [] else
          if Array.sub(counts,n)=0 then fields(n+1)
          else ("("^Int.toString n^","^Int.toString(Array.sub(counts,n))^")")::fields(n+1)
        fun join []="" | join [x]=x | join(x::xs)=x^","^join xs
    in "["^join(fields 0)^"]\n" end
  val _=T.check("puzzle/lazy-all-solution-times",fn()=>
    let val times=List.map L.totalTime(L.Q.toList(L.all()))
    in List.length times=21924 andalso histogram times=histogramExpected end)
  val _=T.check("puzzle/strict-all-solution-times",fn()=>
    let val times=List.map E.totalTime(E.Q.toList(E.all()))
    in List.length times=21924 andalso histogram times=histogramExpected end)
  val _=T.check("puzzle/ordered-minimal-histories-and-rendering",fn()=>
    L.text(L.result())=expected andalso E.text(E.result())=expected andalso
    List.map L.totalTime(L.Q.toList(L.minimum(L.all())))=[17,17])
  val _=T.check("puzzle/reject-perturbed-output",fn()=>
    ((L.checked("X"^String.extract(expected,1,NONE));false)handle Fail _=>true))
  val _=T.check("puzzle/reject-missing-output",fn()=>
    ((E.checked(String.substring(expected,0,String.size expected-1));false)handle Fail _=>true))
  val _=T.check("puzzle/reject-extra-output",fn()=>
    ((L.checked(expected^"extra");false)handle Fail _=>true))
  val _=T.check("puzzle/empty-solutions",fn()=>
    L.text(L.showSolutions(L.Q.empty())1)="" andalso E.text(E.showSolutions(E.Q.empty())1)="")
  val _=T.check("puzzle/not-seen-ignores-time-and-later-history",fn()=>
    let val badTime=BenchNeed.delay(fn()=>raise Fail "unused time")
        val badTail=BenchNeed.delay(fn()=>raise Fail "unused history")
        val history=L.Q.cons(L.value(badTime,L.initial))badTail
    in not(L.notSeen L.initial history) end)
  val _=T.check("puzzle/base-history-defers-time-and-tail",fn()=>
    let val badTime=BenchNeed.delay(fn()=>raise Fail "unused time")
        val badTail=BenchNeed.delay(fn()=>raise Fail "unused history")
        val paths=L.transfer L.initial L.initial L.LeftBank badTime badTail
        val (_,state)=L.Q.head(L.Q.head paths)
    in state=L.initial end)
  val _=T.check("puzzle/minimum-scans-complete-input",fn()=>
    let val h=L.Q.cons(L.value(L.value 1,L.initial))(L.Q.empty())
        val bad=BenchNeed.delay(fn()=>raise Fail "unscanned solutions")
        val xs=L.Q.cons(L.value h)bad
    in ((BenchNeed.force(L.minimum xs);false)handle Fail _=>true) end)
  val _=T.check("puzzle/minimum-preserves-equal-order",fn()=>
    let fun history t s=L.Q.cons(L.value(L.value t,s))(L.Q.empty())
        val first=L.update L.initial L.Bono L.RightBank
        val second=L.update L.initial L.Edge L.RightBank
        val xs=L.Q.fromList[history 3 L.final,history 2 first,history 2 second,history 4 L.initial]
        val states=List.map(fn h=> #2(L.Q.head h))(L.Q.toList(L.minimum xs))
    in states=[first,second] end)
  val _=T.check("puzzle/shared-countdown",fn()=>
    let val calls=ref 0 val time=BenchNeed.delay(fn()=>(calls:= !calls+1;17))
        val paths=L.transfer L.initial L.initial L.LeftBank time (L.Q.empty())
        val h=L.Q.head paths val first=L.totalTime h val second=L.totalTime h
    in first=17 andalso second=17 andalso !calls=1 end)
end
