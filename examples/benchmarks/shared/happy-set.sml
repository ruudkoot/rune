(* Used operations from containers 0.6.7 Data.Set, delta=3 and ratio=2. *)
functor BenchHappySetFn(type item val compare:item*item->order) =
struct
  datatype tree = Tip | Bin of int * item * tree * tree
  fun size Tip=0|size(Bin(n,_,_,_))=n
  fun node x l r=Bin(1+size l+size r,x,l,r)
  fun balanceL x l r =
    case(r,l)of
      (Tip,Tip)=>node x Tip Tip
    |(Tip,Bin(_,_,Tip,Tip))=>node x l Tip
    |(Tip,Bin(_,lx,Tip,Bin(_,m,_,_)))=>node m(node lx Tip Tip)(node x Tip Tip)
    |(Tip,Bin(_,lx,ll,Tip))=>node lx ll(node x Tip Tip)
    |(Tip,Bin(_,lx,ll,lr as Bin(_,m,ml,mr)))=>
        if size lr<2*size ll then node lx ll(node x lr Tip)
        else node m(node lx ll ml)(node x mr Tip)
    |(_,Tip)=>node x Tip r
    |(_,Bin(_,lx,ll,lr))=>if size l>3*size r then
        (case lr of Bin(_,m,ml,mr)=>if size lr<2*size ll then node lx ll(node x lr r)
          else node m(node lx ll ml)(node x mr r)
         |Tip=>raise Fail "left balance shape")else node x l r
  fun balanceR x l r =
    case(l,r)of
      (Tip,Tip)=>node x Tip Tip
    |(Tip,Bin(_,_,Tip,Tip))=>node x Tip r
    |(Tip,Bin(_,rx,Tip,rr))=>node rx(node x Tip Tip)rr
    |(Tip,Bin(_,rx,Bin(_,m,_,_),Tip))=>node m(node x Tip Tip)(node rx Tip Tip)
    |(Tip,Bin(_,rx,rl as Bin(_,m,ml,mr),rr))=>
        if size rl<2*size rr then node rx(node x Tip rl)rr
        else node m(node x Tip ml)(node rx mr rr)
    |(_,Tip)=>node x l Tip
    |(_,Bin(_,rx,rl,rr))=>if size r>3*size l then
        (case rl of Bin(_,m,ml,mr)=>if size rl<2*size rr then node rx(node x l rl)rr
          else node m(node x l ml)(node rx mr rr)
         |Tip=>raise Fail "right balance shape")else node x l r
  fun insertMax x Tip=node x Tip Tip
    |insertMax x(Bin(_,y,l,r))=balanceR y l(insertMax x r)
  fun insertMin x Tip=node x Tip Tip
    |insertMin x(Bin(_,y,l,r))=balanceL y(insertMin x l)r
  fun link x Tip r=insertMin x r
    |link x l Tip=insertMax x l
    |link x(l as Bin(_,y,ly,ry))(r as Bin(_,z,lz,rz))=
      if 3*size l<size r then balanceL z(link x l lz)rz
      else if 3*size r<size l then balanceR y ly(link x ry r)
      else node x l r
  fun insertNode x Tip=node x Tip Tip
    |insertNode x(Bin(n,y,l,r))=case compare(x,y)of
        LESS=>balanceL y(insertNode x l)r|GREATER=>balanceR y l(insertNode x r)|EQUAL=>Bin(n,x,l,r)
  fun memberNode x Tip=false
    |memberNode x(Bin(_,y,l,r))=case compare(x,y)of
        LESS=>memberNode x l|GREATER=>memberNode x r|EQUAL=>true
  fun unordered _ []=false|unordered x(y::_)=compare(x,y)<>LESS
  fun fromNative []=Tip
    |fromNative[x]=node x Tip Tip
    |fromNative(x::xs)=
      let fun slow(tree,ys)=List.foldl(fn(v,t)=>insertNode v t)tree ys
          fun create(_,[])=(Tip,[],[])
            |create(s,ys as y::rest)=if s=1 then
              if unordered y rest then(node y Tip Tip,[],rest)else(node y Tip Tip,rest,[])
              else case create(s div 2,ys)of
                triple as(_,[],_)=>triple
              |(left,[z],bad)=>(insertMax z left,[],bad)
              |(left,z::zs,_)=>if unordered z zs then(left,[],z::zs)else
                let val(right,remain,bad)=create(s div 2,zs)in(link z left right,remain,bad)end
          fun go(_,tree,[])=tree
            |go(_,tree,[y])=insertMax y tree
            |go(s,tree,ys as y::rest)=if unordered y rest then slow(tree,ys)else
              case create(s,rest)of
                (right,remain,[])=>go(2*s,link y tree right,remain)
              |(right,_,bad)=>slow(link y tree right,bad)
      in if unordered x xs then slow(node x Tip Tip,xs)else go(1,node x Tip Tip,xs)end
  fun validate tree =
    let fun walk Tip=(0,NONE,NONE)
          |walk(Bin(n,key,l,r))=
            let val(a,lo,highL)=walk l val(b,lowR,hi)=walk r
                val order=(case highL of NONE=>true|SOME x=>compare(x,key)=LESS)
                  andalso(case lowR of NONE=>true|SOME x=>compare(key,x)=LESS)
                val balanced=a+b<=1 orelse(a<=3*b andalso b<=3*a)
            in if n=1+a+b andalso order andalso balanced then
              (n,case lo of NONE=>SOME key|_=>lo,case hi of NONE=>SOME key|_=>hi)
              else raise Fail "Happy set structure differs"end
    in #1(walk tree)end
  fun insertRight x Tip=node x Tip Tip
    |insertRight x(t as Bin(_,y,l,r))=case compare(x,y)of
       EQUAL=>t
      |LESS=>let val new=insertRight x l in if size new=size l then t else balanceL y new r end
      |GREATER=>let val new=insertRight x r in if size new=size r then t else balanceR y l new end
  fun split x Tip=(Tip,Tip)
    |split x(Bin(_,y,l,r))=case compare(x,y)of
       EQUAL=>(l,r)
      |LESS=>let val(lt,gt)=split x l in(lt,link y gt r)end
      |GREATER=>let val(lt,gt)=split x r in(link y l lt,gt)end
  fun minView(Bin(_,x,Tip,r))=(x,r)
    |minView(Bin(_,x,l,r))=let val(value,l')=minView l in(value,balanceR x l' r)end
    |minView Tip=raise Fail"empty set minimum"
  fun maxView(Bin(_,x,l,Tip))=(x,l)
    |maxView(Bin(_,x,l,r))=let val(value,r')=maxView r in(value,balanceL x l r')end
    |maxView Tip=raise Fail"empty set maximum"
  fun glue Tip r=r|glue l Tip=l
    |glue l r=if size l>size r then let val(x,l')=maxView l in balanceR x l' r end
              else let val(x,r')=minView r in balanceL x l r' end
  fun merge Tip r=r|merge l Tip=l
    |merge(l as Bin(ls,x,lx,rx))(r as Bin(rs,y,ly,ry))=
       if 3*ls<rs then balanceL y(merge l ly)ry
       else if 3*rs<ls then balanceR x lx(merge rx r)
       else glue l r
  fun unionNode t Tip=t
    |unionNode t(Bin(1,x,_,_))=insertRight x t
    |unionNode(Bin(1,x,_,_))t=insertNode x t
    |unionNode Tip t=t
    |unionNode(t as Bin(_,x,l,r))other=
       let val(lo,hi)=split x other
           val left=unionNode l lo val right=unionNode r hi
       in if size left=size l andalso size right=size r then t else link x left right end
  fun differenceNode Tip _=Tip
    |differenceNode t Tip=t
    |differenceNode t(Bin(_,x,l,r))=
       let val(lo,hi)=split x t
           val left=differenceNode lo l val right=differenceNode hi r
       in if size left+size right=size t then t else merge left right end
  fun filterNode _ Tip=Tip
    |filterNode predicate(t as Bin(_,x,l,r))=
       let val left=filterNode predicate l val right=filterNode predicate r
       in if predicate x then
            if size left=size l andalso size right=size r then t else link x left right
          else merge left right end
  structure L=BenchLazy
  type set=tree L.delay
  val empty:set=L.delay(fn()=>Tip)
  fun singleton x=L.delay(fn()=>node x Tip Tip)
  fun fromList values=L.delay(fn()=>fromNative(values()))
  fun member x set=memberNode x(L.force set)
  fun null set=case L.force set of Tip=>true|_=>false
  fun cardinality set=size(L.force set)
  fun union left right=L.delay(fn()=>
      let val r=L.force right in case r of Tip=>L.force left|_=>unionNode(L.force left)r end)
  fun difference left right=L.delay(fn()=>case L.force left of Tip=>Tip|l=>differenceNode l(L.force right))
  fun filter predicate set=L.delay(fn()=>filterNode predicate(L.force set))
  fun fold f initial set=
    let fun go value tree=L.delay(fn()=>case tree of Tip=>L.force value
         |Bin(_,x,l,r)=>L.force(go(L.delay(fn()=>L.force(f x(go value r))))l))
    in L.delay(fn()=>L.force(go initial(L.force set)))end
  datatype listNode=Nil|Cons of item*listNode L.delay
  val nilStream=L.delay(fn()=>Nil)
  fun streamFromList values=L.delay(fn()=>case values of []=>Nil
      |x::rest=>Cons(x,streamFromList rest))
  fun fromStream input=L.delay(fn()=>
    let fun unordered x stream=case L.force stream of Nil=>false|Cons(y,_)=>compare(x,y)<>LESS
        fun slow tree stream=case L.force stream of Nil=>tree
          |Cons(x,rest)=>slow(insertNode x tree)rest
        fun create size stream=case L.force stream of Nil=>(Tip,nilStream,nilStream)
          |Cons(y,rest)=>
           if size=1 then
             if unordered y rest then(node y Tip Tip,nilStream,rest)
             else(node y Tip Tip,rest,nilStream)
           else let val triple as(left,remain,bad)=create(size div 2)stream
                in case L.force remain of Nil=>triple
                 |Cons(z,zs)=>(case L.force zs of Nil=>(insertMax z left,nilStream,bad)
                    |_=>if unordered z zs then(left,nilStream,remain)
                        else let val(right,remain,bad)=create(size div 2)zs
                             in(link z left right,remain,bad)end)end
        fun go size tree stream=case L.force stream of Nil=>tree
          |Cons(y,rest)=>(case L.force rest of Nil=>insertMax y tree
             |_=>if unordered y rest then slow tree stream
                 else let val(right,remain,bad)=create size rest
                          val linked=link y tree right
                      in case L.force bad of Nil=>go(2*size)linked remain
                       |_=>slow linked bad end)
    in case L.force input of Nil=>Tip
      |Cons(x,rest)=>(case L.force rest of Nil=>node x Tip Tip
        |_=>if unordered x rest then slow(node x Tip Tip)rest
            else go 1(node x Tip Tip)rest)end)
  fun toAscList set=fold(fn x=>fn rest=>L.delay(fn()=>Cons(x,rest)))(L.delay(fn()=>Nil))set
  fun equal a b=
    cardinality a=cardinality b andalso
     let fun loop a b=case(L.force a,L.force b)of(Nil,Nil)=>true
           |(Cons(x,xs),Cons(y,ys))=>compare(x,y)=EQUAL andalso loop xs ys
           |_=>false
     in loop(toAscList a)(toAscList b)end
end
