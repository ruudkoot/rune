functor BenchKnightsArrayFn (D : BENCH_SUSPEND) =
struct
  structure L = BenchLazy
  structure S = BenchStream
  type tile = int * int
  datatype boardNode = Board of int D.t * int D.t * tile L.delay * tile L.delay * int D.t vector L.delay
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
  fun tileIndex size (x,y) = (x-1)*size+y
  fun indexTile size x = (x div size+1,x mod size)
  fun update values index value = L.delay(fn()=>
    let val old=L.force values
    in Vector.tabulate(Vector.length old,fn i=>if i=index-1 then value else Vector.sub(old,i))end)
  fun createBoard size t = L.delay(fn()=>
    let val zero=D.delay(fn()=>0)
        val empty=L.delay(fn()=>Vector.tabulate(size*size,fn _=>zero))
        val first=L.delay(fn()=>t)
    in Board(D.delay(fn()=>size),D.delay(fn()=>1),first,first,
      update empty(tileIndex size t)(D.delay(fn()=>1)))end)
  fun sizeBoard b = let val Board(s,_,_,_,_)=L.force b in D.force s end
  fun noPieces b = let val Board(_,n,_,_,_)=L.force b in D.force n end
  fun firstPiece b = let val Board(_,_,_,f,_)=L.force b in L.force f end
  fun lastPiece b = let val Board(_,_,l,_,_)=L.force b in L.force l end
  fun addPiece t b = L.delay(fn()=>let val Board(s,n,_,f,ts)=L.force b
      val next=D.delay(fn()=>D.force n+1)
      val array=L.delay(fn()=>L.force(update ts(tileIndex(D.force s)(L.force t))next))
    in Board(s,next,t,f,array)end)
  fun deleteFirst b = L.delay(fn()=>let val Board(s,n,l,f,ts)=L.force b
      val array=L.delay(fn()=>L.force(update ts(tileIndex(D.force s)(L.force f))(D.delay(fn()=>0))))
    in Board(s,n,l,l,array)end)
  fun positionPiece x b = let val Board(s,_,_,_,ts)=L.force b
      val size=D.force s val array=L.force ts
      fun find i=if i>size*size then raise Fail "Piece not found"
        else if D.force(Vector.sub(array,i-1))=x then indexTile size i else find(i+1)
    in find 1 end
  fun pieceAtTile t b=let val Board(s,_,_,_,ts)=L.force b
    in D.force(Vector.sub(L.force ts,tileIndex(D.force s)t-1))end
  fun isSquareFree t b=pieceAtTile t b=0
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
    let val Board(s,n,_,_,ts)=L.force b val size=D.force s
        fun print index column=L.delay(fn()=>if index=size*size then S.Nil else
          let val value=D.force(Vector.sub(L.force ts,index))
              val word=if value=0 then "*"else integer value
              val suffix=if column=size then "\n"else spaces(size*size)(if value=0 then 1 else value)
          in L.force(S.append(text(word^suffix))(print(index+1)(if column=size then 1 else column+1)))end)
    in S.append(text("Move number "^integer(D.force n)^"\n"))(print 0 1)end
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
