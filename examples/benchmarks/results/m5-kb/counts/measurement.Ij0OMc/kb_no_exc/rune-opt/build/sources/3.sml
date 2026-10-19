(* Xavier Leroy, INRIA, 1996; Q Public License version 1.0.
   Source optional matching/top-level reduction; deeper rewriting still raises. *)
structure BenchSandmarkKBOption =
struct
  structure T=BenchSandmarkKBTerms
  fun fold2 f acc [] []=SOME acc
    |fold2 f acc(a::ar)(b::br)= (case f acc a b of NONE=>NONE|SOME next=>fold2 f next ar br)
    |fold2 _ _ _ _=raise T.Invalid "List.fold_left2"
  fun match subs(T.Var n)t=
        if List.exists(fn(key,_)=>key=n)subs then
          if T.assoc n subs=t then SOME subs else NONE
        else SOME((n,t)::subs)
    |match subs(T.Term(a,xs))(T.Term(b,ys))=if a=b then fold2 match subs xs ys else NONE
    |match _ _ _=NONE
  fun matching first second=match[]first second
  fun reduce l m r=case matching l m of SOME subs=>SOME(T.substitute subs r)|NONE=>NONE
  fun canMatch l m=case matching l m of SOME _=>true|NONE=>false
  fun reducible l m=canMatch l m orelse(case m of T.Term(_,sons)=>List.exists(reducible l)sons|_=>false)
  fun mreduce [] _=NONE
    |mreduce((rule:T.rule)::rest)m=case reduce(#lhs rule)m(#rhs rule)of
       SOME value=>SOME value|NONE=>mreduce rest m
  fun rewriteOne rules m=case mreduce rules m of SOME value=>value|NONE=>
      case m of T.Var _=>raise T.Failure "mrewrite1"
       |T.Term(name,sons)=>T.Term(name,rewriteSons rules sons)
  and rewriteSons _ []=raise T.Failure "mrewrite1"
    |rewriteSons rules(son::rest)=
       (rewriteOne rules son::rest)handle T.Failure _=>son::rewriteSons rules rest
  fun rewriteAll rules m=(rewriteAll rules(rewriteOne rules m))handle T.Failure _=>m
  fun printString _=()
  fun printInt _=()
  fun infixName name=List.exists(fn opName=>name=opName)["+","*"]
  fun prettyTerm(T.Var n)=(printString"v";printInt n)
    |prettyTerm(T.Term(name,sons))=
      if infixName name then
        (case sons of[a,b]=>(prettyClose a;printString name;prettyClose b)
         |_=>raise T.Failure "pretty_term : infix arity <> 2")
      else(printString name;case sons of []=>()|t::rest=>
        (printString"(";prettyTerm t;
         List.app(fn t=>(printString",";prettyTerm t))rest;printString")"))
  and prettyClose(term as T.Term(name,_))=if infixName name
      then(printString"(";prettyTerm term;printString")")else prettyTerm term
    |prettyClose term=prettyTerm term
end
