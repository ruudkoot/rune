functor BenchIdaFn(D:BENCH_SUSPEND)=
struct
  structure F=BenchIdaFiniteFn(D)
  structure L=BenchLazy
  structure S=BenchStream
  type pos=int*int
  type square=pos*pos
  type board=square F.seq*square F.seq
  datatype searchNode=Search of int L.delay*int L.delay*board L.delay*pos S.stream
  type search=searchNode L.delay
  datatype solutionNode=Solution of search*int L.delay
  type solution=solutionNode L.delay
  fun delay f=L.delay f
  fun ready x=L.delay(fn()=>x)
  fun manhattan(x,y)(u,v)=Int.abs(x-u)+Int.abs(y-v)
  fun splitFinite predicate values=delay(fn()=>case D.force values of
      F.Nil=>(F.empty(),F.empty())
    |F.Cons(x,rest)=>
       let val shared=splitFinite predicate rest
           val yes=F.defer(fn()=> #1(L.force shared))
           val no=F.defer(fn()=> #2(L.force shared))
       in if predicate(D.force x)then(F.cons(x,yes),no)else(yes,F.cons(x,no))end)
  fun select hole squares=splitFinite(fn(current,_)=>manhattan hole current=1)squares
  fun goal width height=
    let val positions=List.concat(List.tabulate(width,fn x=>List.tabulate(height,fn y=>(x+1,y+1))))
    in ((1,1),F.fromList(List.map(fn p=>(p,p))(tl positions)))end
  fun random seed=
    let fun loop x=L.delay(fn()=>let val next=Int.rem(4663*x,46199)+1
          in S.Cons(ready next,loop next)end)
    in loop(Int.abs seed)end
  fun reversedPrefix 0 acc stream=acc
    |reversedPrefix n acc stream=reversedPrefix(n-1)(S.head stream::acc)(S.tail stream)
  fun rotate 0 values=values
    |rotate n values=case D.force values of F.Nil=>F.empty()
      |F.Cons(x,rest)=>rotate(n-1)(F.append rest(F.cons(x,F.empty())))
  fun shuffle(hole,squares)count numbers=
    let fun loop hole board []=(hole,F.append(#1(L.force board))(#2(L.force board)))
          |loop hole board(n::ns)=
            let val(movable,fixed)=L.force board
                val choices=rotate(Int.rem(n,F.length movable))movable
            in case D.force choices of F.Nil=>raise Empty
              |F.Cons(square,rejected)=>
               let val(current,home)=D.force square
                   val next=F.cons(D.delay(fn()=>(hole,home)),F.append fixed rejected)
               in loop current(select current next)ns end end
    in loop hole(select hole squares)(reversedPrefix count[]numbers)end
  fun bound space=case L.force space of Search(b,_,_,_)=>L.force b
  fun depth space=case L.force space of Search(_,d,_,_)=>L.force d
  fun upper space= ~(bound space)
  fun singleton space=depth space=0
  fun board space=case L.force space of Search(_,_,b,_)=>b
  fun path space=case L.force space of Search(_,_,_,p)=>p
  fun movable space= #1(L.force(board space))
  fun choose first second=
    if upper first<>upper second then if upper first<upper second then second else first
    else if singleton first then first else second
  fun divide space=L.delay(fn()=>
    let val Search(b,d,board,history)=L.force space val(movables,fixed)=L.force board
    in case D.force movables of F.Nil=>S.Nil
      |F.Cons(square,rest)=>
       let val(current,home)=D.force square
           val delta=delay(fn()=>manhattan(S.head history)home-manhattan current home)
           val selected=select current(F.append rest fixed)
           val nextBoard=delay(fn()=>let val(m,f)=L.force selected
             in(m,F.cons(D.delay(fn()=>(S.head history,home)),f))end)
           val child=forcedCheck(delay(fn()=>Search(delay(fn()=>L.force b+1+L.force delta),
             delay(fn()=>L.force d+L.force delta),nextBoard,S.cons(ready current,history))))
           val others=delay(fn()=>Search(b,d,ready(rest,F.cons(square,fixed)),history))
       in S.Cons(ready child,divide others)end end)
  and forcedCheck space=delay(fn()=>L.force(
    if singleton space then space else
      case D.force(movable space)of F.Nil=>raise Empty
       |F.Cons(_,rest)=>case D.force rest of F.Nil=>S.head(divide space)|_=>space))
  fun solutionSpace sol=case L.force sol of Solution(space,_)=>space
  fun partitions sol=case L.force sol of Solution(_,count)=>L.force count
  fun collect first second=delay(fn()=>
    let val Solution(sp1,nr1)=L.force first val Solution(sp2,nr2)=L.force second
    in Solution(delay(fn()=>L.force(choose sp1 sp2)),delay(fn()=>L.force nr1+L.force nr2))end)
  fun split predicate values=
    let val shared=delay(fn()=>case L.force values of S.Nil=>(S.empty(),S.empty())
          |S.Cons(x,rest)=>let val(yes,no)=split predicate rest
            in if predicate(L.force x)then(S.cons(x,yes),no)else(yes,S.cons(x,no))end)
    in(delay(fn()=>L.force(#1(L.force shared))),delay(fn()=>L.force(#2(L.force shared))))end
  fun foldChoose initial values=
    let fun loop acc values=case L.force values of S.Nil=>acc
          |S.Cons(x,rest)=>loop(delay(fn()=>L.force(choose acc(L.force x))))rest
    in loop initial values end
  fun prune cutoff space=singleton space orelse upper space<cutoff
  fun parallelBranch cutoff spaces current=delay(fn()=>case L.force spaces of S.Nil=>L.force current
    |S.Cons(entry,rest)=>
      let val space=delay(fn()=>L.force(L.force entry))
          val optimum=delay(fn()=>L.force(solutionSpace current))
          val(pruned,unpruned)=split(prune cutoff)(divide space)
          val next=delay(fn()=>L.force(foldChoose optimum pruned))
      in case L.force rest of
          S.Cons _=>L.force(collect
            (parallelBranch cutoff(S.singleton space)(delay(fn()=>Solution(optimum,ready 0))))
            (parallelBranch cutoff rest current))
        |S.Nil=>if upper next=cutoff then Solution(next,delay(fn()=>partitions current))
          else L.force(parallelBranch cutoff unpruned(delay(fn()=>Solution(next,delay(fn()=>partitions current+1)))))end)
  fun branch delta cutoff spaces current=delay(fn()=>case L.force spaces of S.Nil=>L.force current
    |S.Cons(entry,rest)=>
      let val space=delay(fn()=>L.force(L.force entry)) val optimum=delay(fn()=>L.force(solutionSpace current))
      in if upper optimum=cutoff then L.force current
        else if singleton space orelse upper space<cutoff then
          L.force(branch delta cutoff rest(delay(fn()=>Solution(delay(fn()=>L.force(choose optimum space)),delay(fn()=>partitions current)))))
        else if upper space-cutoff>delta then
          L.force(branch delta cutoff(S.append(divide space)rest)(delay(fn()=>Solution(optimum,delay(fn()=>partitions current+1)))))
        else L.force(branch delta cutoff rest(parallelBranch cutoff(S.singleton space)current))end)
  fun optimize initial worst delta=
    let fun repeat current=delay(fn()=>if singleton(solutionSpace current)then L.force current
          else L.force(repeat(branch delta(upper(solutionSpace current))(S.singleton initial)
            (delay(fn()=>Solution(worst,delay(fn()=>partitions current)))))))
    in repeat(delay(fn()=>Solution(delay(fn()=>L.force(choose initial worst)),ready 0)))end
  fun solve(hole,squares)delta maxShift=
    let fun total values=D.delay(fn()=>case D.force values of F.Nil=>0
          |F.Cons(square,rest)=>let val(current,home)=D.force square
             in manhattan current home+D.force(total rest)end)
        val distance=delay(fn()=>D.force(total squares))
        val initial=forcedCheck(delay(fn()=>Search(distance,distance,select hole squares,S.singleton hole)))
        val worst=delay(fn()=>Search(ready maxShift,ready 0,ready(F.empty(),F.empty()),S.empty()))
    in optimize initial worst delta end
  fun showPos(x,y)="("^Int.toString x^","^Int.toString y^")"
  fun showSquare(current,home)="("^showPos current^"-"^showPos home^")"
  fun initial seed width height count=shuffle(goal width height)count(random seed)
  fun showConfiguration(hole,squares)=showPos hole^String.concat(List.map showSquare(F.toList squares))^"\n"
  fun compute width=let val configuration=initial 6 width 4 100
    in(configuration,solve configuration 7 101)end
  fun showResult(configuration,solution)=showConfiguration configuration^
    Int.toString(bound(solutionSpace solution))^" "^Int.toString(partitions solution)^"\n"
  fun validSolution((hole,squares),solution)=
    let val space=solutionSpace solution
        val reversePath=rev(S.foldl(fn(p,ps)=>p::ps)[](path space))
        val chronological=rev reversePath
        fun walk hole tiles []=List.all(fn(current,home)=>current=home)tiles
          |walk hole tiles(next::rest)=
            let fun move []=NONE
                  |move((current,home)::others)=if current=next then SOME((hole,home)::others)
                    else case move others of NONE=>NONE|SOME changed=>SOME((current,home)::changed)
            in manhattan hole next=1 andalso(case move tiles of
                NONE=>false|SOME changed=>walk next changed rest)end
    in depth space=0 andalso length chronological=bound space+1 andalso
       (case chronological of []=>false|start::rest=>start=hole andalso walk hole(F.toList squares)rest)end
  fun one width=showResult(compute width)
  fun calculate count width expected=
    let fun loop 0 bytes=Int.toString count^" "^Int.toString bytes
          |loop n bytes=let val result=compute width val text=showResult result
              val _=if text=expected andalso validSolution result then()
                    else raise Fail "incorrect result: puzzle configuration or solution"
            in loop(n-1)(bytes+String.size text)end
    in loop count 0 end
end
