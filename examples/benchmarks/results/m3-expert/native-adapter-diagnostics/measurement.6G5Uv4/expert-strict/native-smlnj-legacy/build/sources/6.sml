functor BenchExpertFn(P:sig val eagerTerms:bool end)=
struct
  structure K=BenchExpertPhraseFn(P)
  open K
  datatype solution=Soln of phrase table*string S.stream|Question of string
  fun freshCopy(Soln(env,vs))p=
        let val names=vars p val n=S.foldl(fn(_,n)=>n+1)0 names
            val changes=S.zipWith(fn(x,v)=>(L.delay(fn()=>x),L.delay(fn()=>variable v)))names(take n vs)
            val tab=updateList(newTable())changes
        in(Soln(env,drop n vs),subst tab p)end
    |freshCopy _ _=raise Match
  fun singleton x=S.singleton x
  fun children p=let val ps=args p in(S.nth ps 0,S.nth ps 1)end
  fun solve db(Question q)g=singleton(Question q)
    |solve(db as(defs,info))(soln as Soln(env,vs))g=L.delay(fn()=>
      case L.force g of Term("or",_)=>
          let val(a,b)=children g in L.force(S.append(solve db soln a)(solve db soln b))end
       |Term("and",_)=>let val(a,b)=children g
           in L.force(S.concatMap(fn result=>solve db result b)(solve db soln a))end
       |_=>let val rules=relevant defs g
           in case L.force rules of S.Nil=>L.force(ask info soln g)
             |_=>L.force(lookUp db soln g rules)end)
  and lookUp db soln g rules=S.concatMap(fn(soln',rule')=>try db soln' g rule')
      (S.map(freshCopy soln)rules)
  and try db(Soln(env,vs))g rule=
        let val(pattern,newgoal)=children rule
        in case match env g pattern of Reason _=>S.empty()
          |Answer next=>solve db(Soln(next,vs))newgoal end
    |try _ _ _ _=raise Match
  and ask info(Soln(env,vs))g=
        let val sp=L.delay(fn()=>showPhrase(subst env g))
        in S.cons(L.delay(fn()=>Question(L.force sp)),L.delay(fn()=>
          case L.force(find info(L.force sp))of Reason _=>raise Match
            |Answer ans=>L.force(if L.force ans then singleton(Soln(env,vs))else S.empty())))end
    |ask _ _ _=raise Match
  fun strip seen results=L.delay(fn()=>case L.force results of S.Nil=>S.Nil
    |S.Cons(x,rest)=>case L.force x of Question q=>
       if List.exists(fn old=>old=q)seen then L.force(strip seen rest)
       else S.Cons(x,strip(q::seen)rest)
      |_=>S.Cons(x,strip seen rest))
  fun text s=S.fromList(String.explode s)
  fun showVars env names=
    let val strings=S.map(fn name=>name^" = "^showPhrase(subst env(variable name)))names
        fun join xs=case L.force xs of S.Nil=>raise EmptyList
          |S.Cons(x,rest)=>case L.force rest of S.Nil=>L.force x
            |_=>L.force x^"; "^join rest
    in join strings end
  fun display results names answers=L.delay(fn()=>case L.force results of
      S.Nil=>L.force(text "No (more) solutions\n")
    |S.Cons(x,rest)=>case L.force x of Question q=>L.force(S.append
       (text("Is it true that "^q^"?\n"))
       (L.delay(fn()=>L.force(display rest names(S.tail answers)))))
      |Soln(env,_)=>L.force(S.append(text("Solution: "^showVars env names^". More?\n"))
         (L.delay(fn()=>case L.force answers of S.Nil=>S.Nil
           |S.Cons(a,tail)=>if L.force a then L.force(display rest names tail)else S.Nil))))
  fun lines value=
    let val n=String.size value
        fun loop start=L.delay(fn()=>if start>=n then S.Nil else
          let fun finish i=if i=n orelse String.sub(value,i)= #"\n"then i else finish(i+1)
              val stop=finish start
          in S.Cons(L.delay(fn()=>String.substring(value,start,stop-start)),loop(stop+1))end)
    in loop 0 end
  fun names n=S.cons(L.delay(fn()=>"X"^Int.toString n),L.delay(fn()=>L.force(names(n+1))))
  fun charLines input=L.delay(fn()=>case L.force input of S.Nil=>S.Nil
    |_=>let val(line,remaining)=S.span(fn c=>c<> #"\n")input
            val value=L.delay(fn()=>String.implode(rev(S.foldl(fn(c,cs)=>c::cs)[]line)))
            val rest=L.delay(fn()=>case L.force remaining of S.Nil=>S.Nil
               |S.Cons(_,tail)=>L.force(charLines tail))
        in S.Cons(value,rest)end)
  fun process contents input=
    let val rows=lines contents
        val problem=L.delay(fn()=>L.force(goal(String.tokens Char.isSpace(S.head rows))))
        val defs=definitions(S.tail rows)
        val replies=S.map(fn line=>String.tokens Char.isSpace line<>["no"])(charLines input)
        val resultsHolder=ref NONE
        val results=L.delay(fn()=>L.force(valOf(!resultsHolder)))
        fun information results replies=L.delay(fn()=>case L.force results of S.Nil=>S.Nil
          |S.Cons(result,rest)=>case L.force replies of S.Nil=>S.Nil
            |S.Cons(answer,tail)=>case L.force result of Question q=>
                S.Cons(L.delay(fn()=>(L.delay(fn()=>q),answer)),information rest tail)
              |_=>L.force(information rest tail))
        val entries=information results replies
        val info=enterList(newTable())entries
        val body=strip[](solve(defs,info)(Soln(newTable(),names 0))problem)
        val _=resultsHolder:=SOME body
    in S.append(L.delay(fn()=>L.force(text("Solving: "^showPhrase problem^"\n"))))
        (display results(vars problem)replies)end
  fun processText contents input=process contents(text input)
end
