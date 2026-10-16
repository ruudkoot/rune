structure N=BenchAtomFn(BenchNeed)
structure R=BenchAtomFn(BenchStrict)
structure Probe =
struct
  structure L=BenchLazy structure S=BenchStream
  fun observeN n=
    let val hits=ref 0
        fun law param stream=S.map(fn vector=>(hits:= !hits+1;vector))(N.forceLaw param stream)
        val initial=L.delay(fn()=>N.State(N.fromList[1.0],N.fromList[0.0]))
        fun walk 0 xs=()|walk n xs=(case L.force xs of S.Nil=>raise Empty|S.Cons(value,rest)=>
          let val N.State(p,_)=L.force value val _=case BenchNeed.force p of N.Cons(x,_)=>ignore(BenchNeed.force x)|_=>raise Empty
          in walk(n-1)rest end)
        val _=walk n(N.experiment law N.dt(N.fromList[1.0])initial)
    in !hits end
  fun observeR n=
    let val hits=ref 0
        fun law param stream=S.map(fn vector=>(hits:= !hits+1;vector))(R.forceLaw param stream)
        val initial=L.delay(fn()=>R.State(R.fromList[1.0],R.fromList[0.0]))
        fun walk 0 xs=()|walk n xs=(case L.force xs of S.Nil=>raise Empty|S.Cons(value,rest)=>
          let val R.State(p,_)=L.force value val _=case BenchStrict.force p of R.Cons(x,_)=>ignore(BenchStrict.force x)|_=>raise Empty
          in walk(n-1)rest end)
        val _=walk n(R.experiment law R.dt(R.fromList[1.0])initial)
    in !hits end
  val _=List.app(fn n=>print(Int.toString n^" "^Int.toString(observeN n)^" "^Int.toString(observeR n)^"\n"))[0,1,2,3,4,5,6]
end
