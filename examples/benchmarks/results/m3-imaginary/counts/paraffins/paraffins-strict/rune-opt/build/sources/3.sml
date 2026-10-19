structure Benchmark =
struct
  val name="paraffins-strict"
  datatype radical=H|C of radical*radical*radical
  datatype paraffin=BCP of radical*radical|CCP of radical*radical*radical*radical
  fun remainders []=[]|remainders(xs as _::rest)=xs::remainders rest
  fun flat f xs=List.concat(List.map f xs)
  fun radicals n =
    let val rads=Array.array(n+1,[H])
        fun size m=flat(fn(i,j,k)=>flat(fn ris=>let val ri=List.hd ris val js=if i=j then ris else Array.sub(rads,j)
          in flat(fn rjs=>let val rj=List.hd rjs val ks=if j=k then rjs else Array.sub(rads,k)
            in List.map(fn rk=>C(ri,rj,rk))ks end)(remainders js)end)(remainders(Array.sub(rads,i))))(BenchParaffins.triples(m-1))
        fun fill i=if i>n then()else(Array.update(rads,i,size i);fill(i+1))
        val _=fill 1
    in rads end
  fun bcp rads n=if n mod 2=1 then[]else flat(fn ris=>List.map(fn rj=>BCP(List.hd ris,rj))ris)(remainders(Array.sub(rads,n div 2)))
  fun ccp rads n=flat(fn(i,j,k,l)=>flat(fn ris=>let val ri=List.hd ris val js=if i=j then ris else Array.sub(rads,j)
    in flat(fn rjs=>let val rj=List.hd rjs val ks=if j=k then rjs else Array.sub(rads,k)
      in flat(fn rks=>let val rk=List.hd rks val ls=if k=l then rks else Array.sub(rads,l)
        in List.map(fn rl=>CCP(ri,rj,rk,rl))ls end)(remainders ks)end)(remainders js)end)
      (remainders(Array.sub(rads,i))))(BenchParaffins.quadruples(n-1))
  fun calculate n =
    let val all=radicals n val a=List.tabulate(n+1,fn i=>List.length(Array.sub(all,i)))
        val br=radicals(n div 2)val b=List.tabulate(n,fn i=>List.length(bcp br(i+1)))
        val cr=radicals(n div 2)val c=List.tabulate(n,fn i=>List.length(ccp cr(i+1)))
        val both=radicals(n div 2)val d=List.tabulate(n,fn i=>List.length(bcp both(i+1))+List.length(ccp both(i+1)))
    in (a,b,c,d)end
  fun run args=BenchParaffins.run calculate args
end
