structure NeedMinimax=BenchMinimaxFn(BenchNeed)
structure NeedProbe=struct
structure K=NeedMinimax
structure D=BenchNeed
val mode="Need"
  val _=T.check("minimax/"^mode^"/custom-player-recursive-fold",fn()=>
    let val fcalls=ref 0 val gcalls=ref 0
        fun f x _=(fcalls:= !fcalls+1;x)
        fun g _ y=(gcalls:= !gcalls+1;D.force y)
        fun leaf n=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score n),K.empty()))
        val tree=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score 99),K.ofList[leaf 1,leaf 2]))
        val result=K.mise f g tree
    in result=K.Score 1 andalso !fcalls=(if mode="Need"then 1 else 2)
       andalso !gcalls=(if mode="Need"then 0 else 1)end)
end
structure StrictMinimax=BenchMinimaxFn(BenchStrict)
structure StrictProbe=struct
structure K=StrictMinimax
structure D=BenchStrict
val mode="Strict"
  val _=T.check("minimax/"^mode^"/custom-player-recursive-fold",fn()=>
    let val fcalls=ref 0 val gcalls=ref 0
        fun f x _=(fcalls:= !fcalls+1;x)
        fun g _ y=(gcalls:= !gcalls+1;D.force y)
        fun leaf n=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score n),K.empty()))
        val tree=D.delay(fn()=>K.Branch(D.delay(fn()=>K.Score 99),K.ofList[leaf 1,leaf 2]))
        val result=K.mise f g tree
    in result=K.Score 1 andalso !fcalls=(if mode="Need"then 1 else 2)
       andalso !gcalls=(if mode="Need"then 0 else 1)end)
end
