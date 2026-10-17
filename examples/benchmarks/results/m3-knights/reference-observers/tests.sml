functor KnightsTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string end)=struct
 structure K=BenchKnightsFn(P.D)
 structure L=BenchLazy
 structure S=BenchStream
 val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/knights-originals/"
 fun label s="knights/"^P.policy^"/"^s
 fun render size number=String.implode(rev(S.foldl(fn(c,cs)=>c::cs)[](K.printTour size number)))
 fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
 val _=List.app(fn(size,number)=>T.check(label("original "^Int.toString size^"/"^Int.toString number),fn()=>
    render size number=read(base^Int.toString size^"-"^Int.toString number^".tour")))
    [(6,1),(8,1),(8,3),(14,1),(20,1),(4,1),(8,0)]
 fun valid size b=
   let val K.Board(_,_,_,trail)=L.force b
       val ts=S.take(size*size+1)trail
       fun unique []=true|unique(x::xs)=not(List.exists(fn y=>x=y)xs)andalso unique xs
       fun jump((x,y),(u,v))=let val a=Int.abs(x-u)val c=Int.abs(y-v)
         in (a=1 andalso c=2)orelse(a=2 andalso c=1)end
       fun walk(x::y::rest)=jump(x,y)andalso walk(y::rest)|walk _=true
   in length ts=size*size andalso K.noPieces b=size*size andalso unique ts
     andalso List.all(fn(x,y)=>x>=1 andalso x<=size andalso y>=1 andalso y<=size)ts
     andalso walk ts andalso jump(hd ts,List.last ts)end
 val _=List.app(fn size=>T.check(label("independent closed tour "^Int.toString size),fn()=>
   let val (_,b)=S.head(K.tours size 1)in valid size b end))[6,8,14,20]
 val _=T.check(label "zero solutions do not demand odd-board error",fn()=>null(S.take 1(K.tours 3 0)))
 val _=T.check(label "odd board rejected when demanded",fn()=>
   ((L.force(K.startTour(1,1)3);false)handle Fail _=>true))
 val _=T.check(label "empty first field stays unused",fn()=>
   K.isSquareFree(1,1)(K.deleteFirst(K.createBoard 8(1,1))))
 val _=T.check(label "deleted singleton first raises when demanded",fn()=>
   ((K.firstPiece(K.deleteFirst(K.createBoard 8(1,1)));false)handle Empty=>true))
 val _=T.check(label "source direction order",fn()=>
   S.take 8(K.possibleMoves(K.createBoard 8(4,4)))=[K.UL,K.UR,K.DL,K.DR,K.LU,K.LD,K.RU,K.RD])
 val _=T.check(label "stable equal degree partition order",fn()=>
   S.take 4(K.quickSort(fn((x,_),(y,_))=>x<y)(S.fromList[(2,1),(1,2),(2,3),(1,4)]))=
   [(1,2),(1,4),(2,1),(2,3)])
 val _=T.check(label "recorded consumer",fn()=>K.run["2","8","1",base^"8-1.tour"]="2 464")
 val _=T.check(label "zero repetitions",fn()=>K.run["0","8","1",base^"8-1.tour"]="0 0")
 val _=T.check(label "wrong tour rejected",fn()=>
   ((K.run["1","8","1",base^"4-1.tour"];false)handle Fail _=>true))
end
structure LazyKnightsTests=KnightsTestsFn(struct structure D=BenchNeed val policy="lazy"end)
structure StrictKnightsTests=KnightsTestsFn(struct structure D=BenchStrict val policy="strict"end)

structure KnightsCountedNeed=struct
 val calls=ref 0
 type 'a t='a BenchLazy.delay
 fun delay f=BenchLazy.delay(fn()=>(calls:= !calls+1;f()))
 val force=BenchLazy.force
end
structure KnightsCounted=BenchKnightsFn(KnightsCountedNeed)
val _=T.check("knights/counted metadata demand",fn()=>
 let val b=KnightsCounted.createBoard 8(1,1)
     val start= !KnightsCountedNeed.calls
     val first=KnightsCounted.noPieces b
     val afterFirst= !KnightsCountedNeed.calls
     val second=KnightsCounted.noPieces b
 in first=1 andalso second=1 andalso afterFirst=start+1
    andalso !KnightsCountedNeed.calls=afterFirst end)
val _=T.check("knights/persistent predecessor board",fn()=>
 let val old=KnightsCounted.createBoard 8(1,1)
     val next=KnightsCounted.addPiece(BenchLazy.delay(fn()=>(2,3)))old
 in KnightsCounted.noPieces next=2 andalso KnightsCounted.lastPiece next=(2,3)
    andalso KnightsCounted.noPieces old=1 andalso KnightsCounted.isSquareFree(2,3)old end)
