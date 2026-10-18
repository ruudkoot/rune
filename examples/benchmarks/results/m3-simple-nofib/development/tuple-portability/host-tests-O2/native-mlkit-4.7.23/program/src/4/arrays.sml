(* Boxed immutable two-dimensional arrays. Install recursive stores before
 * optional strict finite materialization. Tuple fields remain memoized. *)
functor BenchSimpleArraysFn(val strict:bool)=
struct
 structure L=BenchLazy
 type zone=int*int
 type bounds=zone*zone
 datatype 'a store=Store of bounds*'a L.delay Vector.vector
 type 'a grid='a store L.delay
 fun range a b=if a>b then[]else a::range(a+1)b
 fun positions((a,b),(c,d))=
   List.concat(List.map(fn i=>List.map(fn j=>(i,j))(range b d))(range a c))
 fun raw bounds generate=L.delay(fn()=>
   Store(bounds,Vector.fromList(List.map(fn z=>L.delay(fn()=>generate z))(positions bounds))))
 fun sub array(i,j)=let val Store(((a,b),(c,d)),v)=L.force array
   in if i<a orelse i>c orelse j<b orelse j>d then raise Subscript
      else L.force(Vector.sub(v,(i-a)*(d-b+1)+j-b))end
 fun bounds array=let val Store(b,_)=L.force array in b end
 fun force array=let val Store(_,v)=L.force array in Vector.app(fn x=>ignore(L.force x))v end
 fun materialize array=if strict then force array else()
 fun make b f=let val a=raw b f in materialize a;a end
 fun recursive b f=
   let val holder=ref NONE
       val a=raw b(fn z=>case !holder of SOME self=>f self z|NONE=>raise Fail"array knot")
       val _=holder:=SOME a
   in materialize a;a end
 fun pair b f=
   let val shared=raw b f
       val a=raw b(fn z=>L.force(#1(sub shared z)))
       val c=raw b(fn z=>L.force(#2(sub shared z)))
   in materialize a;materialize c;(a,c)end
 fun recursivePair b f=
   let val holder=ref NONE
       val shared=raw b(fn z=>case !holder of SOME self=>f self z|NONE=>raise Fail"pair knot")
       val a=raw b(fn z=>L.force(#1(sub shared z)))
       val c=raw b(fn z=>L.force(#2(sub shared z)))
       val _=holder:=SOME(a,c)
   in materialize a;materialize c;(a,c)end
 fun recursiveTriple b f=
   let val holder=ref NONE
       val shared=raw b(fn z=>case !holder of SOME self=>f self z|NONE=>raise Fail"triple knot")
       val a=raw b(fn z=>L.force(#1(sub shared z)))
       val c=raw b(fn z=>L.force(#2(sub shared z)))
       val d=raw b(fn z=>L.force(#3(sub shared z)))
       val _=holder:=SOME(a,c,d)
   in materialize a;materialize c;materialize d;(a,c,d)end
 fun total a=List.foldl(fn(z,s)=>s+sub a z)0.0(positions(bounds a))
end
