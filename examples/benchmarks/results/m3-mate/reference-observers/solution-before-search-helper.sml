functor BenchMateFn(P:sig val eagerMoves:bool end)=
struct
  structure M=BenchMateMoveFn(P)
  open M
  datatype solution=Solution of moveInFull*(moveInFull*solution) S.stream
  fun solution bd c n=if n<=0 then raise Match else
    let fun alternatives xs=case L.force xs of S.Nil=>NONE
          |S.Cons(x,rest)=>let val(mif,b)=L.force x
            in case replies b(opponent c)(n-1)of NONE=>alternatives rest
              |SOME rs=>case L.force rs of S.Nil=>if kingincheck(opponent c)b
                 then SOME(Solution(mif,S.empty()))else alternatives rest
                |_=>SOME(Solution(mif,rs))end
    in alternatives(moveDetailsFor c bd)end
  and replies bd c n=
    let val moves=moveDetailsFor c bd
        fun all xs=case L.force xs of S.Nil=>SOME(S.empty())
          |S.Cons(x,rest)=>let val(mif,b)=L.force x
            in case solution b(opponent c)(n-1)of NONE=>NONE
              |SOME s=>case all rest of NONE=>NONE|SOME ms=>SOME(S.cons(L.delay(fn()=>(mif,s)),ms))end
    in if n=0 then(case L.force moves of S.Nil=>SOME(S.empty())|_=>NONE)
       else if n>0 then all moves else raise Match end
  datatype soln=Soln of moveInFull*(moveInFull list*soln)list
  fun cmpKind(k,l)=Int.compare(case k of King=>0|Queen=>1|Rook=>2|Bishop=>3|Knight=>4|Pawn=>5,
                              case l of King=>0|Queen=>1|Rook=>2|Bishop=>3|Knight=>4|Pawn=>5)
  fun thenOrder EQUAL next=next()|thenOrder result _=result
  fun cmpColour(Black,White)=LESS|cmpColour(White,Black)=GREATER|cmpColour _=EQUAL
  fun cmpPiece((c,k),(d,l))=thenOrder(cmpColour(c,d))(fn()=>cmpKind(k,l))
  fun cmpSquare((x,y),(u,v))=thenOrder(Int.compare(x,u))(fn()=>Int.compare(y,v))
  fun cmpOption cmp(NONE,NONE)=EQUAL|cmpOption cmp(NONE,SOME _)=LESS
    |cmpOption cmp(SOME _,NONE)=GREATER|cmpOption cmp(SOME x,SOME y)=cmp(x,y)
  fun cmpMove(Move(s,c,p),Move(t,d,q))=thenOrder(cmpSquare(s,t))(fn()=>
    thenOrder(cmpOption cmpPiece(c,d))(fn()=>cmpOption cmpPiece(p,q)))
  fun cmpFull(MoveInFull(p,s,m),MoveInFull(q,t,n))=thenOrder(cmpPiece(p,q))(fn()=>
    thenOrder(cmpSquare(s,t))(fn()=>cmpMove(m,n)))
  (* Stable natural mergesort: the Data.List.sortBy ascending/descending runs,
     pairwise merging and strict descending comparison retain equal-run order. *)
  fun sortBy cmp values=
    let fun merge xs []=xs|merge [] ys=ys
          |merge(xs as x::xr)(ys as y::yr)=if cmp(x,y)=GREATER then y::merge xs yr else x::merge xr ys
        fun descending a acc(b::bs)=if cmp(a,b)=GREATER then descending b(a::acc)bs
              else((a::acc),b::bs)
          |descending a acc []=(a::acc,[])
        fun ascending a acc(b::bs)=if cmp(a,b)<>GREATER then ascending b(fn tail=>acc(a::tail))bs
              else(acc[a],b::bs)
          |ascending a acc []=(acc[a],[])
        fun sequences(a::b::rest)=let val(run,tail)=if cmp(a,b)=GREATER
              then descending b[a]rest else ascending b(fn tail=>a::tail)rest
            in run::sequences tail end
          |sequences []=[]|sequences xs=[xs]
        fun pairs(a::b::rest)=merge a b::pairs rest|pairs xs=xs
        fun all []=[]|all[x]=x|all xs=all(pairs xs)
    in all(sequences values)end
  fun showSoln(Soln(mif,rs))n=Int.toString n^". "^showMoveInFull mif^
    (case rs of []=>"++\n"
      |[(mifs,s)]=>", "^(if length mifs>1 then"..."else showMoves mifs)^"; "^showSoln s(n+1)
      |_=>",\n"^showReplies(sortBy(fn((xs,_),(ys,_))=>Int.compare(length xs,length ys))rs)n)
  and showReplies [] n=""
    |showReplies((mifs,s)::rest)n=String.implode(List.tabulate(n,fn _=> #"\t"))^"if "^
      (if null rest andalso length mifs>1 then"others"else showMoves mifs)^"; "^
      showSoln s(n+1)^showReplies rest n
  fun compact(Solution(mif,rs))=
    let fun insertMove x []=[x]|insertMove x(y::ys)=case cmpFull(x,y)of
              GREATER=>y::insertMove x ys|_=>x::y::ys
        fun insert(m,s) crs=
          let val cs=compact s
              fun loop []=[([m],cs)]
                |loop(all as(mifs,other)::rest)=case String.compare(showSoln cs 1,showSoln other 1)of
                   LESS=>([m],cs)::all|EQUAL=>(insertMove m mifs,cs)::rest
                  |GREATER=>(mifs,other)::loop rest
          in loop crs end
        fun fold xs=case L.force xs of S.Nil=>[]|S.Cons(x,rest)=>insert(L.force x)(fold rest)
    in Soln(mif,fold rs)end
  fun solve bd c n=case solution bd c(2*n-1)of NONE=>"No solution!\n"|SOME s=>showSoln(compact s)1
  fun problem name input=
    let val(bd,(c,n))=readProblem input
    in "\nFile: "^name^"\n"^showBoard bd^"\n"^(case c of Black=>"Black"|White=>"White")^
      " to move and mate in "^Int.toString n^"\n\n"^solve bd c n end
  fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
  fun run [path,reference]=
    let val actual=problem path(read path)val expected=read reference
    in if actual=expected then Int.toString(String.size actual)
      else raise Fail "incorrect result: chess solution"end
    |run _=raise Fail "expected problem file and reference file"
end
