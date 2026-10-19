functor BenchKnightsFn (D : BENCH_SUSPEND) =
struct
  structure L = BenchLazy
  structure S = BenchStream
  type tile = int * int
  datatype boardNode = Board of int D.t * int D.t * tile L.delay * tile S.stream
  type board = boardNode L.delay
  datatype direction = UL | UR | DL | DR | LU | LD | RU | RD
  fun move UL (x,y) = (x-1,y-2)
    | move UR (x,y) = (x+1,y-2)
    | move DL (x,y) = (x-1,y+2)
    | move DR (x,y) = (x+1,y+2)
    | move LU (x,y) = (x-2,y-1)
    | move LD (x,y) = (x-2,y+1)
    | move RU (x,y) = (x+2,y-1)
    | move RD (x,y) = (x+2,y+1)
  fun createBoard size t = L.delay(fn()=>
    Board(D.delay(fn()=>size),D.delay(fn()=>1),L.delay(fn()=>t),S.singleton t))
  fun sizeBoard b = let val Board(s,_,_,_)=L.force b in D.force s end
  fun noPieces b = let val Board(_,n,_,_)=L.force b in D.force n end
  fun firstPiece b = let val Board(_,_,f,_)=L.force b in L.force f end
  fun lastPiece b = let val Board(_,_,_,ts)=L.force b in S.head ts end
  fun addPiece t b = L.delay(fn()=>let val Board(s,n,f,ts)=L.force b
    in Board(s,D.delay(fn()=>D.force n+1),f,S.cons(t,ts))end)
  fun init xs = L.delay(fn()=>case L.force xs of S.Nil=>raise Empty
    | S.Cons(x,rest)=>case L.force rest of S.Nil=>S.Nil
      | S.Cons _ => S.Cons(x,init rest))
  fun last xs = case L.force xs of S.Nil=>raise Empty
    | S.Cons(x,rest)=>case L.force rest of S.Nil=>L.force x | _=>last rest
  fun deleteFirst b = L.delay(fn()=>let val Board(s,n,_,ts)=L.force b
      val rest=init ts
    in Board(s,D.delay(fn()=>D.force n-1),L.delay(fn()=>last rest),rest)end)
  fun positionPiece x b = let val Board(_,n,_,ts)=L.force b
    in S.nth ts (D.force n-x)end
  fun pieceAtTile t b = let val Board(_,_,_,ts)=L.force b
      fun find xs = case L.force xs of S.Nil=>raise Fail "Tile not used"
        | S.Cons(y,rest)=>if t=L.force y then 1+S.foldl(fn(_,n)=>n+1)0 rest else find rest
    in find ts end
  fun isSquareFree t b = let val Board(_,_,_,ts)=L.force b
      fun free xs = case L.force xs of S.Nil=>true
        | S.Cons(x,rest)=>t<>L.force x andalso free rest
    in free ts end
  fun canMoveTo (x,y) b = x>=1 andalso x<=sizeBoard b andalso
    y>=1 andalso y<=sizeBoard b andalso isSquareFree(x,y)b
  fun canMove b dir = canMoveTo(move dir(lastPiece b))b
  fun moveKnight b dir = addPiece(L.delay(fn()=>move dir(lastPiece b)))b
  fun possibleMoves b = S.filter(canMove b)(S.fromList[UL,UR,DL,DR,LU,LD,RU,RD])
  fun allDescend b = S.map(moveKnight b)(possibleMoves b)
  fun length xs = S.foldl(fn(_,n)=>n+1)0 xs
  fun descAndNo b = S.map(fn x=>(D.delay(fn()=>length(possibleMoves(deleteFirst x))),x))(allDescend b)
  fun singleDescend b = S.map #2 (S.filter(fn(n,_)=>D.force n=1)(descAndNo b))
  fun canJumpFirst b = canMoveTo(firstPiece b)(deleteFirst b)
  fun deadEnd b = length(possibleMoves b)=0
  fun quickSort less xs = L.delay(fn()=>case L.force xs of S.Nil=>S.Nil
    | S.Cons(x,rest)=>L.force(S.append
      (quickSort less (S.filter(fn y=>less(y,L.force x))rest))
      (S.cons(x,quickSort less(S.filter(fn y=>not(less(y,L.force x)))rest)))))
  fun descendents b = L.delay(fn()=>
    if canJumpFirst b andalso deadEnd(addPiece(L.delay(fn()=>firstPiece b))b)
    then S.Nil else let val singles=singleDescend b
      in case length singles of
        0=>L.force(S.map #2 (quickSort(fn((a,_),(c,_))=>D.force a<D.force c)(descAndNo b)))
      | 1=>L.force singles | _=>S.Nil end)
  fun tourFinished b = noPieces b=sizeBoard b*sizeBoard b andalso canJumpFirst b
  fun startTour t size = if size mod 2=0 then createBoard size t
    else raise Fail "Tour doesnt exist for odd size board"
  fun range lo hi = L.delay(fn()=>if lo>hi then S.Nil
    else S.Cons(L.delay(fn()=>lo),range(lo+1)hi))
  fun root size =
    S.map(fn t=>(D.delay(fn()=> ~(size*size)+1),startTour t size))
      (S.concatMap(fn x=>S.map(fn y=>(x,y))(range 1 size))(range 1 size))
  fun grow (n,b) = let val next=D.delay(fn()=>D.force n+1)
    in S.map(fn child=>(next,child))(descendents b)end
  fun isFinished(_,b)=tourFinished b
  fun depthSearch queue growFn finFn = L.delay(fn()=>
    let fun seek q = case L.force q of S.Nil=>S.Nil
          | S.Cons(x,rest)=>if finFn(L.force x)
            then S.Cons(x,depthSearch rest growFn finFn)
            else seek(S.append(growFn(L.force x))rest)
    in seek queue end)
  fun take n xs = L.delay(fn()=>if n<=0 then S.Nil else case L.force xs of
    S.Nil=>S.Nil | S.Cons(x,rest)=>S.Cons(x,take(n-1)rest))
  fun tours size number = take number (depthSearch(root size)grow isFinished)
  fun logTen 0 = 0 | logTen x = 1+logTen(x div 10)
  fun spaces size n = String.implode(List.tabulate(logTen size-logTen n+1,fn _=> #" "))
  fun text str = S.fromList(String.explode str)
  fun integer n = if n<0 then "-"^Int.toString(~n) else Int.toString n
  fun showBoard b =
    let val Board(s,n,_,ts)=L.force b
        val size=D.force s
        fun assign xs z = L.delay(fn()=>case L.force xs of S.Nil=>S.Nil
          | S.Cons(t,rest)=>S.Cons(L.delay(fn()=>let val(x,y)=L.force t
              in ((y-1)*size+x,z)end),assign rest(z-1)))
        val sorted=quickSort(fn((i,j),(k,l))=>i<k orelse(i=k andalso j<l))(assign ts(D.force n))
        fun print trail index = L.delay(fn()=>if index>size*size then S.Nil else
          let val(entry,rest)=case L.force trail of S.Nil=>(NONE,trail)
                | S.Cons(x,xs)=>let val(i,j)=L.force x
                  in if i=index then(SOME j,xs)else(NONE,trail)end
              val word=case entry of NONE=>"*" | SOME j=>integer j
              val suffix=if index mod size=0 then "\n"
                else spaces(size*size)(case entry of NONE=>1|SOME j=>j)
          in L.force(S.append(text(word^suffix))(print rest(index+1)))end)
    in print sorted 1 end
  fun printTour size number = S.concatMap(fn(n,b)=>
    S.append(text("\nKnights tour with "^integer(D.force n)^" backtracking moves\n"))(showBoard b))
    (tours size number)
  fun run [repText,sizeText,numberText,path] =
    let val repeats=BenchInput.between (0,1000000) (BenchInput.integer repText)
        val size=BenchInput.between (1,100) (BenchInput.integer sizeText)
        val number=BenchInput.between (0,100) (BenchInput.integer numberText)
        val input=TextIO.openIn path
        val reference=TextIO.inputAll input
        val _=TextIO.closeIn input
        fun check xs index = case L.force xs of S.Nil=>
              if index=String.size reference then index else raise Fail "incorrect result: tour length"
          | S.Cons(x,rest)=>if index<String.size reference andalso L.force x=String.sub(reference,index)
              then check rest(index+1)else raise Fail "incorrect result: tour character"
        fun loop 0 total=total | loop n total=loop(n-1)(total+IntInf.fromInt(check(printTour size number)0))
    in Int.toString repeats^" "^IntInf.toString(loop repeats 0)end
    | run _ = raise Fail "expected repetitions, board side, solution count and reference file"
end
