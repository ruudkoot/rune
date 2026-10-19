(* Used operations from containers 0.6.7 Data.Set, delta=3 and ratio=2. *)
structure BenchWordSet =
struct
  datatype set = Tip | Bin of int * string * set * set
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
  fun insert x Tip=node x Tip Tip
    |insert x(Bin(n,y,l,r))=case String.compare(x,y)of
        LESS=>balanceL y(insert x l)r|GREATER=>balanceR y l(insert x r)|EQUAL=>Bin(n,x,l,r)
  fun member x Tip=false
    |member x(Bin(_,y,l,r))=case String.compare(x,y)of
        LESS=>member x l|GREATER=>member x r|EQUAL=>true
  fun unordered _ []=false|unordered x(y::_)=String.compare(x,y)<>LESS
  fun fromList []=Tip
    |fromList[x]=node x Tip Tip
    |fromList(x::xs)=
      let fun slow(tree,ys)=List.foldl(fn(v,t)=>insert v t)tree ys
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
                val order=(case highL of NONE=>true|SOME x=>String.compare(x,key)=LESS)
                  andalso(case lowR of NONE=>true|SOME x=>String.compare(key,x)=LESS)
                val balanced=a+b<=1 orelse(a<=3*b andalso b<=3*a)
            in if n=1+a+b andalso order andalso balanced then
              (n,case lo of NONE=>SOME key|_=>lo,case hi of NONE=>SOME key|_=>hi)
              else raise Fail "word-set structure differs"end
    in #1(walk tree)end
end
