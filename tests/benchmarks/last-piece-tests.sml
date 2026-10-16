structure LastPieceNeed = BenchLastPieceFn (BenchNeed)
structure LastPieceStrict = BenchLastPieceFn (BenchStrict)
structure LastPieceNeedCheck = LastPieceCheckFn (LastPieceNeed)
structure LastPieceStrictCheck = LastPieceCheckFn (LastPieceStrict)
structure LastPieceTests =
struct
 structure N=LastPieceNeed
 structure M=BenchPuzzleMap
 fun ids ps=List.map(fn N.Piece(id,_,_)=>id)ps
 val orders=[("ascending",List.tabulate(64,fn i=>i)),("descending",List.rev(List.tabulate(64,fn i=>i))),
   ("zigzag",List.concat(List.tabulate(32,fn i=>[i,63-i]))),("permuted",List.tabulate(64,fn i=>(i*37) mod 64))]
 val _=List.app(fn(name,order)=>T.check("last-piece/source-map-prefix-shapes-"^name,fn()=>
   let val input=TextIO.openIn("map-"^name^".expected")
       fun loop [] board=not(Option.isSome(TextIO.inputLine input))andalso M.size board=64
         | loop(i::rest)board=
             let val next=M.insert(i div 8+1,i mod 8+1)(Char.chr(97+i mod 14))board
             in TextIO.inputLine input=SOME(M.shape next^"\n")andalso loop rest next end
       val result=loop order M.Tip val _=TextIO.closeIn input
   in result end))orders
 val _=T.check("last-piece/initial-board",fn()=>M.toList(BenchLazy.force N.initial)=[((1,1),#"a"),((2,1),#"a"),((2,2),#"a")])
 val _=T.check("last-piece/pick-one-reversed-prefix",fn()=>
  let val ps=List.map(fn c=>N.Piece(c,[[]],[[]]))[#"a",#"b",#"c"]
      fun choices stream=case BenchNeed.force stream of N.CEnd=>[]
        |N.Candidate(id,_,remaining,rest)=>(id,ids(BenchNeed.force remaining))::choices rest
  in choices(N.choices N.Female[]ps)=[(#"a",[#"b",#"c"]),(#"b",[#"a",#"c"]),(#"c",[#"b",#"a"])]end)
 val _=T.check("last-piece/remaining-pieces-delayed-and-shared",fn()=>
  let val ps=[N.Piece(#"a",[[],[(0,1)]],[[],[(0,1)]]),N.Piece(#"b",[[]],[[]])]
  in case BenchNeed.force(N.choices N.Female[]ps)of
    N.Candidate(_,_,remaining,rest)=>
      let val pending=case !remaining of BenchLazy.Pending _=>true|_=>false
      in case BenchNeed.force rest of N.Candidate(_,_,same,_)=>pending andalso remaining=same|_=>false end
   |_=>false end)
 val _=T.check("last-piece/lazy-root-and-child-demand",fn()=>
  let val root=N.solve 2 val pending=case !root of BenchLazy.Pending _=>true|_=>false
  in case BenchNeed.force root of N.Choose children=>
       (case BenchNeed.force children of N.More(child,_)=>pending andalso(case !child of BenchLazy.Pending _=>true|_=>false)|_=>false)
     |_=>false end)
 val _=T.check("last-piece/offset-bounds-and-collision",fn()=>
  let val board=BenchLazy.force N.initial
  in not(Option.isSome(N.extendMaybe board(9,1)#"b"))andalso
     not(Option.isSome(N.extendMaybe board(1,0)#"b"))andalso
     not(Option.isSome(N.extendMaybe board(1,1)#"b"))end)
 val _=T.check("last-piece/fit-anchor-source-precondition",fn()=>
  case N.fit(BenchLazy.force N.initial)(1,1)#"b"[]of SOME b=>M.lookup(1,1)b=SOME #"b"|NONE=>false)
 val _=List.app(fn n=>
   (T.check("last-piece/complete-lazy-prefix-"^Int.toString n,fn()=>LastPieceNeedCheck.run n(Int.toString n^".output")=(1,100));
    T.check("last-piece/complete-strict-prefix-"^Int.toString n,fn()=>LastPieceStrictCheck.run n(Int.toString n^".output")=(1,100))))[0,2,8]
 val _=T.check("last-piece/source-search-node-statistics",fn()=>N.statistics(N.solve 8)=(76,46,1))
 fun rejects path=(ignore(LastPieceNeedCheck.run 2 path);false)handle Fail message=>String.isPrefix "incorrect result:" message
 val _=T.check("last-piece/wrong-board-rejected",fn()=>rejects "wrong.output")
 val _=T.check("last-piece/truncated-rejected",fn()=>rejects "truncated.output")
 val _=T.check("last-piece/extra-rejected",fn()=>rejects "extra.output")
end
