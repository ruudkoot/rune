structure N=BenchAtomFn(BenchNeed)
structure R=BenchAtomFn(BenchStrict)
structure Probe =
struct
  structure L=BenchLazy structure S=BenchStream
  val input=TextIO.openIn "100.positions" val raw=TextIO.inputAll input val _=TextIO.closeIn input
  val expected=Vector.fromList(List.map(fn s=>valOf(Word32.fromString s))(String.tokens Char.isSpace raw))
  fun walkN(n,xs)=if n=100 then true else(case L.force xs of S.Nil=>false|S.Cons(value,rest)=>
    let val N.State(p,_)=L.force value val x=case BenchNeed.force p of N.Cons(x,_)=>BenchNeed.force x|_=>raise Empty
        val observed=N.bits x val wanted=Vector.sub(expected,n)
    in if observed=wanted then walkN(n+1,rest)
       else(print("DETAIL lazy index="^Int.toString n^" observed="^Word32.toString observed^" expected="^Word32.toString wanted^" value="^Real.fmt(StringCvt.GEN(SOME 17))x^"\n");false)end)
  fun walkR(n,xs)=if n=100 then true else(case L.force xs of S.Nil=>false|S.Cons(value,rest)=>
    let val R.State(p,_)=L.force value val x=case BenchStrict.force p of R.Cons(x,_)=>BenchStrict.force x|_=>raise Empty
        val observed=R.bits x val wanted=Vector.sub(expected,n)
    in if observed=wanted then walkR(n+1,rest)
       else(print("DETAIL strict index="^Int.toString n^" observed="^Word32.toString observed^" expected="^Word32.toString wanted^" value="^Real.fmt(StringCvt.GEN(SOME 17))x^"\n");false)end)
  val _=T.check("atom/trace-lazy",fn()=>walkN(0,N.start()))
  val _=T.check("atom/trace-strict",fn()=>walkR(0,R.start()))
end
