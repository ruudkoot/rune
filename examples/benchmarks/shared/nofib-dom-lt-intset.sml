(* Copyright (c) Daan Leijen 2002; Joachim Breitner 2011.
   BSD-style license; full containers sources/notices retained with provenance. *)
(* Required Data.IntSet.Internal operations, containers 0.6.7.
   Big-endian Patricia nodes and 64-bit bitmap leaves; BSD notices retained. *)
structure BenchDomIntSet =
struct
  structure B=BenchDomWord
  structure W=Word64
  datatype set=Nil|Tip of W.word*W.word|Bin of W.word*W.word*set*set
  fun prefix key=W.andb(B.word key,W.notb(0w63:W.word))
  fun bitmap key=B.bit(W.toInt(W.andb(B.word key,0w63)))
  fun tip _ 0w0=Nil|tip key bits=Tip(key,bits)
  fun bin _ _ Nil right=right|bin _ _ left Nil=left
    |bin prefix mask left right=Bin(prefix,mask,left,right)
  fun link p1 t1 p2 t2=let val mask=B.branch p1 p2 val prefix=B.mask p1 mask
    in if B.zero p1 mask then Bin(prefix,mask,t1,t2)else Bin(prefix,mask,t2,t1)end
  fun insertBM key bits tree=case tree of Nil=>Tip(key,bits)
    |Tip(old,oldBits)=>if key=old then Tip(key,W.orb(bits,oldBits))else link key(Tip(key,bits))old tree
    |Bin(prefix,mask,left,right)=>if not(B.match key prefix mask)then link key(Tip(key,bits))prefix tree
      else if B.zero key mask then Bin(prefix,mask,insertBM key bits left,right)
      else Bin(prefix,mask,left,insertBM key bits right)
  fun insert key tree=insertBM(prefix key)(bitmap key)tree
  fun singleton key=Tip(prefix key,bitmap key)
  fun member key tree=
    let val p=prefix key val b=bitmap key
        fun go Nil=false|go(Tip(old,bits))=old=p andalso W.andb(bits,b)<>0w0
          |go(Bin(prefix,mask,left,right))=B.match p prefix mask andalso go(if B.zero p mask then left else right)
    in go tree end
  fun union first second=case(first,second)of
      (Nil,_)=>second|(_,Nil)=>first
    |(Tip(key,bits),_)=>insertBM key bits second
    |(_,Tip(key,bits))=>insertBM key bits first
    |(Bin(p1,m1,l1,r1),Bin(p2,m2,l2,r2))=>
       if B.shorter m1 m2 then
         if not(B.match p2 p1 m1)then link p1 first p2 second
         else if B.zero p2 m1 then Bin(p1,m1,union l1 second,r1)else Bin(p1,m1,l1,union r1 second)
       else if B.shorter m2 m1 then
         if not(B.match p1 p2 m2)then link p1 first p2 second
         else if B.zero p1 m2 then Bin(p2,m2,union first l2,r2)else Bin(p2,m2,l2,union first r2)
       else if p1=p2 then Bin(p1,m1,union l1 l2,union r1 r2)else link p1 first p2 second
  fun deleteBM key bits tree=case tree of Nil=>Nil
    |Tip(old,oldBits)=>if old=key then tip old(W.andb(oldBits,W.notb bits))else tree
    |Bin(prefix,mask,left,right)=>if not(B.match key prefix mask)then tree
      else if B.zero key mask then bin prefix mask(deleteBM key bits left)right
      else bin prefix mask left(deleteBM key bits right)
  fun difference first second=case(first,second)of(Nil,_)=>Nil|(_,Nil)=>first
    |(_,Tip(key,bits))=>deleteBM key bits first
    |(Tip(key,bits),Bin(prefix,mask,left,right))=>if not(B.match key prefix mask)then first
       else difference first(if B.zero key mask then left else right)
    |(Bin(p1,m1,l1,r1),Bin(p2,m2,l2,r2))=>
       if B.shorter m1 m2 then
         if not(B.match p2 p1 m1)then first
         else if B.zero p2 m1 then bin p1 m1(difference l1 second)r1
         else bin p1 m1 l1(difference r1 second)
       else if B.shorter m2 m1 then
         if not(B.match p1 p2 m2)then first else difference first(if B.zero p1 m2 then l2 else r2)
       else if p1=p2 then bin p1 m1(difference l1 l2)(difference r1 r2)else first
  fun foldr f initial tree=
    let fun bits key bitmap acc=if bitmap=0w0 then acc else
          let val index=B.highestIndex bitmap val rest=W.xorb(bitmap,B.bit index)
          in bits key rest(f(B.integer(W.orb(key,W.fromInt index)))acc)end
        fun go Nil acc=acc|go(Tip(key,bitmap))acc=bits key bitmap acc
          |go(Bin(_,_,left,right))acc=go left(go right acc)
    in case tree of Bin(_,mask,left,right)=>if mask=B.sign then go right(go left initial)
         else go tree initial|_=>go tree initial end
  fun toList tree=foldr(fn value=>fn rest=>value::rest)[]tree
  fun filter predicate tree=
    let fun bits key bitmap acc=if bitmap=0w0 then acc else
          let val index=B.lowestIndex bitmap val bit=B.bit index
              val rest=W.andb(bitmap,W.-(bitmap,0w1))
              val acc=if predicate(B.integer(W.orb(key,W.fromInt index)))then W.orb(acc,bit)else acc
          in bits key rest acc end
        fun go Nil=Nil|go(Tip(key,bitmap))=tip key(bits key bitmap 0w0)
          |go(Bin(prefix,mask,left,right))=bin prefix mask(go left)(go right)
    in go tree end
  fun fromList values=List.foldl(fn(value,tree)=>insert value tree)Nil values
end
