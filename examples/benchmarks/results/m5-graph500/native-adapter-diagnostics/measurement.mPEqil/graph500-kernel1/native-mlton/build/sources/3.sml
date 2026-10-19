(* OCaml 4.14.1 stdlib/array.ml and list.ml sorting definitions.
   Xavier Leroy, INRIA Rocquencourt. Copyright 1996 INRIA; LGPL 2.1 with the OCaml linking exception.
   Original sources and complete notices are retained in the reference archive. *)
structure BenchGraphSort =
struct
  fun array cmp a=
    let fun get ar i=Array.sub(ar,i)
        fun set ar i value=Array.update(ar,i,value)
        (* ArraySlice.copy retains the source's overlap-safe blit operation. *)
        fun blit src si dst di n=ArraySlice.copy{src=ArraySlice.slice(src,si,SOME n),dst=dst,di=di}
        fun merge src1ofs src1len src2 src2ofs src2len dst dstofs=
          let val end1=src1ofs+src1len val end2=src2ofs+src2len
              fun loop i1 s1 i2 s2 d=
                if cmp(s1,s2)<>GREATER then
                  (set dst d s1;
                   if i1+1<end1 then loop(i1+1)(get a(i1+1))i2 s2(d+1)
                   else blit src2 i2 dst(d+1)(end2-i2))
                else(set dst d s2;
                   if i2+1<end2 then loop i1 s1(i2+1)(get src2(i2+1))(d+1)
                   else blit a i1 dst(d+1)(end1-i1))
          in loop src1ofs(get a src1ofs)src2ofs(get src2 src2ofs)dstofs end
        fun insertion sourceOffset dst destinationOffset len=
          let fun insert i=if i=len then()else
                let val e=get a(sourceOffset+i)
                    fun shift j=if j>=destinationOffset andalso cmp(get dst j,e)=GREATER
                         then(set dst(j+1)(get dst j);shift(j-1))
                         else set dst(j+1)e
                    val _=shift(destinationOffset+i-1)
                in insert(i+1)end
          in insert 0 end
        fun sortTo sourceOffset dst destinationOffset len=
          if len<=5 then insertion sourceOffset dst destinationOffset len
          else let val l1=len div 2 val l2=len-l1
                   val _=sortTo(sourceOffset+l1)dst(destinationOffset+l1)l2
                   val _=sortTo sourceOffset a(sourceOffset+l2)l1
               in merge(sourceOffset+l2)l1 dst(destinationOffset+l1)l2 dst destinationOffset end
        val len=Array.length a
    in if len<=5 then insertion 0 a 0 len
       else let val l1=len div 2 val l2=len-l1 val temp=Array.array(l2,get a 0)
                val _=sortTo l1 temp 0 l2 val _=sortTo 0 a l2 l1
            in merge l2 l1 temp 0 l2 a 0 end end
  fun list cmp xs=
    let fun revAppend [] tail=tail|revAppend(x::xs)tail=revAppend xs(x::tail)
        fun merge [] ys acc=revAppend ys acc
          |merge xs [] acc=revAppend xs acc
          |merge(xs as x::xr)(ys as y::yr)acc=
             if cmp(x,y)<>GREATER then merge xr ys(x::acc)else merge xs yr(y::acc)
        fun mergeRev [] ys acc=revAppend ys acc
          |mergeRev xs [] acc=revAppend xs acc
          |mergeRev(xs as x::xr)(ys as y::yr)acc=
             if cmp(x,y)=GREATER then mergeRev xr ys(x::acc)else mergeRev xs yr(y::acc)
        fun sort 2(x::y::tail)=(if cmp(x,y)<>GREATER then[x,y]else[y,x],tail)
          |sort 3(x::y::z::tail)=
             ((if cmp(x,y)<>GREATER then
                 if cmp(y,z)<>GREATER then[x,y,z]
                 else if cmp(x,z)<>GREATER then[x,z,y]else[z,x,y]
               else if cmp(x,z)<>GREATER then[y,x,z]
               else if cmp(y,z)<>GREATER then[y,z,x]else[z,y,x]),tail)
          |sort n values=
             let val n1=n div 2 val n2=n-n1
                 val(s1,l2)=reverseSort n1 values val(s2,tail)=reverseSort n2 l2
             in(mergeRev s1 s2[],tail)end
        and reverseSort 2(x::y::tail)=(if cmp(x,y)=GREATER then[x,y]else[y,x],tail)
          |reverseSort 3(x::y::z::tail)=
             ((if cmp(x,y)=GREATER then
                 if cmp(y,z)=GREATER then[x,y,z]
                 else if cmp(x,z)=GREATER then[x,z,y]else[z,x,y]
               else if cmp(x,z)=GREATER then[y,x,z]
               else if cmp(y,z)=GREATER then[y,z,x]else[z,y,x]),tail)
          |reverseSort n values=
             let val n1=n div 2 val n2=n-n1
                 val(s1,l2)=sort n1 values val(s2,tail)=sort n2 l2
             in(merge s1 s2[],tail)end
        val len=List.length xs
    in if len<2 then xs else #1(sort len xs)end
end
