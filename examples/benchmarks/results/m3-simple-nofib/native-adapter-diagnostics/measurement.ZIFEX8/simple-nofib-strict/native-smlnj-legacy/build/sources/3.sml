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
 fun associations(bounds as((a,b),(c,d)))generate=
   let val missing=L.delay(fn()=>raise Fail"undefined SIMPLE array element")
       val result=L.delay(fn()=>
         let val entries=generate()
             val count=Int.max(0,c-a+1)*Int.max(0,d-b+1)
             val cells=Array.array(count,missing)
             fun put((i,j),value)=
               if i<a orelse i>c orelse j<b orelse j>d then raise Subscript
               else Array.update(cells,(i-a)*(d-b+1)+j-b,value)
             val _=List.app put entries
             val _=if strict then List.app(fn(_,cell)=>ignore(L.force cell))entries else()
         in Store(bounds,Vector.tabulate(count,fn i=>Array.sub(cells,i)))end)
   in if strict then ignore(L.force result)else();result end
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
       val a=raw b(fn z=>let val(x,_)=sub shared z in L.force x end)
       val c=raw b(fn z=>let val(_,x)=sub shared z in L.force x end)
   in materialize a;materialize c;(a,c)end
 fun recursivePair b f=
   let val holder=ref NONE
       val shared=raw b(fn z=>case !holder of SOME self=>f self z|NONE=>raise Fail"pair knot")
       val a=raw b(fn z=>let val(x,_)=sub shared z in L.force x end)
       val c=raw b(fn z=>let val(_,x)=sub shared z in L.force x end)
       val _=holder:=SOME(a,c)
   in materialize a;materialize c;(a,c)end
 fun recursiveTriple b f=
   let val holder=ref NONE
       val shared=raw b(fn z=>case !holder of SOME self=>f self z|NONE=>raise Fail"triple knot")
       val a=raw b(fn z=>let val(x,_,_)=sub shared z in L.force x end)
       val c=raw b(fn z=>let val(_,x,_)=sub shared z in L.force x end)
       val d=raw b(fn z=>let val(_,_,x)=sub shared z in L.force x end)
       val _=holder:=SOME(a,c,d)
   in materialize a;materialize c;materialize d;(a,c,d)end
 datatype 'a seqNode=Nil|Cons of 'a L.delay*'a seqNode L.delay
 type 'a seq='a seqNode L.delay
 fun mapList f values=L.delay(fn()=>case values of []=>Nil
      |x::xs=>Cons(L.delay(fn()=>f x),mapList f xs))
 fun elements array=L.delay(fn()=>
   let val Store(_,values)=L.force array
       fun loop i=L.delay(fn()=>if i=Vector.length values then Nil
          else Cons(Vector.sub(values,i),loop(i+1)))
   in L.force(loop 0)end)
 fun head values=case L.force values of Nil=>raise Empty|Cons(value,_)=>L.force value
 fun foldl f initial values=
   let fun loop acc values=case L.force values of Nil=>L.force acc
         |Cons(value,rest)=>
           let val next=L.delay(fn()=>f(L.force acc,L.force value))
               val _=if strict then ignore(L.force next)else()
           in loop next rest end
   in loop initial values end
 fun total array=foldl(fn(a:real,b)=>a+b)(L.delay(fn()=>0.0))(elements array)
end
