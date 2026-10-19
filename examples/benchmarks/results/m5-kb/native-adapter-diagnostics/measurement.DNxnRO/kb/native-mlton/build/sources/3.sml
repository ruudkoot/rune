(* Xavier Leroy, INRIA, 1996; Q Public License version 1.0.
   Source exception-based matching and rewriting; source term printers are stubs. *)
structure BenchSandmarkKBRaise =
struct
  structure T=BenchSandmarkKBTerms
  fun matching first second=
    let fun match subs(T.Var n)t=
              if List.exists(fn(key,_)=>key=n)subs then
                if T.assoc n subs=t then subs else raise T.Failure "matching"
              else(n,t)::subs
          |match subs(T.Term(a,xs))(T.Term(b,ys))=
              if a=b then T.fold2 match subs xs ys else raise T.Failure "matching"
          |match _ _ _=raise T.Failure "matching"
    in match[]first second end
  fun reduce l m r=T.substitute(matching l m)r
  fun canMatch l m=(matching l m;true)handle T.Failure _=>false
  fun reducible l m=canMatch l m orelse(case m of T.Term(_,sons)=>List.exists(reducible l)sons|_=>false)
  fun mreduce [] _=raise T.Failure "mreduce"
    |mreduce((rule:T.rule)::rest)m=
       reduce(#lhs rule)m(#rhs rule)handle T.Failure _=>mreduce rest m
  fun rewriteOne rules m=mreduce rules m handle T.Failure _=>case m of
      T.Var _=>raise T.Failure "mrewrite1"
    |T.Term(name,sons)=>T.Term(name,rewriteSons rules sons)
  and rewriteSons _ []=raise T.Failure "mrewrite1"
    |rewriteSons rules(son::rest)=
       (rewriteOne rules son::rest)handle T.Failure _=>son::rewriteSons rules rest
  fun rewriteAll rules m=(rewriteAll rules(rewriteOne rules m))handle T.Failure _=>m
  fun prettyTerm _=()
end
