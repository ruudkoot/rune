structure Benchmark =
struct
  val name="paraffins-lazy"
  datatype radical=H|C of radical BenchLazy.delay*radical BenchLazy.delay*radical BenchLazy.delay
  datatype paraffin=BCP of radical BenchLazy.delay*radical BenchLazy.delay
    |CCP of radical BenchLazy.delay*radical BenchLazy.delay*radical BenchLazy.delay*radical BenchLazy.delay
  fun headCell xs=case BenchLazy.force xs of BenchStream.Cons(x,_)=>x|_=>raise Empty
  fun remainders xs=BenchLazy.delay(fn()=>case BenchLazy.force xs of BenchStream.Nil=>BenchStream.Nil
    |BenchStream.Cons(_,rest)=>BenchStream.Cons(BenchLazy.delay(fn()=>xs),remainders rest))
  fun mapCells f xs=BenchLazy.delay(fn()=>case BenchLazy.force xs of BenchStream.Nil=>BenchStream.Nil
    |BenchStream.Cons(x,rest)=>BenchStream.Cons(BenchLazy.delay(fn()=>f x),mapCells f rest))
  fun length xs=let fun loop(xs,n)=case BenchLazy.force xs of BenchStream.Nil=>n
    |BenchStream.Cons(_,rest)=>loop(rest,n+1)in loop(xs,0)end
  fun radicals n =
    let val holder : radical BenchStream.stream Array.array option ref=ref NONE
        fun size m =
          let val rads=valOf(!holder)
          in BenchStream.concatMap(fn(i,j,k)=>BenchStream.concatMap(fn ris=>
            let val ri=headCell ris
                val js=if i=j then ris else Array.sub(rads,j)
            in BenchStream.concatMap(fn rjs=>let val rj=headCell rjs
                val ks=if j=k then rjs else Array.sub(rads,k)
              in mapCells(fn rk=>C(ri,rj,rk))ks end)(remainders js)end)
            (remainders(Array.sub(rads,i))))(BenchStream.fromList(BenchParaffins.triples(m-1)))end
        val rads=Array.tabulate(n+1,fn j=>if j=0 then BenchStream.singleton H else
          BenchLazy.delay(fn()=>BenchLazy.force(size j)))
        val _=holder:=SOME rads
    in rads end
  fun bcp rads n = if n mod 2=1 then BenchStream.empty()else
    BenchStream.concatMap(fn ris=>let val ri=headCell ris in
      mapCells(fn rj=>BCP(ri,rj))ris end)
      (remainders(Array.sub(rads,n div 2)))
  fun ccp rads n = BenchStream.concatMap(fn(i,j,k,l)=>
    BenchStream.concatMap(fn ris=>let val ri=headCell ris val js=if i=j then ris else Array.sub(rads,j)
      in BenchStream.concatMap(fn rjs=>let val rj=headCell rjs val ks=if j=k then rjs else Array.sub(rads,k)
        in BenchStream.concatMap(fn rks=>let val rk=headCell rks val ls=if k=l then rks else Array.sub(rads,l)
          in mapCells(fn rl=>CCP(ri,rj,rk,rl))ls end)
          (remainders ks)end)(remainders js)end)(remainders(Array.sub(rads,i))))
      (BenchStream.fromList(BenchParaffins.quadruples(n-1)))
  fun calculate n =
    let val all=radicals n
        val a=List.tabulate(n+1,fn i=>length(Array.sub(all,i)))
        val br=radicals(n div 2)
        val b=List.tabulate(n,fn i=>length(bcp br(i+1)))
        val cr=radicals(n div 2)
        val c=List.tabulate(n,fn i=>length(ccp cr(i+1)))
        val both=radicals(n div 2)
        val d=List.tabulate(n,fn i=>length(bcp both(i+1))+length(ccp both(i+1)))
    in (a,b,c,d)end
  fun run args=BenchParaffins.run calculate args
end
