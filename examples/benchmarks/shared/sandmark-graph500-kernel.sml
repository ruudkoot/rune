(* Sequential Graph500 Kronecker generation and list-array adjacency build.
   Original Sandmark sources and their individual notices are retained. *)
structure BenchGraph500 =
struct
  structure R=BenchOCamlRandom
  type edge=int*int*real
  fun loop n f=
    let fun run i=if i=n then()else(f i;run(i+1))
    in run 0 end
  fun power scale=Word.toInt(Word.<<(0w1,Word.fromInt scale))
  fun computeIJW state m scale=
    let val first=Array.array(m,1)val second=Array.array(m,1)
        val a=0.57 val b=0.19 val c=0.19 val ab=a+b
        val cNorm=c/(1.0-(a+b))val aNorm=a/(a+b)
        val _=loop scale(fn bit=>loop m(fn i=>
          let val ii=R.real state 1.0>ab
              val jj=R.real state 1.0>(if ii then cNorm else aNorm)
              val _=if ii then Array.update(first,i,Array.sub(first,i)+power bit)else()
          in if jj then Array.update(second,i,Array.sub(second,i)+power bit)else()end))
        val weights=RealArray.tabulate(m,fn _=>R.real state 1.0)
    in(first,second,weights)end
  fun permutation state n=
    let val data=Array.tabulate(n,fn i=>(R.bits state,i))
        val _=BenchGraphSort.array(fn((a,_),(b,_))=>Int.compare(a,b))data
    in fn i=> #2(Array.sub(data,i))end
  fun permute state values=
    let val keyed=Array.tabulate(Array.length values,fn i=>(R.bits state,Array.sub(values,i)))
        val _=BenchGraphSort.array(fn((a,_),(b,_))=>Int.compare(a,b))keyed
    in Array.tabulate(Array.length keyed,fn i=> #2(Array.sub(keyed,i)))end
  fun generate state scale edgeFactor=
    let val n=power scale val m=edgeFactor*n
        val(first,second,weights)=computeIJW state m scale
        val first=Array.tabulate(m,fn i=>Array.sub(first,i)-1)
        val second=Array.tabulate(m,fn i=>Array.sub(second,i)-1)
        val p=permutation state n
        val first=Array.tabulate(m,fn i=>p(Array.sub(first,i)))
        val second=Array.tabulate(m,fn i=>p(Array.sub(second,i)))
        val edges=Array.tabulate(m,fn i=>(Array.sub(first,i),Array.sub(second,i),RealArray.sub(weights,i)))
    in permute state edges end
  fun maxVertex(edges:edge array)=Array.foldl(fn((s,e,_),maximum)=>Int.max(maximum,Int.max(s,e)))~1 edges
  fun sparse(edges:edge array)=
    let val graph=Array.tabulate(maxVertex edges+1,fn _=>[])
        val _=loop(Array.length edges)(fn i=>
          let val(s,e,w)=Array.sub(edges,i)
          in if s=e then()else
            (Array.update(graph,s,(e,w)::Array.sub(graph,s));
             Array.update(graph,e,(s,w)::Array.sub(graph,e)))end)
    in graph end
end
