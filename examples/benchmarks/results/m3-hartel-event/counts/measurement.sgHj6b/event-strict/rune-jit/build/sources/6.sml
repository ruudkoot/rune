functor BenchEventFn(D:BENCH_SUSPEND)=
struct
  structure L=BenchLazy
  structure S=BenchStream
  structure F=BenchEventFiniteFn(D)
  datatype three=X|Low|High
  type state=three F.seq L.delay
  datatype event=At of int L.delay*int L.delay*three L.delay
  datatype func=NoFn|Fn of(int->int->int->int->state->event)*int*int
  fun at time wire what=At(L.delay(fn()=>time),L.delay(fn()=>wire),L.delay(fn()=>what))
  fun time(At(t,_,_))=L.force t
  fun wire(At(_,w,_))=L.force w
  fun what(At(_,_,s))=L.force s
  fun compareEvents left right=Int.compare(time left,time right)
  fun stateView root=F.defer(fn()=>L.force root)
  fun stateAt root index=F.nth(L.force root)index
  fun update root index value=L.delay(fn()=>F.update(stateView root)index(D.delay(fn()=>L.force value)))
  fun nand left right=case L.force left of Low=>High
    |High=>(case L.force right of High=>Low|Low=>High|X=>X)
    |X=>(case L.force right of Low=>High|_=>X)
  fun nandGate x y current target st=At(L.delay(fn()=>current+3),L.delay(fn()=>target),
    L.delay(fn()=>nand(L.delay(fn()=>stateAt st x))(L.delay(fn()=>stateAt st y))))
  fun definition 3=Fn(nandGate,0,0)
    |definition 4=Fn(nandGate,0,1)
    |definition 5=Fn(nandGate,3,1)
    |definition 6=Fn(nandGate,4,7)
    |definition 7=Fn(nandGate,5,6)
    |definition 8=Fn(nandGate,1,1)
    |definition 9=Fn(nandGate,8,6)
    |definition 10=Fn(nandGate,8,7)
    |definition 11=Fn(nandGate,9,12)
    |definition 12=Fn(nandGate,10,11)
    |definition _=NoFn
  fun recalculate(Fn(f,x,y))current target st=f x y current target st
    |recalculate NoFn _ _ _=raise Match
  val numberWires=13
  val initialState=L.delay(fn()=>F.fromList(List.tabulate(numberWires,fn _=>X)))
  fun insert dependencies target=case definition target of NoFn=>dependencies
    |Fn(_,left,right)=>
      let val first=D.delay(fn()=>F.unify(F.nth dependencies left)target)
          val second=D.delay(fn()=>F.unify(F.nth dependencies right)target)
      in F.update(F.update dependencies left first)right second end
  val dependencyTable=L.delay(fn()=>F.foldl insert
    (F.fromList(List.tabulate(numberWires,fn _=>F.empty())))
    (F.fromList(List.tabulate(numberWires,fn i=>i))))
  fun dependencies index=F.nth(L.force dependencyTable)index
  fun finiteStream values=L.delay(fn()=>case D.force values of F.Nil=>S.Nil
    |F.Cons(x,rest)=>S.Cons(L.delay(fn()=>D.force x),finiteStream rest))
  fun merge cmp xs ys=L.delay(fn()=>case L.force xs of S.Nil=>L.force ys
    |S.Cons(x,xr)=>case L.force ys of S.Nil=>S.Cons(x,xr)
      |S.Cons(y,yr)=>if cmp(L.force x)(L.force y)<>GREATER
        then S.Cons(x,merge cmp xr ys)else S.Cons(y,merge cmp xs yr))
  fun length xs=let fun loop n values=case L.force values of S.Nil=>n
    |S.Cons(_,rest)=>loop(n+1)rest in loop 0 xs end
  fun take n xs=L.delay(fn()=>if n=0 then S.Nil else case L.force xs of S.Nil=>S.Nil
    |S.Cons(x,rest)=>S.Cons(x,take(n-1)rest))
  fun drop n xs=L.delay(fn()=>if n=0 then L.force xs else case L.force xs of S.Nil=>S.Nil
    |S.Cons(_,rest)=>L.force(drop(n-1)rest))
  fun sort cmp xs=L.delay(fn()=>let val n=length xs val middle=n div 2
    in if n<=1 then L.force xs else L.force(merge cmp(sort cmp(take middle xs))(sort cmp(drop middle xs)))end)
  fun clock target current low high=S.cons(L.delay(fn()=>at current target Low),
    S.cons(L.delay(fn()=>at(current+low)target High),L.delay(fn()=>L.force(clock target(current+low+high)low high))))
  val initialEvents=merge compareEvents(clock 1 0 50 50)(clock 0 25 100 100)
  fun simulate events st finish=L.delay(fn()=>case L.force events of S.Nil=>S.Nil
    |S.Cons(e,rest)=>
      let val current=L.force e val currentTime=time current
      in if currentTime>=finish then S.Nil else
        let val target=wire current val next=what current
        in if stateAt st target=next then L.force(simulate rest st finish)
           else S.Cons(L.delay(fn()=>case current of At(t,w,s)=>At(t,w,s)),L.delay(fn()=>
             let val newState=update st target(L.delay(fn()=>next))
                 val more=S.map(fn out=>recalculate(definition out)currentTime out newState)
                   (finiteStream(dependencies target))
                 val queue=merge compareEvents rest(sort compareEvents more)
             in L.force(simulate queue newState finish)end))end end)
  fun findLastState events st=case L.force events of S.Nil=>st
    |S.Cons(e,rest)=>
      let val changed=L.delay(fn()=>
            let val current=L.force e
            in F.update(stateView st)(wire current)(D.delay(fn()=>what current))end)
      in findLastState rest changed end
  fun show X= #"x"|show Low= #"L"|show High= #"H"
  fun benchmark finish=
    let val result=findLastState(simulate initialEvents initialState finish)initialState
    in String.implode(List.map show(F.toList(L.force result)))^"\n"end
end
