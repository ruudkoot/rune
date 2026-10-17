(* Sandmark graph500seq/kronecker.ml: PRISM Lab, IIT Madras and OCaml Labs.
   Preserve the standalone prototype's append-based construction, draw order,
   one-based coordinates and independent row permutations. *)
structure BenchKroneckerPrototype =
struct
  structure R=BenchOCamlRandom
  fun loop n f=BenchGraph500.loop n f
  fun append a b=RealArray.tabulate(RealArray.length a+RealArray.length b,
    fn i=>if i<RealArray.length a then RealArray.sub(a,i)else RealArray.sub(b,i-RealArray.length a))
  fun addArray a b=Array.tabulate(Array.length a+Array.length b,
    fn i=>if i<Array.length a then Array.sub(a,i)else Array.sub(b,i-Array.length a))
  fun empty()=RealArray.array(0,0.0)
  fun appendOne values value=append values(RealArray.fromList[value])
  fun weights state n=
    let fun run 0 values=values|run n values=run(n-1)(appendOne values(R.real state 1.0))
    in run n(empty())end
  fun iiBits state n ab=
    let fun run 0 values=values|run n values=
       if R.real state 1.0>ab then run(n-1)(appendOne values 1.0)
       else run(n-1)(appendOne values 0.0)
    in run n(empty())end
  fun jjBits state ii m aNorm cNorm=
    let fun run index values=if index=m then values else
          let val h=RealArray.sub(ii,index)
              val threshold=cNorm*h+aNorm*Real.fromInt(Word.toInt(Word.xorb(Word.fromInt(Real.trunc h),0w1)))
              val bit=if R.real state 1.0>threshold then 1.0 else 0.0
          in run(index+1)(appendOne values bit)end
    in run 0(empty())end
  fun modify bits index original m=
    let fun run i values=if i=m then values else
          let val element=RealArray.sub(original,i)+
                Math.pow(2.0,Real.fromInt index)*RealArray.sub(bits,i)
          in run(i+1)(appendOne values element)end
    in run 0(empty())end
  fun permute compareValue state values=
    let val keyed=List.map(fn x=>(R.bits state,x))values
        fun compare((a,x),(b,y))=case Int.compare(a,b)of EQUAL=>compareValue(x,y)|order=>order
    in List.map #2(BenchGraphSort.list compare keyed)end
  fun toList a=List.tabulate(RealArray.length a,fn i=>RealArray.sub(a,i))
  fun compareRow(a,b)=
    let fun run i=if i=RealArray.length a then Int.compare(RealArray.length a,RealArray.length b)
          else if i=RealArray.length b then GREATER
          else case Real.compare(RealArray.sub(a,i),RealArray.sub(b,i))of EQUAL=>run(i+1)|order=>order
    in run 0 end
  fun transpose ar target=
    (loop(Array.length ar)(fn i=>loop(RealArray.length(Array.sub(ar,0)))(fn j=>
       RealArray.update(Array.sub(!target,j),i,RealArray.sub(Array.sub(ar,i),j))));!target)
  fun generate state scale edgeFactor=
    let val n=Real.trunc(Math.pow(2.0,Real.fromInt scale))val m=edgeFactor*n
        val a=0.57 val b=0.19 val c=0.19 val ab=a+b
        val cNorm=c/(1.0-(a+b))val aNorm=a/(a+b)
        val initial=Array.tabulate(3,fn _=>RealArray.array(m,1.0))
        fun bits index rows=if index=scale then rows else
          let val ii=iiBits state m ab
              val jj=jjBits state ii m aNorm cNorm
              val first=modify ii index(Array.sub(rows,0))m
              val second=modify jj index(Array.sub(rows,1))m
              val next=addArray(addArray(Array.fromList[first])(Array.fromList[second]))
                 (Array.fromList[Array.sub(rows,2)])
          in bits(index+1)next end
        val rows=bits 0 initial
        val third=weights state m
        val first=RealArray.fromList(permute Real.compare state(toList(Array.sub(rows,0))))
        val second=RealArray.fromList(permute Real.compare state(toList(Array.sub(rows,1))))
        val rows=addArray(addArray(Array.fromList[first])(Array.fromList[second]))(Array.fromList[third])
        val ar=transpose rows(ref(Array.tabulate(m,fn _=>RealArray.array(3,1.0))))
        val permuted=Array.fromList(permute compareRow state(List.tabulate(Array.length ar,fn i=>Array.sub(ar,i))))
    in transpose permuted(ref rows)end
  fun write path rows=
    let val out=TextIO.openOut path
        val size=ref 0 val hash=ref(0w0:Word64.word)
        fun emit text=(TextIO.output(out,text);CharVector.app(fn c=>
          (size:= !size+1;hash:=Word64.+(Word64.*(!hash,0w31),Word64.fromInt(Char.ord c))))text)
        val _=Array.app(fn row=>
          (RealArray.app(fn value=>emit(Real.fmt(StringCvt.FIX(SOME 6))value^", "))row;emit"\n"))rows
        val _=TextIO.closeOut out
    in(!size,!hash)end
end
