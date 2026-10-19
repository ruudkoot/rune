(* Mark P. Jones's Mini Prolog, November 1990. Portable translation of the
   nofib application; original files and historical notes are retained. *)
functor BenchPrologFn(D:BENCH_SUSPEND) =
struct
  structure S=BenchStream
  structure L=BenchLazy
  structure P=BenchPrologParse
  type id=int*string
  datatype node=Var of id|Struct of string*term S.stream
  withtype term=node D.t
  datatype clause=Clause of term*term S.stream
  type database=(string*clause list)list
  type substitution=id->term
  fun variable id=D.delay(fn()=>Var id)
  fun structureTerm name args=D.delay(fn()=>
    let val _=D.delay(fn()=>S.foldl(fn(t,())=>(D.force t;()))()args)
    in Struct(name,args)end)
  fun equal(a,b)=case(D.force a,D.force b)of
      (Var x,Var y)=>x=y
    |(Struct(x,xs),Struct(y,ys))=>x=y andalso equalList xs ys
    |_=>false
  and equalList xs ys=case(L.force xs,L.force ys)of
      (S.Nil,S.Nil)=>true
    |(S.Cons(x,xr),S.Cons(y,yr))=>equal(L.force x,L.force y)andalso equalList xr yr
    |_=>false
  fun member x values=case L.force values of S.Nil=>false
    |S.Cons(y,rest)=>x=L.force y orelse member x rest
  fun nub values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
    |S.Cons(x,rest)=>S.Cons(x,nub(S.filter(fn y=>y<>L.force x)rest)))
  fun varsIn value=L.delay(fn()=>L.force(case D.force value of
      Var x=>S.singleton x|Struct(_,args)=>nub(S.concatMap varsIn args)))
  fun rename level value=D.delay(fn()=>case D.force value of
      Var(_,name)=>Var(level,name)
    |Struct(name,args)=>D.force(structureTerm name(S.map(rename level)args)))
  val emptyDb:database=[]
  fun clausesFor(name:string)(db:database)=case db of []=>[]
    |(key,clauses)::rest=>if key<name then clausesFor name rest
      else if name=key then clauses else[]
  fun addClause db (clause as Clause(head,_))=
    case D.force head of Var _=>raise Match
    |Struct(name,_)=>
      let fun update []=[(name,[clause])]
            |update((entry as(key,clauses))::rest)=
              if key=name then(key,clauses@[clause])::rest
              else if key<name then entry::update rest
              else(name,[clause])::entry::rest
      in update db end
  fun renamed db level goal=L.delay(fn()=>L.force(case D.force goal of Var _=>S.empty()
    |Struct(name,_)=>S.map(fn Clause(head,body)=>
      Clause(rename level head,S.map(rename level)body))(S.fromList(clausesFor name db))))
  fun apply substitution value=D.delay(fn()=>case D.force value of
      Var x=>D.force(substitution x)
    |Struct(name,args)=>D.force(structureTerm name(S.map(apply substitution)args)))
  val nullSubst:substitution=variable
  fun bind id value other=D.delay(fn()=>D.force(if other=id then value else variable other))
  fun compose a b id=D.delay(fn()=>D.force(apply a(b id)))
  fun unify a b=L.delay(fn()=>L.force(case(D.force a,D.force b)of
      (Var x,Var y)=>S.singleton(if x=y then nullSubst else bind x(variable y))
    |(Var x,_)=>if member x(varsIn b)then S.empty()else S.singleton(bind x b)
    |(_,Var y)=>if member y(varsIn a)then S.empty()else S.singleton(bind y a)
    |(Struct(x,xs),Struct(y,ys))=>if x=y then listUnify xs ys else S.empty()))
  and listUnify xs ys=L.delay(fn()=>L.force(case(L.force xs,L.force ys)of
      (S.Nil,S.Nil)=>S.singleton nullSubst
    |(S.Cons(x,xr),S.Cons(y,yr))=>S.concatMap(fn first=>
        S.map(fn second=>compose second first)
          (listUnify(S.map(apply first)xr)(S.map(apply first)yr)))
        (unify(L.force x)(L.force y))
    |_=>S.empty()))
  val theCut=structureTerm "!"(S.empty())
  fun alternatives db level goal=S.concatMap(fn Clause(head,body)=>
    S.map(fn substitution=>(body,substitution))(unify goal head))(renamed db level goal)
  fun cut stack=case stack of top::(s,goals,_)::rest=>top::(s,goals,S.empty())::rest|_=>stack
  fun proveStack db goals=
    let fun solve level substitution goals stack=L.delay(fn()=>case L.force goals of
          S.Nil=>S.Cons(L.delay(fn()=>substitution),backtrack level stack)
        |S.Cons(goal,rest)=>if equal(L.force goal,theCut)then L.force(solve level substitution rest(cut stack))
          else L.force(choose level substitution rest(alternatives db level(apply substitution(L.force goal)))stack))
        and choose level substitution rest options stack=L.delay(fn()=>case L.force options of
          S.Nil=>L.force(backtrack level stack)
        |S.Cons(option,tail)=>let val(body,unifier)=L.force option
          in L.force(solve(level+1)(compose unifier substitution)
            (S.append body rest)((substitution,rest,tail)::stack))end)
        and backtrack level stack=L.delay(fn()=>case stack of []=>S.Nil
          |(substitution,goals,options)::rest=>L.force(choose(level-1)substitution goals options rest))
    in solve 1 nullSubst goals[]end
  datatype proofNode=Done of substitution|Choice of proofNode L.delay S.stream
  fun proofTree db level substitution goals=L.delay(fn()=>case L.force goals of
      S.Nil=>Done substitution
    |S.Cons(goal,rest)=>Choice(S.concatMap(fn Clause(head,body)=>
       S.map(fn unifier=>proofTree db(level+1)(compose unifier substitution)
         (S.map(apply unifier)(S.append body rest)))(unify(L.force goal)head))
       (renamed db level(L.force goal))))
  fun search tree=L.delay(fn()=>L.force(case L.force tree of Done s=>S.singleton s
    |Choice children=>S.concatMap search children))
  fun proveTree db goals=search(proofTree db 1 nullSubst goals)
  (* Difference-list printers retain the source higher-order ShowS consumer. *)
  fun writeText text tail=S.append(S.fromList(String.explode text))tail
  fun showTermS value tail=L.delay(fn()=>L.force(case D.force value of
      Var(level,name)=>writeText name
        (if level=0 then tail else writeText("_"^Int.toString level)tail)
    |Struct(name,args)=>case L.force args of S.Nil=>writeText name tail
      |_=>writeText name(writeText"("(showWithSep "," args(writeText")"tail)))))
  and showWithSep separator values tail=L.delay(fn()=>case L.force values of
      S.Nil=>raise Match
    |S.Cons(first,rest)=>L.force(showTermS(L.force first)
      (case L.force rest of S.Nil=>tail|_=>writeText separator(showWithSep separator rest tail))))
  fun showClauseS(Clause(head,goals))tail=
    showTermS head(case L.force goals of S.Nil=>writeText"."tail
      |_=>writeText":=="(showWithSep "," goals(writeText"."tail)))
  fun showDbS db tail=
    let fun clauses [] tail=raise Empty
          |clauses(first::rest)tail=showClauseS first(writeText"\n"
            (if List.null rest then tail else clauses rest tail))
        fun groups [] tail=writeText"-- Empty Database --\n"tail
          |groups[(_,rs)]tail=clauses rs tail
          |groups((_,rs)::rest)tail=clauses rs(writeText"\n"(groups rest tail))
    in groups db tail end
  fun textOf chars=String.implode(List.rev(S.foldl(fn(c,cs)=>c::cs)[]chars))
  fun showTerm value=textOf(showTermS value(S.empty()))
  fun showClause value=textOf(showClauseS value(S.empty()))
  fun showDb db=textOf(showDbS db(S.empty()))
  fun letter input=P.satisfy(fn c=>Char.isAlpha c orelse Char.isDigit c orelse
    List.exists(fn x=>x=c)(String.explode ":;+=-*&%$#@?/.~!"))input
  fun parseVariable input=P.map(P.sequence(P.satisfy Char.isUpper)(P.many letter))
    (fn(initial,rest)=>variable(0,String.implode(initial::rest)))input
  fun parseTerm input=P.space(P.alternative parseVariable parseStruct)input
  and parseTermList input=P.listOf parseTerm(P.spaceToken ",")input
  and parseStruct input=
    P.map(P.sequence(P.many letter)
      (P.alternative
        (P.map(P.sequence(P.spaceToken "(")(P.sequence parseTermList(P.spaceToken ")")))
          (fn(_,(terms,_))=>terms))
        (P.okay[])))
      (fn(name,args)=>structureTerm(String.implode name)(S.fromList args))input
  fun parseClause input=
    P.map(P.sequence(P.space parseStruct)
      (P.sequence(P.alternative
        (P.map(P.sequence(P.spaceToken ":==")(P.listOf parseTerm(P.spaceToken ",")))(fn(_,body)=>body))
        (P.okay[]))(P.spaceToken ".")))
      (fn(head,(body,_))=>Clause(head,S.fromList body))input
  datatype command=Fact of clause|Query of term S.stream|Show|Error|Quit|NoChange
  fun command input=
    P.alternative
      (P.map(P.just(P.alternative(P.spaceToken "bye")(P.spaceToken "quit")))(fn _=>Quit))
      (P.alternative(P.just(P.okay NoChange))
        (P.alternative(P.map(P.just(P.spaceToken "??"))(fn _=>Show))
          (P.alternative(P.map(P.just parseClause)Fact)
            (P.alternative
              (P.map(P.just(P.sequence(P.spaceToken "?-")parseTermList))(fn(_,terms)=>Query(S.fromList terms)))
              (P.okay Error)))))input
  fun readLibrary text=
    let val rows=String.tokens(fn c=>c= #"\n")text
        fun parsed row=case L.force(parseClause(String.explode row))of
          S.Cons(value,_)=>let val(clause,rest)=L.force value
            in if List.null rest then SOME clause else NONE end
          |S.Nil=>NONE
    in List.mapPartial parsed rows end
  fun rubout c=c=Char.chr 127 orelse c=Char.chr 8
  fun lineOut input=
    let fun loop n []=[]
          |loop n(c::cs)=if n>0 andalso rubout c then #"\b":: #" ":: #"\b"::loop(n-1)cs
            else if n=0 andalso rubout c then loop 0 cs
            else c::loop(n+1)cs
    in loop 0 input end
  fun noBackSpaces input=
    let fun delete n []=[]
          |delete n(c::cs)=if rubout c then delete(n+1)cs
            else if n>0 then delete(n-1)cs else c::delete 0 cs
    in List.rev(delete 0(List.rev input))end
  fun solutions variables substitution=S.concatMap(fn id=>
    let val value=substitution id
    in if equal(value,variable id)then S.empty()
       else S.singleton(showTermS(variable id)(writeText" = "(showTermS value(S.empty()))))end)variables
  fun joinRows rows tail=L.delay(fn()=>case L.force rows of S.Nil=>raise Empty
    |S.Cons(first,rest)=>L.force(S.append(L.force first)
      (case L.force rest of S.Nil=>tail|_=>writeText"\n"(joinRows rest tail))))
  fun interactive prove db input=
    let
      fun loop db input=L.delay(fn()=>
        let val _=if List.null input then raise Empty else()
            fun split []=([],[])
              |split(#"\n"::rest)=([],rest)
              |split(c::rest)=let val(line,tail)=split rest in(c::line,tail)end
            val(line,tail)=split input
            val cmd= #1(S.head(command(noBackSpaces line)))
        in L.force(S.append(S.fromList(#">":: #" "::lineOut line@[#"\n"]))(exec db cmd tail))end)
      and exec db cmd input=case cmd of
          Fact clause=>loop(addClause db clause)input
        |Query goals=>demonstrate db goals input
        |Show=>showDbS db(loop db input)
        |Error=>S.append(S.fromList(String.explode "I don't understand\n"))(loop db input)
        |Quit=>S.fromList(String.explode "Thank you and goodbye\n")
        |NoChange=>loop db input
      and demonstrate db goals input=
        let val variables=nub(S.concatMap varsIn goals)
            val bindings=S.map(solutions variables)(prove db goals)
            fun output bindings input=L.delay(fn()=>case L.force bindings of
                S.Nil=>L.force(S.append(S.fromList(String.explode "no.\n"))(loop db input))
              |S.Cons(first,rest)=>case L.force(L.force first)of
                  S.Nil=>L.force(writeText"yes.\n"(loop db input))
                |_=>L.force(joinRows(L.force first)(writeText" "(next rest input))))
            and next bindings input=L.delay(fn()=>case input of []=>S.Nil
              |c::rest=>if c= #";"then L.force(S.append(S.fromList[String.sub(";",0),#"\n"])(output bindings rest))
                else L.force(S.append(S.singleton #"\n")(loop db rest)))
        in output bindings input end
    in loop db input end

  fun setup text=List.foldl(fn(clause,db)=>addClause db clause)emptyDb(readLibrary text)
  fun runChars tree db input=interactive(if tree then proveTree else proveStack)db input
  fun runText tree db input=runChars tree db(String.explode input)
end
