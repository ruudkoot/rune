(* Used lookup/insert path from containers0.6.7 Data.Map.Internal.
   Copyright Daan Leijen2002 and Andriy Palamarchuk2008; see pinned LICENSE.
   Source delta3/ratio2 size-balanced shapes, not an AVL replacement. *)
structure BenchPuzzleMap =
struct
  type square = int * int
  datatype board = Tip | Bin of int * square * char * board * board
  fun size Tip = 0 | size(Bin(n,_,_,_,_))=n
  fun leaf k x = Bin(1,k,x,Tip,Tip)
  fun compare ((a,b),(c,d)) = case Int.compare(a,c)of EQUAL=>Int.compare(b,d)|other=>other
  fun lookup k Tip = NONE
    | lookup k (Bin(_,key,value,left,right)) = case compare(k,key)of
        LESS=>lookup k left | GREATER=>lookup k right | EQUAL=>SOME value
  fun balanceL k x left Tip = (case left of
      Tip=>leaf k x
    | Bin(_,_,_,Tip,Tip)=>Bin(2,k,x,left,Tip)
    | Bin(_,lk,lx,Tip,Bin(_,lrk,lrx,_,_))=>Bin(3,lrk,lrx,leaf lk lx,leaf k x)
    | Bin(_,lk,lx,ll as Bin _,Tip)=>Bin(3,lk,lx,ll,leaf k x)
    | Bin(ls,lk,lx,ll as Bin(lls,_,_,_,_),lr as Bin(lrs,lrk,lrx,lrl,lrr))=>
        if lrs<2*lls then Bin(1+ls,lk,lx,ll,Bin(1+lrs,k,x,lr,Tip))
        else Bin(1+ls,lrk,lrx,Bin(1+lls+size lrl,lk,lx,ll,lrl),Bin(1+size lrr,k,x,lrr,Tip)))
    | balanceL k x left (right as Bin(rs,_,_,_,_)) = (case left of
        Tip=>Bin(1+rs,k,x,Tip,right)
      | Bin(ls,lk,lx,ll,lr)=>if ls>3*rs then(case(ll,lr)of
          (Bin(lls,_,_,_,_),Bin(lrs,lrk,lrx,lrl,lrr))=>
            if lrs<2*lls then Bin(1+ls+rs,lk,lx,ll,Bin(1+rs+lrs,k,x,lr,right))
            else Bin(1+ls+rs,lrk,lrx,Bin(1+lls+size lrl,lk,lx,ll,lrl),Bin(1+rs+size lrr,k,x,lrr,right))
        | _=>raise Fail "Failure in Data.Map.balanceL")else Bin(1+ls+rs,k,x,left,right))
  fun balanceR k x Tip right = (case right of
      Tip=>leaf k x
    | Bin(_,_,_,Tip,Tip)=>Bin(2,k,x,Tip,right)
    | Bin(_,rk,rx,Tip,rr as Bin _)=>Bin(3,rk,rx,leaf k x,rr)
    | Bin(_,rk,rx,Bin(_,rlk,rlx,_,_),Tip)=>Bin(3,rlk,rlx,leaf k x,leaf rk rx)
    | Bin(rs,rk,rx,rl as Bin(rls,rlk,rlx,rll,rlr),rr as Bin(rrs,_,_,_,_))=>
        if rls<2*rrs then Bin(1+rs,rk,rx,Bin(1+rls,k,x,Tip,rl),rr)
        else Bin(1+rs,rlk,rlx,Bin(1+size rll,k,x,Tip,rll),Bin(1+rrs+size rlr,rk,rx,rlr,rr)))
    | balanceR k x (left as Bin(ls,_,_,_,_)) right = (case right of
        Tip=>Bin(1+ls,k,x,left,Tip)
      | Bin(rs,rk,rx,rl,rr)=>if rs>3*ls then(case(rl,rr)of
          (Bin(rls,rlk,rlx,rll,rlr),Bin(rrs,_,_,_,_))=>
            if rls<2*rrs then Bin(1+ls+rs,rk,rx,Bin(1+ls+rls,k,x,left,rl),rr)
            else Bin(1+ls+rs,rlk,rlx,Bin(1+ls+size rll,k,x,left,rll),Bin(1+rrs+size rlr,rk,rx,rlr,rr))
        | _=>raise Fail "Failure in Data.Map.balanceR")else Bin(1+ls+rs,k,x,left,right))
  fun insert k x Tip = leaf k x
    | insert k x (Bin(n,key,value,left,right)) = case compare(k,key)of
        LESS=>balanceL key value(insert k x left)right
      | GREATER=>balanceR key value left(insert k x right)
      | EQUAL=>Bin(n,k,x,left,right)
  fun toList Tip=[] | toList(Bin(_,key,value,left,right))=toList left@((key,value)::toList right)
  fun shape Tip = "."
    | shape(Bin(n,(row,col),value,left,right))=String.concat["(",Int.toString n," ",Int.toString row," ",Int.toString col," ",Int.toString(Char.ord value)," ",shape left," ",shape right,")"]

end
