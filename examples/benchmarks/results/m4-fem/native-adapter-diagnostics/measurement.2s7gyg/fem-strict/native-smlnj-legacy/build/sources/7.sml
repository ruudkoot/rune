(* Boxed immutable arrays with memoized cells. Recursive arrays install their
 * knot before the strict policy materializes finite values. *)
functor BenchFemArraysFn(val strict:bool)=
struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(BenchNeed)
 datatype 'a arrayNode=ArrayNode of int*int*'a L.delay Vector.vector
 type 'a store='a arrayNode L.delay
 datatype 'a vec=VEC of int*'a store
 datatype 'a mat=MAT of (int*int)*'a vec
 datatype 'a vbm=VBMAT of int*int vec*'a vec
 fun range first last=if first>last then[]else first::range(first+1)last
 fun rawArray low high generate=L.delay(fn()=>ArrayNode(low,high,
      Vector.tabulate(Int.max(0,high-low+1),fn i=>L.delay(fn()=>generate(low+i)))))
 fun forceArray array=let val ArrayNode(_,_,cells)=L.force array in Vector.app(fn cell=>ignore(L.force cell))cells end
 fun materialize array=if strict then forceArray array else()
 fun array low high generate=let val result=rawArray low high generate
   in materialize result;result end
 fun sub array index=let val ArrayNode(low,high,cells)=L.force array
   in if index<low orelse index>high then raise Subscript else L.force(Vector.sub(cells,index-low))end
 fun arrayBounds array=let val ArrayNode(low,high,_)=L.force array in(low,high)end
 fun listArray low values=
   let val backing=Vector.fromList values val size=Vector.length backing
   in array low(low+size-1)(fn i=>Vector.sub(backing,i-low))end
 fun delayedListArray low values=
   let val backing=Vector.fromList values val size=Vector.length backing
   in array low(low+size-1)(fn i=>L.force(Vector.sub(backing,i-low)))end
 fun change combine original updates=
   let val result=L.delay(fn()=>
        let val ArrayNode(low,high,cells)=L.force original
            val work=Array.tabulate(Vector.length cells,fn i=>Vector.sub(cells,i))
            fun update(index,value)=
              if index<low orelse index>high then raise Subscript
              else let val old=Array.sub(work,index-low)
                   in Array.update(work,index-low,combine old value)end
            val _=List.app update updates
        in ArrayNode(low,high,Vector.tabulate(Array.length work,fn i=>Array.sub(work,i)))end)
   in materialize result;result end
 fun makevec n generate=VEC(n,array 1 n generate)
 fun recursiveVec n generate=
   let val holder=ref NONE
       val cells=rawArray 1 n(fn i=>case !holder of SOME value=>generate value i|NONE=>raise Fail"uninstalled vector knot")
       val result=VEC(n,cells)
       val _=holder:=SOME result
   in materialize cells;result end
 fun boundvec(VEC(n,_))=n
 fun vecsub(VEC(_,array))index=sub array index
 fun updvec(VEC(n,array))updates=VEC(n,change(fn _=>fn value=>value)array updates)
 fun incrvec add(VEC(n,array))updates=
   VEC(n,change(fn old=>fn value=>L.delay(fn()=>add(L.force old,L.force value)))array updates)
 fun maxupdvec(VEC(n,array))updates=
   VEC(n,change(fn old=>fn value=>L.delay(fn()=>Int.max(L.force old,L.force value)))array updates)
 fun elements vector=List.map(vecsub vector)(range 1(boundvec vector))
 fun makemat(nr,nc)generate=
   let val positions=List.concat(List.map(fn i=>List.map(fn j=>(i,j))(range 1 nc))(range 1 nr))
   in MAT((nr,nc),makevec(nr*nc)(fn index=>
     F.nth(F.map generate(F.fromList positions))(index-1)))end
 fun boundmat(MAT(shape,_))=shape
 fun matsub(MAT((_,nc),elements))(i,j)=vecsub elements((i-1)*nc+j)
 fun vbdim(VBMAT(n,_,_))=n
 fun vbdiag(VBMAT(_,diagonal,_))=diagonal
 fun vbelements(VBMAT(_,_,elements))=elements
 fun firstColumn(VBMAT(_,diagonal,_))i=
   if i=1 then 1 else i-vecsub diagonal i+vecsub diagonal(i-1)+1
 fun address(VBMAT(_,diagonal,_))(i,j)=vecsub diagonal i+j-i
 fun vbsub(matrix as VBMAT(_,_,elements))position=vecsub elements(address matrix position)
 fun vbpositions n diagonal=
   List.concat(List.map(fn i=>List.map(fn j=>(i,j))
     (range(if i=1 then 1 else i-vecsub diagonal i+vecsub diagonal(i-1)+1)i))(range 1 n))
 fun makevb n diagonal generate=
   let val positions=vbpositions n diagonal
       val values=List.map(fn position=>L.delay(fn()=>generate position))positions
       val vector=Vector.fromList values
       val elements=makevec(vecsub diagonal n)(fn index=>L.force(Vector.sub(vector,index-1)))
   in VBMAT(n,diagonal,elements)end
 fun recursiveVB n diagonal generate=
   let val holder=ref NONE
       val positions=Vector.fromList(vbpositions n diagonal)
       val size=vecsub diagonal n
       val cells=rawArray 1 size(fn index=>case !holder of
          SOME value=>generate value(Vector.sub(positions,index-1))
         |NONE=>raise Fail"uninstalled bandwidth-matrix knot")
       val result=VBMAT(n,diagonal,VEC(size,cells))
       val _=holder:=SOME result
   in materialize cells;result end
 fun incrvb add(matrix as VBMAT(n,diagonal,elements))updates=
   VBMAT(n,diagonal,incrvec add elements(List.map(fn(position,value)=>(address matrix position,value))updates))
end
