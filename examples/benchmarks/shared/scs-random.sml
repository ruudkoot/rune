(* RandomFix's Hugs-compatible Integer mapping. Word32 retains its signed32-bit
   Schrage intermediates; result heads and state transitions share delays. *)
structure BenchScsRandom =
struct
  structure I=IntInf
  structure W=Word32
  structure L=BenchLazy
  structure S=BenchStream
  type state=W.word*W.word
  fun negative value=W.andb(value,0wx80000000)<>0w0
  fun seed n=
    let val value=I.abs n val q=I.div(value,2147483562) val r=I.mod(value,2147483562)
    in (W.fromLargeInt(I.+(r,1)),W.fromLargeInt(I.+(I.mod(q,2147483398),1)))end
  fun advance(s1,s2)=
    let val k=W.div(s1,0w53668)
        val a=W.-(W.*(0w40014,W.-(s1,W.*(k,0w53668))),W.*(k,0w12211))
        val s1=if negative a then W.+(a,0w2147483563)else a
        val k=W.div(s2,0w52774)
        val b=W.-(W.*(0w40692,W.-(s2,W.*(k,0w52774))),W.*(k,0w3791))
        val s2=if negative b then W.+(b,0w2147483399)else b
    in(s1,s2)end
  fun result(s1,s2)=
    let val z=W.-(s1,s2)
    in W.toLargeInt(if negative z orelse z=0w0 then W.+(z,0w2147483562)else z)end
  fun raw state=L.delay(fn()=>
    let val next=L.delay(fn()=>advance(L.force state))
    in S.Cons(L.delay(fn()=>result(L.force next)),raw next)end)
  fun countDigits base size=if I.<(size,base)then 1 else 1+countDigits base(I.div(size,base))
  fun random(lo,hi)n=L.delay(fn()=>
    if I.>(lo,hi)then raise Fail "Random.random: empty interval"else
    let val width=I.+(I.-(hi,lo),1) val base:I.int=2147483561
        val digits=countDigits base width
        fun take 0 source=([],source)
          |take k source=case L.force source of S.Nil=>raise Fail "finite raw random stream"
           |S.Cons(x,rest)=>let val(xs,after)=take(k-1)rest in(x::xs,after)end
        fun values source=L.delay(fn()=>
          let val(xs,rest)=take digits source
              val value=L.delay(fn()=>I.+(lo,I.mod(List.foldr(fn(x,acc)=>I.+(L.force x,I.*(acc,base)))0 xs,width)))
          in S.Cons(value,values rest)end)
    in L.force(values(raw(L.delay(fn()=>seed n))))end)
end
