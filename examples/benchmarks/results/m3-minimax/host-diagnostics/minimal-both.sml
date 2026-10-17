functor PlayerFoldFn(D:BENCH_SUSPEND) =
struct
  datatype 'a node=Nil|Cons of 'a D.t * 'a node D.t
  datatype evaluation=XWin|OWin|Score of int
  datatype 'a tree=Branch of 'a D.t * 'a tree D.t node D.t
  fun empty()=D.delay(fn()=>Nil)
  fun ofList xs=D.delay(fn()=>case xs of []=>Nil
    |x::rest=>Cons(D.delay(fn()=>x),ofList rest))
  fun map f xs=D.delay(fn()=>case D.force xs of Nil=>Nil
    |Cons(x,rest)=>Cons(D.delay(fn()=>f(D.force x)),map f rest))
  fun foldr f base xs=D.delay(fn()=>case D.force xs of Nil=>D.force base
    |Cons(x,rest)=>f(D.force x,foldr f base rest))
  fun mise f g tree=case D.force tree of Branch(a,children)=>
    case D.force children of Nil=>D.force a
    |Cons _=>D.force(foldr(fn(x,rest)=>f x rest)
      (D.delay(fn()=>g OWin(D.delay(fn()=>XWin))))(map(mise g f)children))
end
structure K=PlayerFoldFn(BenchNeed)
structure D=BenchNeed
structure NeedPlayer =
struct
  fun f x _=x
  fun g _ y=D.force y
  fun leaf n=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score n),K.empty()))
  val tree=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score 99),K.ofList[leaf 1,leaf 2]))
  val result=K.mise f g tree
  val _=T.check("minimal-both/Need/three-node-fold",fn()=>result=K.Score 1)
end
structure K=PlayerFoldFn(BenchStrict)
structure D=BenchStrict
structure StrictPlayer =
struct
  fun f x _=x
  fun g _ y=D.force y
  fun leaf n=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score n),K.empty()))
  val tree=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score 99),K.ofList[leaf 1,leaf 2]))
  val result=K.mise f g tree
  val _=T.check("minimal-both/Strict/three-node-fold",fn()=>result=K.Score 1)
end
