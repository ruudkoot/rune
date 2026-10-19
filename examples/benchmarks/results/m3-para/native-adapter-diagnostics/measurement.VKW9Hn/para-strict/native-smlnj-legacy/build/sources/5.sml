(* Oege de Moor and Jeremy Gibbons, paragraph formatting, 1995--1999.
   The linear-time par3 and symmetric-list representation are retained. *)
functor BenchParaFn(D:BENCH_SUSPEND) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  datatype candidate=P of int D.t*int D.t*int D.t
  type 'a symmetric='a S.stream*'a S.stream
  datatype state=State of candidate symmetric D.t*int D.t*int D.t
  fun number n=D.delay(fn()=>n)
  fun widthTail(P(w,_,_))=D.force w
  fun costTail(P(_,c,_))=D.force c
  fun lengthTail(P(_,_,n))=D.force n
  fun null xs=case L.force xs of S.Nil=>true|_=>false
  fun single xs=case L.force xs of S.Cons(_,rest)=>null rest|_=>false
  fun count xs=S.foldl(fn(_,n)=>n+1)0 xs
  fun reverse xs=S.foldl(fn(x,ys)=>S.cons(L.delay(fn()=>x),ys))(S.empty())xs
  fun take n xs=L.delay(fn()=>if n=0 then S.Nil else case L.force xs of S.Nil=>S.Nil
      |S.Cons(x,rest)=>S.Cons(x,take(n-1)rest))
  fun drop n xs=if n<=0 then xs else case L.force xs of S.Nil=>S.empty()
      |S.Cons(_,rest)=>drop(n-1)rest
  fun nullSym(x,y)=null x andalso null y
  fun singleSym(x,y)=(null x andalso single y)orelse(single x andalso null y)
  fun headSym(x,y)=if not(null x)then S.head x else S.head y
  fun lastSym(y,x)=if not(null x)then S.head x else S.head y
  fun consSym a(x,y)=if not(null y)then(S.cons(L.delay(fn()=>a),x),y)
    else(S.singleton a,x)
  fun tailSym(x,y)=if null x then(S.empty(),S.empty())
    else if single x then
      let val n=count y div 2 in(reverse(drop n y),take n y)end
    else(S.tail x,y)
  fun initSym(y,x)=if null x then(S.empty(),S.empty())
    else if single x then
      let val n=count y div 2 in(take n y,reverse(drop n y))end
    else(y,S.tail x)
  fun start w=if w<=70 then State(D.delay(fn()=>consSym(P(number 0,number 0,number 0))
        (S.empty(),S.empty())),number w,number 1)
    else raise Fail "source paragraph contains an overlong final word"
  fun step w(State(ps,tw,tl))=
    let val totalWidth=D.delay(fn()=>w+1+D.force tw)
        val totalLength=D.delay(fn()=>1+D.force tl)
        fun single p=lengthTail p=0
        fun widthHead p=if single p then D.force totalWidth
          else D.force totalWidth-widthTail p-1
        fun cost p=if single p then 0 else
          let val d=63-widthHead p in costTail p+d*d end
        fun oldWidth p=if single p then D.force tw else D.force tw-widthTail p-1
        fun new p=if single p then P(tw,number 0,tl)else
          P(tw,D.delay(fn()=>let val d=63-oldWidth p in costTail p+d*d end),tl)
        fun bf p q=
          let val wph=L.delay(fn()=>widthHead p)
              val wqh=L.delay(fn()=>widthHead q)
              val rqh=L.delay(fn()=>70-L.force wqh+1)
          in if single q andalso costTail p=0 then Int.min(63-L.force wph,L.force rqh)
             else if single q then L.force rqh
             else Int.min((cost p-cost q+2*(L.force wqh-L.force wph)-1)
                  div(2*(L.force wqh-L.force wph)),L.force rqh)end
        fun add p queue=if singleSym queue orelse nullSym queue then consSym p queue
          else let val rest=L.delay(fn()=>tailSym queue)
                   val q=L.delay(fn()=>headSym queue)
                   val r=L.delay(fn()=>headSym(L.force rest))
               in if bf p(L.force q)<=bf(L.force q)(L.force r)
                  then add p(L.force rest)else consSym p queue end
        fun nofit queue=if nullSym queue then queue
          else if widthHead(lastSym queue)>70 then nofit(initSym queue)else queue
        fun trim queue=if nullSym queue orelse singleSym queue then queue
          else let val prefix=L.delay(fn()=>initSym queue)
               in if cost(lastSym(L.force prefix))<=cost(lastSym queue)
                  then trim(L.force prefix)else queue end
    in State(D.delay(fn()=>trim(nofit(add(new(lastSym(D.force ps)))(D.force ps)))),
       totalWidth,totalLength)end
  fun scan1 f g xs=L.delay(fn()=>case L.force xs of S.Nil=>raise Empty
    |S.Cons(x,rest)=>if null rest then S.Cons(L.delay(fn()=>g(L.force x)),S.empty())
      else let val states=scan1 f g rest
           in S.Cons(L.delay(fn()=>f(L.force x)(S.head states)),states)end)
  fun stateLength(State(_,_,n))=D.force n
  fun stateTailLength(State(ps,_,_))=lengthTail(lastSym(D.force ps))
  fun tile words lengths n=L.delay(fn()=>case L.force lengths of S.Nil=>S.Nil
    |S.Cons(m,rest)=>
      let val first=L.force m val len=n-first
      in S.Cons(L.delay(fn()=>take len words),tile(drop len words)(drop len lengths)first)end)
  fun paragraph words=
    let val states=scan1 step start(S.map count words)
        val lengths=S.map stateTailLength states
    in tile words lengths(stateLength(S.head states))end
  fun fold1 f g xs=L.delay(fn()=>case L.force xs of S.Nil=>raise Empty
    |S.Cons(x,rest)=>if null rest then L.force(g(L.force x))
      else L.force(f(L.force x)(fold1 f g rest)))
  (* Source format/unformat preserve right-fold grouping and separators. *)
  fun format equal separator xs=
    let fun split b groups=if equal(separator,b)then S.cons(L.delay S.empty,groups)
          else S.cons(L.delay(fn()=>S.cons(L.delay(fn()=>b),S.head groups)),
               L.delay(fn()=>L.force(S.tail groups)))
        fun final b=split b(S.singleton(S.empty()))
    in if null xs then S.singleton(S.empty())else fold1 split final xs end
  fun unformat separator xs=fold1(fn first=>fn rest=>
       S.append first(S.cons(L.delay(fn()=>separator),rest)))(fn last=>last)xs
  fun chars text=S.fromList(String.explode text)
  fun lines xs=L.delay(fn()=>case L.force xs of S.Nil=>S.Nil|_=>
    let val(prefix,suffix)=S.span(fn c=>c<> #"\n")xs
        val rest=L.delay(fn()=>case L.force suffix of S.Nil=>S.Nil
           |S.Cons(_,tail)=>L.force(lines tail))
    in S.Cons(L.delay(fn()=>prefix),rest)end)
  fun words xs=L.delay(fn()=>
    let val start=S.dropWhile Char.isSpace xs
    in case L.force start of S.Nil=>S.Nil|_=>
      let val(word,rest)=S.span(fn c=>not(Char.isSpace c))start
      in S.Cons(L.delay(fn()=>word),words rest)end end)
  fun parse text=
    S.filter(fn group=>not(null group))
      (format(fn(a,b)=>null a andalso null b)(S.empty())
        (S.map words(lines text)))
  fun unparse paragraphs=
    let val rows=unformat(S.empty())paragraphs
        fun line ws=if null ws then S.empty()else unformat #" " ws
    in S.concatMap(fn row=>S.append(line row)(S.singleton #"\n"))rows end
  fun formatText text=
    if null text then S.empty()else
      unparse(S.map(fn group=>paragraph(S.concatMap(fn row=>row)group))(parse text))
end
