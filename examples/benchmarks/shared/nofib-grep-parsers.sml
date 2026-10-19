(* Thiemann's ordered list-of-successes parser combinators. *)
functor BenchGrepParsersFn(D : BENCH_SUSPEND) =
struct
 structure Q=BenchCellSequenceFn(D)
 type 'a parser=int list -> ('a * int list) Q.sequence
 fun singleton x=Q.cons(Q.value x)(Q.empty())
 fun succeed value tokens=singleton(value,tokens)
 fun satisfy predicate []=Q.empty()
   | satisfy predicate(token::tokens)=if predicate token then succeed token tokens else Q.empty()
 fun literal token=satisfy(fn c=>c=token)
 fun bind xs function=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,rest)=>D.force(Q.append(function(D.force x))(bind rest function)))
 fun thn first second tokens=bind(first tokens)(fn(v1,tokens1)=>Q.map(fn(v2,tokens2)=>((v1,v2),tokens2))(second tokens1))
 fun thnx first second tokens=bind(first tokens)(fn(v1,tokens1)=>Q.map(fn(_,tokens2)=>(v1,tokens2))(second tokens1))
 fun xthn first second tokens=bind(first tokens)(fn(_,tokens1)=>second tokens1)
 fun alt first second tokens=Q.append(first tokens)(D.delay(fn()=>D.force(second tokens)))
 fun using parser function tokens=Q.map(fn(v,rest)=>(function v,rest))(parser tokens)
 fun plus parser tokens=using(thn parser(rpt parser))(fn(v,vs)=>v::vs)tokens
 and rpt parser tokens=alt(plus parser)(succeed[])tokens
 fun opt parser=alt(using parser(fn x=>[x]))(succeed[])
 fun followedBy first second tokens=bind(first tokens)(fn(v,rest)=>Q.map(fn _=>(v,rest))(second rest))
end
