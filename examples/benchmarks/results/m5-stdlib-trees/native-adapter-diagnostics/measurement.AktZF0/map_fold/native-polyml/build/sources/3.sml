(* Active Set.Make operations from OCaml 4.14.1 set.ml.
 * Xavier Leroy / INRIA, copyright 1996. LGPL 2.1 with linking exception.
 * Original notices, complete source and license are retained in library/.
 * Change flags preserve unchanged paths without structural tree equality. *)
structure BenchStdlibIntSet=
struct
 exception NotFound
 datatype tree=Empty|Node of tree*int*tree*int
 fun compareKey(a:int,b)=case Int.compare(a,b)of LESS=> ~1|EQUAL=>0|GREATER=>1
 fun height Empty=0|height(Node(_,_,_,h))=h
 fun create l key r=Node(l,key,r,Int.max(height l,height r)+1)
 fun balance l key r=
   if height l>height r+2 then
     (case l of Empty=>raise Fail"Set.bal"
      |Node(ll,lk,lr,_)=>if height ll>=height lr then create ll lk(create lr key r)
        else case lr of Empty=>raise Fail"Set.bal"
          |Node(lrl,lrk,lrr,_)=>create(create ll lk lrl)lrk(create lrr key r))
   else if height r>height l+2 then
     (case r of Empty=>raise Fail"Set.bal"
      |Node(rl,rk,rr,_)=>if height rr>=height rl then create(create l key rl)rk rr
        else case rl of Empty=>raise Fail"Set.bal"
          |Node(rll,rlk,rlr,_)=>create(create l key rll)rlk(create rlr rk rr))
   else create l key r
 fun addChanged key Empty=SOME(Node(Empty,key,Empty,1))
   |addChanged key(Node(l,k,r,_))=
      let val c=compareKey(key,k)in if c=0 then NONE
      else if c<0 then(case addChanged key l of NONE=>NONE|SOME next=>SOME(balance next k r))
      else(case addChanged key r of NONE=>NONE|SOME next=>SOME(balance l k next))end
 fun add key tree=case addChanged key tree of NONE=>tree|SOME next=>next
 fun member key Empty=false|member key(Node(l,k,r,_))=
   let val c=compareKey(key,k)in c=0 orelse member key(if c<0 then l else r)end
 fun minimum Empty=raise NotFound
   |minimum(Node(Empty,k,_,_))=k|minimum(Node(l,_,_,_))=minimum l
 fun removeMinimum Empty=raise Fail"Set.remove_min_elt"
   |removeMinimum(Node(Empty,_,r,_))=r
   |removeMinimum(Node(l,k,r,_))=balance(removeMinimum l)k r
 fun merge Empty right=right|merge left Empty=left
   |merge left right=balance left(minimum right)(removeMinimum right)
 fun removeChanged key Empty=NONE
   |removeChanged key(Node(l,k,r,_))=
      let val c=compareKey(key,k)in if c=0 then SOME(merge l r)
      else if c<0 then(case removeChanged key l of NONE=>NONE|SOME next=>SOME(balance next k r))
      else(case removeChanged key r of NONE=>NONE|SOME next=>SOME(balance l k next))end
 fun remove key tree=case removeChanged key tree of NONE=>tree|SOME next=>next
 fun isEmpty Empty=true|isEmpty _=false
 fun fold f Empty acc=acc|fold f(Node(l,k,r,_))acc=fold f r(f k(fold f l acc))
 fun elements tree=rev(fold(fn k=>fn acc=>k::acc)tree[])
 fun decimal n=if n<0 then "-"^Int.toString(~n)else Int.toString n
 fun shape Empty="."
   |shape(Node(l,k,r,h))="("^decimal k^":"^Int.toString h^" "^shape l^" "^shape r^")"
 fun invariant tree=
   let fun loop Empty=(true,0,NONE,NONE)
         |loop(Node(l,k,r,h))=
           let val(a,hl,mnl,mxl)=loop l val(b,hr,mnr,mxr)=loop r
               val ordered=(case mxl of NONE=>true|SOME v=>v<k)andalso(case mnr of NONE=>true|SOME v=>k<v)
           in(a andalso b andalso ordered andalso h=Int.max(hl,hr)+1 andalso Int.abs(hl-hr)<=2,
              h,case mnl of NONE=>SOME k|some=>some,case mxr of NONE=>SOME k|some=>some)end
   in #1(loop tree)end
end
