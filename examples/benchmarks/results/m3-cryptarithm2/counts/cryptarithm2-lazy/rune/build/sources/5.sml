(* Port of Andy Gill's nofib cryptarithm2 (October 1999).
   The used StateT/list operations are translated into SML97; preserve the
   individual BSD library notices in each benchmark directory's upstream/transformers.
   Original program license grant is unstated. See workload PROVENANCE.md. *)
(* Andy Gill's nofib cryptarithm2: ordered StateT/list search and column pruning. *)
functor BenchCryptarithmFn(D : BENCH_SUSPEND) =
struct
  structure S=BenchCellSequenceFn(D)
  datatype digits=Digits of int S.sequence * (char * int D.t) S.sequence
  type state=digits D.t
  fun ret value state=S.cons(S.value(value,state))(S.empty())
  fun concatMap f xs=D.delay(fn()=>case D.force xs of S.Nil=>S.Nil
    | S.Cons(x,rest)=>D.force(S.append(f(D.force x))(concatMap f rest)))
  fun bind search f state=concatMap(fn(value,next)=>f value next)(search state)
  fun delete value xs=D.delay(fn()=>case D.force xs of S.Nil=>S.Nil
    | S.Cons(x,rest)=>if D.force x=value then D.force rest
                      else S.Cons(x,delete value rest))
  val initState=D.delay(fn()=>Digits(S.fromList(List.tabulate(10,fn i=>i)),S.empty()))

  fun permute c state=
    let val Digits(available,environment)=D.force state
        fun choices xs=D.delay(fn()=>case D.force xs of S.Nil=>S.Nil
          | S.Cons(x,rest)=>
              let val next=D.delay(fn()=>Digits(delete(D.force x)available,
                                    S.cons(S.value(c,x))environment))
              in S.Cons(S.value(x,next),choices rest)end)
    in choices available end

  fun select c state=D.delay(fn()=>
    let val Digits(_,environment)=D.force state
        fun lookup xs=case D.force xs of S.Nil=>NONE
          | S.Cons(x,rest)=>let val(key,value)=D.force x
                           in if key=c then SOME value else lookup rest end
    in case lookup environment of SOME value=>D.force(ret value state)
       | NONE=>D.force(permute c state)end)

  fun mapSelect []=ret(D.delay(fn()=>[]))
    | mapSelect(c::cs)=bind(select c)(fn x=>
        bind(mapSelect cs)(fn xs=>ret(D.delay(fn()=>x::D.force xs))))

  fun solve columns [] carry=
        if List.null columns andalso carry=0 then ret(D.delay(fn()=>())) else (fn _=>S.empty())
    | solve columns (bot::bots) carry=
        let val topSearch=case columns of []=>ret(D.delay(fn()=>carry))
              | top::_=>bind(mapSelect top)(fn values=>ret(D.delay(fn()=>
                  List.foldl(fn(x,sum)=>sum+D.force x)0(D.force values)+carry)))
        in bind topSearch(fn topN=>bind(select bot)(fn botN=>fn state=>
             if D.force topN mod 10=D.force botN then
               solve(case columns of []=>[] | _::rest=>rest)bots(D.force topN div 10)state
             else S.empty()))end

  fun transpose rows=
    let val remaining=List.filter(fn row=>not(List.null row))rows
    in if List.null remaining then []
       else List.map List.hd remaining::transpose(List.map List.tl remaining)end

  fun environment state=
    let val Digits(_,env)=D.force state
    in List.map(fn(c,digit)=>(c,D.force digit))(S.toList env)end
  fun solutions top bot=solve(transpose(List.map(List.rev o String.explode)top))
                             (List.rev(String.explode bot))0 initState
  fun all top bot=List.map(fn(_,state)=>environment state)(S.toList(solutions top bot))

  fun puzzle top bot=
    let val symbols=String.explode(String.concat top^bot)
        fun distinct [] seen=List.length seen
          | distinct(c::cs)seen=distinct cs(if List.exists(fn x=>x=c)seen then seen else c::seen)
        val _=if distinct symbols []<=10 then ()else raise Fail "cannot map more than ten characters"
        val answer=case D.force(solutions top bot)of S.Nil=>raise Fail "cannot find a solution"
          | S.Cons(x,_)=>let val(_,state)=D.force x in environment state end
        fun lookup c=case List.find(fn(key,_)=>key=c)answer of SOME(_,value)=>value
          | NONE=>raise Fail "missing digit"
        fun expand text=List.foldl(fn(c,n)=>n*10+lookup c)0(String.explode text)
        val total=List.foldl(fn(text,n)=>n+expand text)0 top
        val _=if total=expand bot then ()else raise Fail "invalid cryptarithm answer"
    in String.concat(List.map(fn(c,n)=>String.str c^" => "^Int.toString n^"\n")answer)end
end
