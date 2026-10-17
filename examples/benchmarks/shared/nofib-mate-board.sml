functor BenchMateBoardFn(P:sig val eagerMoves:bool end)=
struct
  structure L=BenchLazy
  structure S=BenchStream
  datatype kind=King|Queen|Rook|Bishop|Knight|Pawn
  datatype colour=Black|White
  type piece=colour*kind
  type square=int*int
  datatype boardNode=Board of (kind*square) S.stream*(kind*square) S.stream
  type board=boardNode L.delay
  val emptyBoard=L.delay(fn()=>Board(S.empty(),S.empty()))
  fun opponent Black=White|opponent White=Black
  fun colourOf(c,_)=c
  fun kindOf(_,k)=k
  fun forcesColoured White b=let val Board(w,_)=L.force b in w end
    |forcesColoured Black b=let val Board(_,black)=L.force b in black end
  fun pieceAt b sq=
    let fun find c next xs=case L.force xs of S.Nil=>next()
          | S.Cons(x,rest)=>let val(k,s)=L.force x
            in if s=sq then SOME(c,k)else find c next rest end
    in find White(fn()=>find Black(fn()=>NONE)(forcesColoured Black b))(forcesColoured White b)end
  fun emptyAtAll b predicate=
    let fun empty (xs:(kind*square)S.stream) next=case L.force xs of S.Nil=>next()
          | S.Cons(x,rest)=>not(predicate(#2(L.force x)))andalso empty rest next
    in empty(forcesColoured White b)(fn()=>empty(forcesColoured Black b)(fn()=>true))end
  fun rPa sq (xs:(kind*square)S.stream)=L.delay(fn()=>case L.force xs of S.Nil=>raise Match
    |S.Cons(x,rest)=>if #2(L.force x)=sq then L.force rest else S.Cons(x,rPa sq rest))
  fun rmPieceAt c sq b=L.delay(fn()=>let val Board(w,black)=L.force b
    in case c of White=>Board(rPa sq w,black)|Black=>Board(w,rPa sq black)end)
  fun putPieceAt sq(c,k)b=L.delay(fn()=>let val Board(w,black)=L.force b
      val item=L.delay(fn()=>(k,sq))
    in case c of White=>Board(S.cons(item,w),black)|Black=>Board(w,S.cons(item,black))end)
  fun kingSquare c b=
    let fun seek xs=case L.force xs of S.Nil=>raise Match
          |S.Cons(x,rest)=>case L.force x of(King,sq)=>sq|_=>seek rest
    in seek(forcesColoured c b)end
  fun onboard(p,q)=1<=p andalso p<=8 andalso 1<=q andalso q<=8
  fun kindToChar King= #"K"|kindToChar Queen= #"Q"|kindToChar Rook= #"R"
    |kindToChar Bishop= #"B"|kindToChar Knight= #"N"|kindToChar Pawn= #"P"
  fun pieceToChar(Black,k)=kindToChar k|pieceToChar(White,k)=Char.toLower(kindToChar k)
  fun showPiece(_,k)=String.str(kindToChar k)
  fun showSquare c(x,y)=List.nth(["QR","QN","QB","Q","K","KB","KN","KR"],x-1)^
    Int.toString(case c of Black=>9-y|White=>y)
  fun showBoard b=String.concat(List.tabulate(8,fn row=>
    String.concat(List.tabulate(8,fn file=>" "^(case pieceAt b(file+1,8-row)of
      NONE=>"-"|SOME p=>String.str(pieceToChar p))))^"\n"))
  fun lines text=let val n=String.size text
      fun loop i start acc=if i=n then rev(if start<n then String.substring(text,start,n-start)::acc else acc)
        else if String.sub(text,i)= #"\n"then loop(i+1)(i+1)(String.substring(text,start,i-start)::acc)
        else loop(i+1)start acc
    in loop 0 0[]end
  fun readProblem text=
    let val rows=List.filter(fn s=>s<>""andalso not(String.isPrefix "--"s))(lines text)
        fun parseSquare row file c=if c= #"-"then NONE else
          let val colour=if Char.isUpper c then Black else White
              val kind=case Char.toLower c of #"k"=>King| #"q"=>Queen| #"r"=>Rook
                | #"b"=>Bishop| #"n"=>Knight| #"p"=>Pawn|_=>raise Match
          in SOME((colour,kind),(file,row))end
        fun rank row text=
          let fun loop _ []=[]|loop file(c::rest)=case parseSquare row file c of NONE=>loop(file+1)rest
                |SOME x=>x::loop(file+1)rest
          in loop 1(List.filter(fn c=>c<> #" ")(String.explode text))end
        val pieces=List.concat(List.tabulate(8,fn i=>rank(8-i)(List.nth(rows,i))))
        val bd=List.foldr(fn((p,sq),rest)=>putPieceAt sq p rest)emptyBoard pieces
        val words=String.tokens Char.isSpace(List.nth(rows,8))
        val c=case hd words of "White"=>White|"Black"=>Black|_=>raise Match
        val n=valOf(Int.fromString(List.last words))
    in (bd,(c,n))end
end
