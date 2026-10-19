functor BenchExpertPhraseFn(P:sig val eagerTerms:bool end)=
struct
  structure Table=BenchExpertTable
  exception EmptyList=Empty
  open Table
  datatype phraseNode=Term of string*phraseNode L.delay S.stream|Var of string
  type phrase=phraseNode L.delay
  fun materialize xs=S.fromList(rev(S.foldl(fn(x,rest)=>(L.force x;x::rest))[]xs))
  fun term word children=L.delay(fn()=>Term(word,if P.eagerTerms then materialize children else children))
  fun variable name=L.delay(fn()=>Var name)
  fun nub xs=
    let fun loop seen xs=L.delay(fn()=>case L.force xs of S.Nil=>S.Nil
          |S.Cons(x,rest)=>let val name=L.force x
            in if List.exists(fn old=>old=name)seen then L.force(loop seen rest)
              else S.Cons(x,loop(name::seen)rest)end)
    in loop[]xs end
  fun vars phrase=
    let fun names p=L.delay(fn()=>case L.force p of Var x=>L.force(S.singleton x)
          |Term(_,ps)=>L.force(S.concatMap names ps))
    in nub(names phrase)end
  fun showPhrase p=case L.force p of Var x=>x|Term(word,children)=>
    case L.force children of S.Nil=>word|S.Cons(a,rest)=>
      (case L.force rest of S.Cons(b,tail)=>
        (case L.force tail of S.Nil=>showPhrase(L.force a)^" "^word^" "^showPhrase(L.force b)|_=>raise Match)
       |_=>raise Match)
  fun list xs=S.fromList xs
  fun split words f word g=
    let fun left []=[]|left(x::xs)=if x=word then[]else x::left xs
        fun right []=raise EmptyList|right(x::xs)=if x=word then xs else right xs
    in term word(list[L.delay(fn()=>L.force(f(left words))),L.delay(fn()=>L.force(g(right words)))])end
  fun noun [a,x]=if List.exists(fn s=>s=a)["a","an","the"]then noun[a^" "^x]else raise Match
    |noun[x]=if String.size x>0 andalso #"A"<=String.sub(x,0)andalso String.sub(x,0)<= #"Z"
       then variable x else term x(S.empty())
    |noun _=raise Match
  fun relation words=
    let val verb=hd(List.filter(fn word=>List.exists(fn v=>v=word)["is","describes","has","can","eats"])words)
    in split words noun verb noun end
  fun goal words=if List.exists(fn w=>w="or")words then split words goal "or"goal
    else if List.exists(fn w=>w="and")words then split words goal "and"goal else relation words
  fun rule words=split words relation "if"goal
  fun args p=case L.force p of Term(_,children)=>children|_=>raise Match
  fun verb p=case L.force(S.head(args p))of Term(v,_)=>v|_=>raise Match
  fun definitions lines=
    let val rules=S.map(fn line=>rule(String.tokens Char.isSpace line))lines
        val verbs=nub(S.map verb rules)
        val changes=S.map(fn v=>(L.delay(fn()=>v),L.delay(fn()=>S.filter(fn r=>verb r=v)rules)))verbs
    in updateList(newTable())changes end
  fun relevant defs p=case L.force p of Var _=>raise Match
    |Term(v,_)=>case L.force(find defs v)of Reason _=>S.empty()|Answer rules=>L.force rules
  fun subst env p=L.delay(fn()=>case L.force p of Term(word,children)=>
       L.force(term word(S.map(subst env)children))
    |Var x=>case L.force(find env x)of Reason _=>Var x|Answer value=>L.force(subst env(L.force value)))
  fun occurs variable phrase=case L.force phrase of Term(_,ps)=>
      let fun any xs=case L.force xs of S.Nil=>false|S.Cons(p,rest)=>occurs variable(L.force p)orelse any rest
      in any ps end
    |Var x=>case L.force variable of Var y=>y=x|_=>false
  fun match env a b=compear env(subst env a)(subst env b)
  and matchList env pairs=case L.force pairs of S.Nil=>Answer env
    |S.Cons(pair,rest)=>let val(a,b)=L.force pair
      in case match env a b of Reason why=>Reason why|Answer next=>matchList next rest end
  and compear env a b=case(L.force a,L.force b)of
      (Term(x,ps),Term(y,qs))=>if x=y then matchList env(S.zipWith(fn(p,q)=>(p,q))ps qs)else Reason "no match"
    |(Var x,Var y)=>Answer(if x<>y then update env x(L.delay(fn()=>variable y))else env)
    |(Var x,_)=>if not(occurs(variable x)b)then Answer(update env x(L.delay(fn()=>b)))else Reason "occurs check failed"
    |(_,Var _)=>compear env b a
end
