functor BenchLastPieceFn (D : BENCH_SUSPEND) =
struct
  structure M = BenchPuzzleMap
  datatype sex = Male | Female
  datatype piece = Piece of char * (int*int) list list * (int*int) list list
  datatype solution = Soln of M.board | Choose of siblings D.t | Failure of M.board * (int*int)
  and siblings = NoSolutions | More of solution D.t * siblings D.t
  datatype candidates = CEnd | Candidate of char * (int*int) list * piece list D.t * candidates D.t
  fun flip Male=Female | flip Female=Male
  fun next(row,col)=(row,col+1)
  fun extendMaybe board (row,col) id =
    if row>8 orelse col<1 orelse col>8 then NONE else
    case M.lookup(row,col)board of SOME _=>NONE |NONE=>SOME(M.insert(row,col)id board)
  fun fit board square id []=SOME(M.insert square id board)
    | fit board (square as(row,col)) id ((dr,dc)::rest)=
        (case extendMaybe board(row+dr,col+dc)id of NONE=>NONE|SOME b=>fit b square id rest)
  val pieces=List.map Piece BenchLastPieceData.pieces
  val initial=BenchLazy.delay(fn()=>case fit M.Tip(1,1)#"a"[(1,0),(1,1)]of SOME b=>b|NONE=>raise Fail "invalid initial piece")
  fun choices gender prefix []=D.delay(fn()=>CEnd)
    | choices gender prefix ((piece as Piece(id,male,female))::tail)=D.delay(fn()=>
        let val remaining=D.delay(fn()=>prefix@tail)
            val orientations=case gender of Male=>male|Female=>female
            fun each []=D.force(choices gender(piece::prefix)tail)
              | each(offsets::rest)=Candidate(id,offsets,remaining,D.delay(fn()=>each rest))
        in each orientations end)
  fun search (square as(row,col)) gender board pieces =D.delay(fn()=>case D.force pieces of
      []=>Soln board
    | ps=>if col=9 then D.force(search(row+1,1)(flip gender)board pieces)
      else if Option.isSome(M.lookup square board)then D.force(search(next square)(flip gender)board pieces)
      else let val children=attempts square gender board(choices gender[]ps)
           in case D.force children of NoSolutions=>Failure(board,square)|More _=>Choose children end)
  and attempts square gender board candidates=D.delay(fn()=>case D.force candidates of CEnd=>NoSolutions
    | Candidate(id,offsets,remaining,rest)=>(case fit board square id offsets of NONE=>D.force(attempts square gender board rest)
      |SOME nextBoard=>More(search(next square)(flip gender)nextBoard remaining,attempts square gender board rest)))
  fun input remaining =
    if remaining=13 then (BenchLazy.force initial,pieces) else
    let val _=if remaining>=0 andalso remaining<=13 then()else raise Fail "piece count out of range"
        val fixed=List.take(pieces,13-remaining)
        val ids=List.map(fn Piece(id,_,_)=>id)fixed
        val board=List.foldl(fn((square,id),b)=>if List.exists(fn c=>c=id)ids then M.insert square id b else b)
          (BenchLazy.force initial)BenchLastPieceData.firstSolution
    in (board,List.drop(pieces,13-remaining))end
  fun solve remaining =
    let val(board,pieces)=input remaining
    in search(1,2)Female board(D.delay(fn()=>pieces))end
  type tree = solution D.t
  fun statistics tree =
    let fun visit node = case D.force node of
          Soln _ => (1,0,1)
        | Failure _ => (1,1,0)
        | Choose children => let val (nodes,fails,answers)=walk children in(nodes+1,fails,answers)end
        and walk children = case D.force children of NoSolutions => (0,0,0)
          | More(first,rest) =>
              let val(a,b,c)=visit first val(x,y,z)=walk rest in(a+x,b+y,c+z)end
    in visit tree end
  fun render tree emit =
    let val solutions=ref 0
        fun board b =
          let val _=solutions:= !solutions+1 val _=emit "Success!\n"
              fun rows 0=()
                | rows row=(emit "  ";
                    List.app(fn col=>emit(String.str(case M.lookup(row,col)b of SOME c=>c|NONE=> #".")))
                      [1,2,3,4,5,6,7,8];emit "\n";rows(row-1))
          in rows 8;emit "  \n"end
        fun visit node=case D.force node of Soln b=>board b|Failure _=>()|Choose children=>walk children
        and walk children=case D.force children of NoSolutions=>()|More(first,rest)=>(visit first;walk rest)
        val _=visit tree
        val _=if !solutions=0 then emit "\n"else()
    in !solutions end
end
