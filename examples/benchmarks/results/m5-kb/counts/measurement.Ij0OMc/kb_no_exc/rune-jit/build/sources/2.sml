(* Xavier Leroy, INRIA Rocquencourt. Copyright 1996 INRIA.
   Distributed under the Q Public License version 1.0.
   Portable translation of Sandmark's retained terms/equations definitions. *)
structure BenchSandmarkKBTerms =
struct
  datatype term=Var of int|Term of string*term list
  type rule={number:int,numvars:int,lhs:term,rhs:term}
  exception Failure of string
  exception NotFound
  exception Invalid of string
  fun union [] ys=ys
    |union(a::rest)ys=if List.exists(fn x=>a=x)ys then union rest ys else a::union rest ys
  fun vars(Var n)=[n]
    |vars(Term(_,sons))=varsList sons
  and varsList []=[]
    |varsList(t::rest)=union(vars t)(varsList rest)
  fun assoc key []=raise NotFound
    |assoc key((n,t)::rest)=if key=n then t else assoc key rest
  fun substitute subs(Var n)= (assoc n subs handle NotFound=>Var n)
    |substitute subs(Term(name,sons))=Term(name,List.map(substitute subs)sons)
  fun replace m [] n=n
    |replace(Term(name,sons))(i::path)n=Term(name,replaceNth i sons path n)
    |replace _ _ _=raise Failure "replace"
  and replaceNth _ [] _ _=raise Failure "replace_nth"
    |replaceNth i(s::rest)path n=if i=1 then replace s path n::rest
      else s::replaceNth(i-1)rest path n
  fun fold2 f acc [] []=acc
    |fold2 f acc(a::ar)(b::br)=fold2 f(f acc a b)ar br
    |fold2 _ _ _ _=raise Invalid "List.fold_left2"
  fun compose first second=List.map(fn(v,t)=>(v,substitute first t))second@first
  fun occurs n(Var m)=m=n
    |occurs n(Term(_,sons))=List.exists(occurs n)sons
  fun unify(Var n,t)=if Var n=t then[]else if occurs n t then raise Failure "unify"else[(n,t)]
    |unify(t,Var n)=if occurs n t then raise Failure "unify"else[(n,t)]
    |unify(Term(a,xs),Term(b,ys))=if a=b then
      fold2(fn s=>fn x=>fn y=>compose(unify(substitute s x,substitute s y))s)[]xs ys
      else raise Failure "unify"
  fun mkRule number m n=
    let val allVars=union(vars m)(vars n)val counter=ref 0
        val subs=List.map(fn v=>(counter:= !counter+1;(v,Var(!counter))))(List.rev allVars)
    in {number=number,numvars= !counter,lhs=substitute subs m,rhs=substitute subs n}:rule end
  fun checkRules rules=
    let val counter=ref 0
        val _=List.app(fn(r:rule)=>(counter:= !counter+1;
          if #number r= !counter then()else raise Failure "Rule numbers not in sequence"))rules
    in !counter end
  fun canonicalTerm(Var n)="v"^Int.toString n
    |canonicalTerm(Term(name,sons))=name^"("^String.concatWith","(List.map canonicalTerm sons)^")"
  fun canonicalRule({number,numvars,lhs,rhs}:rule)=
    Int.toString number^" "^Int.toString numvars^" "^canonicalTerm lhs^"="^canonicalTerm rhs^"\n"
end
