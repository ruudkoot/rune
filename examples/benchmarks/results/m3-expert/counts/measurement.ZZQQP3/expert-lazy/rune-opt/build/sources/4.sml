structure BenchExpertTable =
struct
  structure L=BenchLazy
  structure S=BenchStream
  datatype 'a tableNode=Empty|Fork of 'a tableNode L.delay *
    (string L.delay * 'a L.delay) * 'a tableNode L.delay
  type 'a table='a tableNode L.delay
  type 'a entry=string L.delay * 'a L.delay
  datatype ('a,'b) result=Answer of 'a|Reason of 'b
  fun answer(Answer a)=a|answer _=raise Match
  fun fails(Answer _)=false|fails _=true
  fun newTable()=L.delay(fn()=>Empty)
  fun find table key=L.delay(fn()=>case L.force table of Empty=>Reason "not found"
    |Fork(left,(k,v),right)=>case String.compare(key,L.force k)of
      LESS=>L.force(find left key)|EQUAL=>Answer v|GREATER=>L.force(find right key))
  fun enter table key value=L.delay(fn()=>case L.force table of
    Empty=>Fork(newTable(),(L.delay(fn()=>key),value),newTable())
    |Fork(left,e as(k,_),right)=>case String.compare(key,L.force k)of
      LESS=>Fork(enter left key value,e,right)|EQUAL=>Fork(left,e,right)
      |GREATER=>Fork(left,e,enter right key value))
  fun update table key value=L.delay(fn()=>case L.force table of
    Empty=>Fork(newTable(),(L.delay(fn()=>key),value),newTable())
    |Fork(left,e as(k,_),right)=>case String.compare(key,L.force k)of
      LESS=>Fork(update left key value,e,right)|EQUAL=>Fork(left,(L.delay(fn()=>key),value),right)
      |GREATER=>Fork(left,e,update right key value))
  fun enterList table entries=L.delay(fn()=>case L.force entries of S.Nil=>L.force table
    |S.Cons(e,rest)=>case L.force table of
       Empty=>let val entry as(k,_)=L.force e
         in Fork(enterList(newTable())(S.filter(fn(key,_)=>String.compare(L.force key,L.force k)=LESS)rest),
           entry,enterList(newTable())(S.filter(fn(key,_)=>String.compare(L.force key,L.force k)=GREATER)rest))end
      |Fork(left,e as(k,_),right)=>Fork(
         enterList left(S.filter(fn(key,_)=>String.compare(L.force key,L.force k)=LESS)entries),e,
         enterList right(S.filter(fn(key,_)=>String.compare(L.force key,L.force k)=GREATER)entries)))
  fun delete table key=L.delay(fn()=>case L.force table of Empty=>Empty
    |Fork(left,e as(k,_),right)=>case String.compare(key,L.force k)of
      LESS=>Fork(delete left key,e,right)|GREATER=>Fork(left,e,delete right key)
      |EQUAL=>L.force(graft left right))
  and graft left right=L.delay(fn()=>case L.force right of Empty=>L.force left
    |_=>let val(e,rest)=leftmost right in Fork(left,e,rest)end)
  and leftmost tree=case L.force tree of Empty=>raise Match
    |Fork(left,e,right)=>case L.force left of Empty=>(e,right)
      |_=>let val(e2,rest)=leftmost left in(e2,L.delay(fn()=>Fork(rest,e,right)))end
  fun entries table=L.delay(fn()=>case L.force table of Empty=>S.Nil
    |Fork(left,e,right)=>L.force(S.append(entries left)(S.cons(L.delay(fn()=>e),entries right))))
  fun insertKey (entry as(k,_)) xs=L.delay(fn()=>case L.force xs of S.Nil=>L.force(S.singleton entry)
    |S.Cons(e,rest)=>let val(key,_)=L.force e
      in if String.compare(L.force k,L.force key)<>GREATER then L.force(S.cons(L.delay(fn()=>entry),xs))
        else S.Cons(e,insertKey entry rest)end)
  fun sortKey xs=L.delay(fn()=>case L.force xs of S.Nil=>S.Nil
    |S.Cons(e,rest)=>L.force(insertKey(L.force e)(sortKey rest)))
  fun unique(xs:'a entry S.stream)=L.delay(fn()=>case L.force xs of S.Nil=>S.Nil
    |S.Cons(a,rest)=>case L.force rest of S.Nil=>S.Cons(a,rest)
      |S.Cons(b,_)=>if L.force(#1(L.force a))=L.force(#1(L.force b))then L.force(unique rest)
        else S.Cons(a,unique rest))
  fun mergeKey(xs:'a entry S.stream)(ys:'a entry S.stream)=L.delay(fn()=>case L.force xs of S.Nil=>L.force ys
    |S.Cons(a,ar)=>case L.force ys of S.Nil=>S.Cons(a,ar)
      |S.Cons(b,br)=>if String.compare(L.force(#1(L.force a)),L.force(#1(L.force b)))<>GREATER
        then S.Cons(a,mergeKey ar ys)else S.Cons(b,mergeKey xs br))
  fun take n xs=L.delay(fn()=>if n<=0 then S.Nil else case L.force xs of S.Nil=>S.Nil
    |S.Cons(x,rest)=>S.Cons(x,take(n-1)rest))
  fun drop n xs=if n<=0 then xs else case L.force xs of S.Nil=>S.empty()|S.Cons(_,rest)=>drop(n-1)rest
  fun balance xs=L.delay(fn()=>case L.force xs of S.Nil=>Empty
    |_=>let val middle=S.foldl(fn(_,n)=>n+1)0 xs div 2
         val entry=S.nth xs middle
       in Fork(balance(take middle xs),entry,balance(drop(middle+1)xs))end)
  fun updateList table changes=balance(mergeKey(entries table)(unique(sortKey changes)))
end
