(* Active integer Map.Make operations from OCaml 4.14.1 map.ml.
 * Xavier Leroy / INRIA, copyright 1996. LGPL 2.1 with linking exception.
 * Original notices, complete source and license are retained in library/.
 * Change flags replace source physical-equality tests without tree comparison. *)
structure BenchStdlibIntMap=
struct
 exception NotFound
 datatype tree=Empty|Node of tree*int*int*tree*int
 fun compareKey(a:int,b)=case Int.compare(a,b)of LESS=> ~1|EQUAL=>0|GREATER=>1
 fun height Empty=0|height(Node(_,_,_,_,h))=h
 fun create l key value r=Node(l,key,value,r,Int.max(height l,height r)+1)
 fun balance l key value r=
   if height l>height r+2 then
     (case l of Empty=>raise Fail"Map.bal"
      |Node(ll,lk,lv,lr,_)=>if height ll>=height lr then create ll lk lv(create lr key value r)
        else case lr of Empty=>raise Fail"Map.bal"
          |Node(lrl,lrk,lrv,lrr,_)=>create(create ll lk lv lrl)lrk lrv(create lrr key value r))
   else if height r>height l+2 then
     (case r of Empty=>raise Fail"Map.bal"
      |Node(rl,rk,rv,rr,_)=>if height rr>=height rl then create(create l key value rl)rk rv rr
        else case rl of Empty=>raise Fail"Map.bal"
          |Node(rll,rlk,rlv,rlr,_)=>create(create l key value rll)rlk rlv(create rlr rk rv rr))
   else create l key value r
 fun addChanged key value Empty=SOME(Node(Empty,key,value,Empty,1))
   |addChanged key value(Node(l,k,v,r,h))=
      let val c=compareKey(key,k)in
      if c=0 then if value=v then NONE else SOME(Node(l,key,value,r,h))
      else if c<0 then(case addChanged key value l of NONE=>NONE|SOME next=>SOME(balance next k v r))
      else(case addChanged key value r of NONE=>NONE|SOME next=>SOME(balance l k v next))end
 fun add key value tree=case addChanged key value tree of NONE=>tree|SOME next=>next
 fun find key Empty=NONE|find key(Node(l,k,v,r,_))=
   let val c=compareKey(key,k)in if c=0 then SOME v else find key(if c<0 then l else r)end
 fun minimum Empty=raise NotFound
   |minimum(Node(Empty,k,v,_,_))=(k,v)|minimum(Node(l,_,_,_,_))=minimum l
 fun removeMinimum Empty=raise Fail"Map.remove_min_elt"
   |removeMinimum(Node(Empty,_,_,r,_))=r
   |removeMinimum(Node(l,k,v,r,_))=balance(removeMinimum l)k v r
 fun merge Empty right=right|merge left Empty=left
   |merge left right=let val(k,v)=minimum right in balance left k v(removeMinimum right)end
 fun removeChanged key Empty=NONE
   |removeChanged key(Node(l,k,v,r,_))=
      let val c=compareKey(key,k)in if c=0 then SOME(merge l r)
      else if c<0 then(case removeChanged key l of NONE=>NONE|SOME next=>SOME(balance next k v r))
      else(case removeChanged key r of NONE=>NONE|SOME next=>SOME(balance l k v next))end
 fun remove key tree=case removeChanged key tree of NONE=>tree|SOME next=>next
 fun isEmpty Empty=true|isEmpty _=false
 fun iter f Empty=()|iter f(Node(l,k,v,r,_))=(iter f l;f k v;iter f r)
 fun map f Empty=Empty
   |map f(Node(l,k,v,r,h))=let val nextL=map f l val nextV=f v val nextR=map f r
     in Node(nextL,k,nextV,nextR,h)end
 fun fold f Empty acc=acc|fold f(Node(l,k,v,r,_))acc=fold f r(f k v(fold f l acc))
 fun forAll p Empty=true|forAll p(Node(l,k,v,r,_))=p k v andalso forAll p l andalso forAll p r
 fun bindings tree=rev(fold(fn k=>fn v=>fn acc=>(k,v)::acc)tree[])
 fun decimal n=if n<0 then "-"^Int.toString(~n)else Int.toString n
 fun shape Empty="."
   |shape(Node(l,k,_,r,h))="("^decimal k^":"^Int.toString h^" "^shape l^" "^shape r^")"
 fun invariant tree=
   let fun loop Empty=(true,0,NONE,NONE)
         |loop(Node(l,k,_,r,h))=
           let val(a,hl,mnl,mxl)=loop l val(b,hr,mnr,mxr)=loop r
               val ordered=(case mxl of NONE=>true|SOME v=>v<k)andalso(case mnr of NONE=>true|SOME v=>k<v)
           in(a andalso b andalso ordered andalso h=Int.max(hl,hr)+1 andalso Int.abs(hl-hr)<=2,
              h,case mnl of NONE=>SOME k|some=>some,case mxr of NONE=>SOME k|some=>some)end
   in #1(loop tree)end
end
