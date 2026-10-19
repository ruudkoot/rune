(* Source list-of-successes parser combinators; alternatives remain memoized
   streams so that inspecting one parse never forces every possible parse. *)
structure BenchPrologParse =
struct
  structure S=BenchStream
  structure L=BenchLazy
  type 'a parser=char list->('a*char list) S.stream
  fun fail _=S.empty()
  fun okay value input=S.singleton(value,input)
  fun token word input=
    let val chars=String.explode word val n=List.length chars
    fun take 0 _=[]
          |take _ []=[]
          |take k(x::xs)=x::take(k-1)xs
    in if take n input=chars
       then S.singleton(word,List.drop(input,n))else S.empty()end
  fun satisfy predicate input=case input of []=>S.empty()
    |c::rest=>if predicate c then S.singleton(c,rest)else S.empty()
  fun alternative p q input=S.append(p input)(L.delay(fn()=>L.force(q input)))
  fun sequence p q input=S.concatMap(fn(a,rest)=>S.map(fn(b,tail)=>((a,b),tail))(q rest))(p input)
  fun map p f input=S.map(fn(value,rest)=>(f value,rest))(p input)
  fun dropSpaces input=case input of #" "::rest=>dropSpaces rest|_=>input
  fun just p input=S.map(fn(value,_)=>(value,[]))
    (S.filter(fn(_,rest)=>List.null(dropSpaces rest))(p input))
  fun space p input=p(dropSpaces input)
  fun spaceToken word=space(token word)
  fun many p input=L.delay(fn()=>L.force
    (alternative(map(sequence p(many p))(fn(x,xs)=>x::xs))(okay[])input))
  fun many1 p=map(sequence p(many p))(fn(x,xs)=>x::xs)
  fun listOf p separator=
    alternative(map(sequence p(many(sequence separator p)))
      (fn(x,xs)=>x::List.map #2 xs))(okay[])
end
