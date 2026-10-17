structure PlainPlayer =
struct
  datatype evaluation = XWin | OWin | Score of int
  datatype 'a tree = Branch of 'a * 'a tree list
  fun mise f g (Branch(a,children)) =
    case children of []=>a
    | _=>List.foldr(fn(x,rest)=>f x rest)(g OWin XWin)
      (List.map(mise g f)children)
  val fcalls=ref 0
  val gcalls=ref 0
  fun f x _=(fcalls:= !fcalls+1;x)
  fun g _ y=(gcalls:= !gcalls+1;y)
  val tree=Branch(Score 99,[Branch(Score 1,[]),Branch(Score 2,[])])
  val result=mise f g tree
  val _=T.check("plain-player/three-node-fold",fn()=>result=Score 1 andalso !fcalls=2 andalso !gcalls=1)
end
