(* Copyright (c) Daan Leijen 2002; Andriy Palamarchuk 2008; wren romano 2016.
   BSD-style license; full containers sources/notices retained with provenance. *)
(* Required Data.IntMap.Strict operations, containers 0.6.7; BSD notices retained. *)
structure BenchDomIntMap =
struct
  structure B=BenchDomWord
  structure W=Word64
  datatype 'a map=Nil|Tip of int*'a|Bin of W.word*W.word*'a map*'a map
  fun link p1 t1 p2 t2=
    let val mask=B.branch p1 p2 val prefix=B.mask p1 mask
    in if B.zero p1 mask then Bin(prefix,mask,t1,t2)else Bin(prefix,mask,t2,t1)end
  fun lookup key Nil=NONE
    |lookup key(Tip(k,value))=if key=k then SOME value else NONE
    |lookup key(Bin(prefix,mask,left,right))=
       if not(B.match(B.word key)prefix mask)then NONE
       else lookup key(if B.zero(B.word key)mask then left else right)
  fun insertWith f key value tree=case tree of Nil=>Tip(key,value)
    |Tip(k,old)=>if key=k then Tip(key,f value old)else link(B.word key)(Tip(key,value))(B.word k)tree
    |Bin(prefix,mask,left,right)=>if not(B.match(B.word key)prefix mask)
       then link(B.word key)(Tip(key,value))prefix tree
       else if B.zero(B.word key)mask then Bin(prefix,mask,insertWith f key value left,right)
       else Bin(prefix,mask,left,insertWith f key value right)
  fun insert key value tree=insertWith(fn new=>fn _=>new)key value tree
  fun adjust f key tree=case tree of Nil=>Nil|Tip(k,value)=>if k=key then Tip(k,f value)else tree
    |Bin(prefix,mask,left,right)=>if not(B.match(B.word key)prefix mask)then tree
      else if B.zero(B.word key)mask then Bin(prefix,mask,adjust f key left,right)
      else Bin(prefix,mask,left,adjust f key right)
  fun unionWith f first second=case(first,second)of
      (Nil,_)=>second|(_,Nil)=>first
    |(Tip(key,value),_)=>insertWith f key value second
    |(_,Tip(key,value))=>insertWith(fn right=>fn left=>f left right)key value first
    |(Bin(p1,m1,l1,r1),Bin(p2,m2,l2,r2))=>
       if B.shorter m1 m2 then
         if not(B.match p2 p1 m1)then link p1 first p2 second
         else if B.zero p2 m1 then Bin(p1,m1,unionWith f l1 second,r1)
         else Bin(p1,m1,l1,unionWith f r1 second)
       else if B.shorter m2 m1 then
         if not(B.match p1 p2 m2)then link p1 first p2 second
         else if B.zero p1 m2 then Bin(p2,m2,unionWith f first l2,r2)
         else Bin(p2,m2,l2,unionWith f first r2)
       else if p1=p2 then Bin(p1,m1,unionWith f l1 l2,unionWith f r1 r2)
       else link p1 first p2 second
  fun map f Nil=Nil|map f(Tip(key,value))=Tip(key,f value)
    |map f(Bin(prefix,mask,left,right))=Bin(prefix,mask,map f left,map f right)
  fun foldl f initial tree=
    let fun go acc Nil=acc|go acc(Tip(key,value))=f acc key value
          |go acc(Bin(_,_,left,right))=go(go acc left)right
    in case tree of Bin(_,mask,left,right)=>if mask=B.sign then go(go initial right)left
         else go initial tree|_=>go initial tree end
  fun foldr f initial tree=
    let fun go Nil acc=acc|go(Tip(key,value))acc=f key value acc
          |go(Bin(_,_,left,right))acc=go left(go right acc)
    in case tree of Bin(_,mask,left,right)=>if mask=B.sign then go right(go left initial)
         else go tree initial|_=>go tree initial end
  fun toList tree=foldr(fn key=>fn value=>fn rest=>(key,value)::rest)[]tree
  fun fromList values=List.foldl(fn((key,value),tree)=>insert key value tree)Nil values
  fun size Nil=0|size(Tip _)=1|size(Bin(_,_,left,right))=size left+size right
end
