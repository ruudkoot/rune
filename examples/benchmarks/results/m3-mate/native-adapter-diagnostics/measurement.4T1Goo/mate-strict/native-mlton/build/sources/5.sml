functor BenchMateMoveFn(P:sig val eagerMoves:bool end)=
struct
  structure B=BenchMateBoardFn(P)
  open B
  datatype move=Move of square*piece option*piece option
  datatype moveInFull=MoveInFull of piece*square*move
  fun showMove withPiece(MoveInFull(p as(c,k),sq,Move(sq',captured,promotion)))=
    (if withPiece then showPiece p^(if k=King orelse(k=Pawn andalso captured=NONE andalso promotion=NONE)
       then ""else"/"^showSquare c sq)else"")^
    (case captured of NONE=>"-"|SOME p=>"x"^showPiece p^"/")^showSquare c sq'^
    (case promotion of NONE=>""|SOME p=>"("^showPiece p^")")
  val showMoveInFull=showMove true
  fun showMoves []=raise Match
    |showMoves(first::rest)=
      let fun after _ []=""|after(MoveInFull(p',sq',_))((m as MoveInFull(p,sq,_))::xs)=
             ", "^showMove(p<>p' orelse sq<>sq')m^after m xs
      in showMoveInFull first^after first rest end
  fun kingincheck c bd=
    let val king=L.delay(fn()=>kingSquare c bd)
        fun givesCheck(k,(x,y))=
          let val(xk,yk)=L.force king
              fun threat King=Int.abs(x-xk)<=1 andalso Int.abs(y-yk)<=1
                |threat Queen=threat Rook orelse threat Bishop
                |threat Rook=(x=xk andalso emptyAtAll bd(fn(xe,ye)=>xe=xk andalso Int.min(y,yk)<ye andalso ye<Int.max(y,yk)))
                   orelse(y=yk andalso emptyAtAll bd(fn(xe,ye)=>ye=yk andalso Int.min(x,xk)<xe andalso xe<Int.max(x,xk)))
                |threat Bishop=(x+y=xk+yk andalso emptyAtAll bd(fn(xe,ye)=>xe+ye=xk+yk andalso Int.min(x,xk)<xe andalso xe<Int.max(x,xk)))
                   orelse(x-y=xk-yk andalso emptyAtAll bd(fn(xe,ye)=>xe-ye=xk-yk andalso Int.min(x,xk)<xe andalso xe<Int.max(x,xk)))
                |threat Knight=(Int.abs(x-xk)=2 andalso Int.abs(y-yk)=1)orelse(Int.abs(x-xk)=1 andalso Int.abs(y-yk)=2)
                |threat Pawn=Int.abs(x-xk)=1 andalso(case c of Black=>yk=y+1|White=>yk=y-1)
          in threat k end
        fun any xs=case L.force xs of S.Nil=>false|S.Cons(x,rest)=>givesCheck(L.force x)orelse any rest
    in any(forcesColoured(opponent c)bd)end
  fun tryMove c(k,sq)(m as Move(sq',captured,promotion))bd=
    let val p=(c,k)val bd1=rmPieceAt c sq bd
        val p'=case promotion of NONE=>p|SOME p=>p
        val bd2=putPieceAt sq' p'(case captured of NONE=>bd1|SOME _=>rmPieceAt(opponent c)sq' bd1)
    in if not(kingincheck c bd2)then SOME(MoveInFull(p,sq,m),bd2)else NONE end
  fun moveLine bd c sq inc cont=
    let fun loop at ms=let val next=inc at
          in if onboard next then case pieceAt bd next of NONE=>loop next(Move(next,NONE,NONE)::ms)
            |SOME p=>if colourOf p<>c then cont(Move(next,SOME p,NONE)::ms)else cont ms
          else cont ms end
    in loop sq end
  fun bishopmoves c sq bd=moveLine bd c sq(fn(x,y)=>(x-1,y+1))
    (moveLine bd c sq(fn(x,y)=>(x+1,y+1))
    (moveLine bd c sq(fn(x,y)=>(x-1,y-1))
    (moveLine bd c sq(fn(x,y)=>(x+1,y-1))(fn x=>x))))[]
  fun rookmoves c sq bd=moveLine bd c sq(fn(x,y)=>(x-1,y))
    (moveLine bd c sq(fn(x,y)=>(x+1,y))
    (moveLine bd c sq(fn(x,y)=>(x,y-1))
    (moveLine bd c sq(fn(x,y)=>(x,y+1))(fn x=>x))))[]
  fun sift c bd ms []=ms
    |sift c bd ms(sq::rest)=if onboard sq then case pieceAt bd sq of
       NONE=>sift c bd(Move(sq,NONE,NONE)::ms)rest
      |SOME p=>if colourOf p=c then sift c bd ms rest else sift c bd(Move(sq,SOME p,NONE)::ms)rest
      else sift c bd ms rest
  fun kingmoves c(p,q)bd=sift c bd[][(p-1,q+1),(p,q+1),(p+1,q+1),(p-1,q),(p+1,q),(p-1,q-1),(p,q-1),(p+1,q-1)]
  fun knightmoves c(p,q)bd=sift c bd[][(p-1,q+2),(p+1,q+2),(p-2,q+1),(p+2,q+1),(p-2,q-1),(p+2,q-1),(p-1,q-2),(p+1,q-2)]
  fun pawnmoves c(p,q)bd=
    let val fwd=case c of White=>1|Black=> ~1
        fun promote(sq as(x,y))captured=if(c=Black andalso y=1)orelse(c=White andalso y=8)
          then List.map(fn k=>Move(sq,captured,SOME(c,k)))[Queen,Rook,Bishop,Knight]
          else[Move(sq,captured,NONE)]
        val ordinary=L.delay(fn()=>if pieceAt bd(p,q+fwd)=NONE then
          promote(p,q+fwd)NONE@(if((q=2 andalso c=White)orelse(q=7 andalso c=Black))andalso
            pieceAt bd(p,q+2*fwd)=NONE then[Move((p,q+2*fwd),NONE,NONE)]else[])else[])
        val captures=L.delay(fn()=>List.concat(List.map(fn sq=>case pieceAt bd sq of
          SOME p=>if colourOf p<>c then promote sq(SOME p)else[]|NONE=>[])[(p+1,q+fwd),(p-1,q+fwd)]))
    in S.append(L.delay(fn()=>L.force(S.fromList(L.force ordinary))))
       (L.delay(fn()=>L.force(S.fromList(L.force captures))))end
  fun rawmoves c(k,sq)bd=case k of
    King=>S.fromList(kingmoves c sq bd)|Knight=>S.fromList(knightmoves c sq bd)
    |Bishop=>S.fromList(bishopmoves c sq bd)|Rook=>S.fromList(rookmoves c sq bd)
    |Queen=>S.append(L.delay(fn()=>L.force(S.fromList(bishopmoves c sq bd))))
      (L.delay(fn()=>L.force(S.fromList(rookmoves c sq bd))))
    |Pawn=>pawnmoves c sq bd
  fun moveDetailsFor c bd=L.delay(fn()=>
    let val stream=S.concatMap(fn ksq=>S.concatMap(fn m=>case tryMove c ksq m bd of
          NONE=>S.empty()|SOME detail=>S.singleton detail)(rawmoves c ksq bd))(forcesColoured c bd)
    in if P.eagerMoves then L.force(S.fromList(rev(S.foldl(fn(x,xs)=>x::xs)[]stream)))else L.force stream end)
end
