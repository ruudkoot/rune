from pathlib import Path
p=Path(__file__).resolve().parent
s=(p/'kernel.sml').read_text().replace('functor BenchKnightsFn','functor BenchKnightsArrayFn')
a=s.index('  datatype boardNode');b=s.index('  datatype direction',a)
s=s[:a]+'''  datatype boardNode = Board of int D.t * int D.t * tile L.delay * tile L.delay * int D.t vector L.delay
  type board = boardNode L.delay
'''+s[b:]
a=s.index('  fun createBoard');b=s.index('  fun canMoveTo',a)
s=s[:a]+'''  fun tileIndex size (x,y) = (x-1)*size+y
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
'''+s[b:]
a=s.index('  fun showBoard');b=s.index('  fun printTour',a)
s=s[:a]+'''  fun showBoard b =
    let val Board(s,n,_,_,ts)=L.force b val size=D.force s
        fun print index column=L.delay(fn()=>if index=size*size then S.Nil else
          let val value=D.force(Vector.sub(L.force ts,index))
              val word=if value=0 then "*"else integer value
              val suffix=if column=size then "\\n"else spaces(size*size)(if value=0 then 1 else value)
          in L.force(S.append(text(word^suffix))(print(index+1)(if column=size then 1 else column+1)))end)
    in S.append(text("Move number "^integer(D.force n)^"\\n"))(print 0 1)end
'''+s[b:]
(p/'array.sml').write_text(s)
