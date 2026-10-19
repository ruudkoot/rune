(* nofib grep: ordered parsers and epsilon-compressed, cyclic NFA producers. *)
functor BenchGrepFn(D : BENCH_SUSPEND) =
struct
 structure P=BenchGrepParsersFn(D)
 structure Q=P.Q
 structure L=BenchLazy
 datatype node = NFAChar of int * node L.delay | NFAAny of node L.delay
   | NFAEps of node L.delay Q.sequence | NFAEnd of node L.delay | NFAFinal
   | NFATable of (int * node L.delay) Q.sequence * node L.delay Q.sequence * node L.delay Q.sequence * bool
 type producer = node L.delay -> node L.delay
 val finalNode=L.delay(fn()=>NFAFinal)
 fun singleton x=P.singleton x
 fun fix builder =
   let val cell=ref(L.Pending(fn()=>raise Fail "uninitialized NFA knot"))
       val _=cell:=L.Pending(fn()=>L.force(builder cell))
   in cell end
 fun epsClosure states=D.delay(fn()=>case D.force states of Q.Nil=>Q.Nil
   | Q.Cons(n,rest)=>case L.force(D.force n)of
       NFAEps next=>D.force(epsClosure(Q.append next rest))
     | _=>Q.Cons(n,epsClosure rest))
 fun mkTable pairs anys ends final states = case D.force states of
     Q.Nil=>NFATable(pairs,anys,ends,final)
   | Q.Cons(n,rest)=>case L.force(D.force n)of
       NFAChar(c,next)=>mkTable(Q.cons(Q.value(c,next))pairs)anys ends final rest
     | NFAAny next=>mkTable pairs(Q.cons(Q.value next)anys)ends final rest
     | NFATable(pairs',anys',ends',final')=>mkTable(Q.append pairs' pairs)
         (Q.append anys' anys)(Q.append ends' ends)(final' orelse final)rest
     | NFAEnd next=>mkTable pairs anys(Q.cons(Q.value next)ends)final rest
     | NFAFinal=>mkTable pairs anys ends true rest
     | _=>raise Fail "illegal argument to mkTable"
 fun nfaEps states=L.delay(fn()=>mkTable(Q.empty())(Q.empty())(Q.empty())false(epsClosure states))
 fun nfaChar c next=L.delay(fn()=>NFAChar(c,next))
 fun nfaAny next=L.delay(fn()=>NFAAny next)
 fun nfaEnd next=L.delay(fn()=>NFAEnd next)
 fun star at final=
   let val initial=fix(fn self=>at(nfaEps(Q.fromList[final,self])))
   in nfaEps(Q.fromList[initial,final])end
 fun plus at final=
   let val initial=fix(fn self=>at(nfaEps(Q.fromList[final,self])))
   in nfaEps(singleton initial)end
 fun optional at final=
   let val initial=at(nfaEps(singleton final))
   in nfaEps(Q.fromList[final,initial])end
 fun compose (f:producer) (g:producer) final=f(g final)
 fun combine f g final=nfaEps(Q.fromList[f final,g final])
 infixr 8 thenP rightP leftP
 infix 7 usingP
 infixr 6 orP
 fun op thenP (first,second)=P.thn first second
 fun op rightP (first,second)=P.xthn first second
 fun op leftP (first,second)=P.thnx first second
 fun op usingP (first,second)=P.using first second
 fun op orP (first,second)=P.alt first second
 fun lit c=P.literal(Char.ord c)
 val anyC : int P.parser = P.satisfy(fn _=>true)
 fun butC chars=P.satisfy(fn c=>not(List.exists(fn x=>Char.ord x=c)(String.explode chars)))
 fun atom tokens=(
       lit #"\\" rightP lit #"(" rightP regexp leftP lit #"\\" leftP lit #")"
   orP lit #"\\" rightP butC "|()" usingP nfaChar
   orP lit #"." usingP(fn _=>nfaAny)
   orP butC "\\.$" usingP nfaChar
   orP P.followedBy(lit #"$")anyC usingP nfaChar)tokens
 and extended tokens=(atom thenP P.opt(
       lit #"*" usingP(fn _=>star)
   orP lit #"+" usingP(fn _=>plus)
   orP lit #"?" usingP(fn _=>optional))usingP
     (fn(at,[])=>at |(at,[modify])=>modify at | _=>raise Fail "invalid optional quantifier"))tokens
 and factor tokens=(P.plus extended usingP
     List.foldr(fn(f,g)=>compose f g)(fn final=>final))tokens
 and regexp tokens=(factor thenP P.rpt(lit #"\\" rightP lit #"|" rightP factor)
     thenP P.opt(lit #"$")usingP
       (fn(first,(others,anchor))=>
         let val result=List.foldl(fn(next,acc)=>combine acc next)first others
         in if List.null anchor then result else compose result nfaEnd end))tokens
 fun compile chars = let val(producer,_)=Q.head(regexp chars)in producer end
 fun matching pairs c=D.delay(fn()=>case D.force pairs of Q.Nil=>Q.Nil
   | Q.Cons(pair,rest)=>let val(key,next)=D.force pair
       in if key=c then Q.Cons(Q.value next,matching rest c)else D.force(matching rest c)end)
 fun step node c=case L.force node of
     NFAChar(key,next)=>if key=c then singleton next else Q.empty()
   | NFAAny next=>singleton next
   | NFATable(pairs,anys,_,_)=>Q.append(matching pairs c)anys
   | _=>Q.empty()
 fun endStep node=case L.force node of
     NFAEnd next=>singleton next
   | NFAFinal=>singleton node
   | NFATable(_,_,_,true)=>singleton finalNode
   | NFATable(_,_,ends,false)=>ends
   | _=>Q.empty()
 fun run states []=(case D.force(P.bind states endStep)of Q.Nil=>false | _=>true)
   | run states(c::rest)=run(P.bind states(fn state=>step state c))rest
 fun accept producer subject=run(singleton(producer finalNode))subject
end
