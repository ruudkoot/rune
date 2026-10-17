from pathlib import Path
p=Path(__file__).resolve().parent;root=Path.cwd()
s='''functor MateTestsFn(P:sig val eagerMoves:bool val policy:string end)=struct
 structure K=BenchMateFn(P)
 open K
 val base="BASE"
 fun label s="mate/"^P.policy^"/"^s
 fun bool true="True"|bool false="False"
 fun moveReference input=
   let val(bd,(c,_))=readProblem input
   in showBoard bd^"("^bool(kingincheck White bd)^","^bool(kingincheck Black bd)^")\\n"^
     String.concat(rev(S.foldl(fn((m,b),xs)=>(showMoveInFull m^"\\n"^showBoard b)::xs)[](moveDetailsFor c bd)))end
 val _=List.app(fn name=>T.check(label("original moves "^name),fn()=>
   moveReference(read(base^"cases/"^name^".prob"))=read(base^"cases/"^name^".moves")))
   ["mate","stalemate","promotion","pinned-rook","black-pawn-check","heathcote3","kohtz","holzhausen","simple"]
 val _=List.app(fn name=>T.check(label("original solve "^name),fn()=>
   let val(bd,(c,n))=readProblem(read(base^"cases/"^name^".prob"))
   in solve bd c n=read(base^"cases/"^name^".solution")end))
   ["mate","stalemate","promotion","pinned-rook","black-pawn-check","simple"]
 val _=T.check(label "stable source sort",fn()=>sortBy(fn((a,_),(b,_))=>Int.compare(a,b))
   [(2,1),(1,2),(2,3),(1,4),(0,5)]=[(0,5),(1,2),(1,4),(2,1),(2,3)])
 val _=T.check(label "source data constructor order",fn()=>
   cmpKind(King,Queen)=LESS andalso cmpKind(Knight,Pawn)=LESS andalso cmpColour(Black,White)=LESS)
 val _=T.check(label "piece lookup avoids unused opponent",fn()=>
   let val bd=L.delay(fn()=>Board(S.singleton(King,(1,1)),L.delay(fn()=>raise Fail "unused opponent")))
   in pieceAt bd(1,1)=SOME(White,King)end)
 val _=T.check(label "check avoids unused attacker tail",fn()=>
   let val bd=L.delay(fn()=>Board(S.singleton(King,(1,1)),
     S.cons(L.delay(fn()=>(Rook,(1,8))),L.delay(fn()=>raise Fail "unused attacker"))))
   in kingincheck White bd end)
 val _=T.check(label "source stopping at first legal reply",fn()=>
   let val bd=L.delay(fn()=>Board(S.cons(L.delay(fn()=>(King,(1,1))),
         L.delay(fn()=>raise Fail "later piece")),S.singleton(King,(8,8))))
       fun attempt()=case replies bd White 0 of NONE=>true|_=>false
   in if P.eagerMoves then ((attempt();false)handle Fail message=>message="later piece")
      else attempt()end)
 val _=T.check(label "persistent board predecessor",fn()=>
   let val old=putPieceAt(1,1)(White,King)emptyBoard
       val next=putPieceAt(2,3)(White,Knight)old
   in pieceAt old(2,3)=NONE andalso pieceAt next(2,3)=SOME(White,Knight)end)
 val _=T.check(label "four promotion choices",fn()=>
   let val(bd,_)=readProblem(read(base^"cases/promotion.prob"))
       val promotions=S.foldl(fn((MoveInFull(_,_,Move(_,_,p)),_),n)=>case p of NONE=>n|SOME _=>n+1)0(moveDetailsFor White bd)
   in promotions=4 end)
 val _=T.check(label "checked consumer",fn()=>
   let val actual=problem "runtime_files/simple.prob"(read(base^"cases/simple.prob"))
   in actual=read(base^"smoke-small.stdout")end)
 val _=T.check(label "incorrect output rejected",fn()=>
   ((run[base^"cases/simple.prob",base^"cases/simple.solution"];false)handle Fail message=>String.isPrefix "incorrect result:"message))
end
structure LazyMateTests=MateTestsFn(struct val eagerMoves=false val policy="lazy"end)
structure StrictMateTests=MateTestsFn(struct val eagerMoves=true val policy="strict"end)
'''.replace('BASE',str(p)+'/')
(p/'tests.sml').write_text(s)
files=[root/'tests/basis/harness.sml']+[root/'examples/benchmarks/shared'/x for x in ['lazy.sml','stream.sml']]+[p/x for x in ['board.sml','move.sml','solution.sml','tests.sml']]+[root/'tests/basis/finish.sml']
(p/'test-sources.txt').write_text(''.join(str(f)+'\n'for f in files))
