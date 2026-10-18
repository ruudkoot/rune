 (* ProduceCode/GenUtils ShowS builders, retaining character spines and
  * delayed right operands rather than flattening intermediate output. *)
 structure B=
 struct
   type builder=text->text
   fun id tail=tail
   fun str value tail=F.append value tail
   fun literal value=str(X.text value)
   fun cat left right tail=left(F.defer(fn()=>right tail))
   fun delayed body tail=F.defer(fn()=>body()tail)
   fun many builders tail=F.defer(fn()=>case D.force builders of F.Nil=>tail
     |F.Cons(value,rest)=>D.force value(F.defer(fn()=>many rest tail)))
   fun pieces values=many(F.fromList values)
   fun interleave separator builders tail=F.defer(fn()=>case D.force builders of F.Nil=>tail
     |F.Cons(value,rest)=>D.force value(F.append(X.text separator)(F.defer(fn()=>interleave separator rest tail))))
   fun interleave1 separator builders tail=F.defer(fn()=>case D.force builders of F.Nil=>raise Empty
     |F.Cons(value,rest)=>D.force value(F.defer(fn()=>case D.force rest of F.Nil=>tail
       |_=>F.append(X.text separator)(interleave1 separator rest tail))))
   fun bracket value=pieces[literal"(",value,literal")"]
   fun integer n=delayed(fn()=>literal(Int.toString n))
   fun output builder=builder emptyText
 end
 (* The original routine returns the first unquoted $$ substitution. *)
 fun mapDollarDollar code=
   let fun add s acc=List.rev(String.explode s)@acc
       fun go chars acc=case uncons chars of NONE=>NONE
         |SOME(c,rest)=>if c= #"\""then
            (case readString chars of NONE=>go rest(c::acc)
             |SOME(value,after)=>go after(add(showString value)acc))
          else if Char.isAlphaNum c then
            (case uncons rest of SOME(#"'",after)=>go after(#"'"::c::acc)|_=>go rest(c::acc))
          else if c= #"'"then
            (case readCharacter chars of NONE=>go rest(c::acc)
             |SOME(value,after)=>go after(add(showCharacter value)acc))
          else if c= #"\\"then
            (case uncons rest of SOME(#"$",after)=>go after(#"$"::acc)|_=>go rest(c::acc))
          else if c= #"$"then
            (case uncons rest of SOME(#"$",after)=>SOME(fn replacement=>
                 F.append(F.fromList(List.rev acc))(F.append replacement after))
              |_=>go rest(c::acc))
          else go rest(c::acc)
   in go code[]end
 fun getDefault actions=
   let fun errorAction values=case D.force values of F.Nil=>NONE
         |F.Cons(value,rest)=>let val(n,a)=D.force value
           in if n=1 then SOME a else errorAction rest end
       fun firstReduction multiple values=case D.force values of F.Nil=>NONE
         |F.Cons(value,rest)=>let val(_,a)=D.force value
           in case D.force a of LRReduce _=>if multiple then firstReduction multiple rest else SOME a
            |LRMultiple(_,winner)=>if multiple then(case D.force winner of LRReduce _=>SOME winner
                 |_=>firstReduction multiple rest)else firstReduction multiple rest
            |_=>firstReduction multiple rest end
       fun choose()=case firstReduction false actions of SOME a=>a
         |NONE=>(case firstReduction true actions of SOME a=>a|NONE=>failAction)
   in case errorAction actions of
      SOME a=>(case D.force a of LRReduce _=>a
         |LRMultiple(_,winner)=>(case D.force winner of LRReduce _=>a|_=>failAction)
         |LRFail=>choose()|_=>failAction)
     |NONE=>choose()end
 fun mkAction value=B.delayed(fn()=>case D.force value of
      LRShift(n,_)=>B.pieces[B.literal"happyShift action_",B.integer(D.force n)]
     |LRReduce(n,_)=>B.pieces[B.literal"happyReduce_",B.integer(D.force n)]
     |LRAccept=>B.literal"happyAccept"|LRFail=>B.literal"happyFail"|LRMustFail=>B.literal"happyFail"
     |LRMultiple(_,winner)=>mkAction winner)
 fun mkActionName n=B.pieces[B.literal"action_",B.integer n]
 fun mkReduceFun n=B.pieces[B.literal"happyReduce_",B.integer n]
 fun mkHappyVar n=B.pieces[B.literal"happy_var_",B.integer n]
 fun typeParam n ty=B.delayed(fn()=>case D.force ty of NONE=>B.pieces[B.literal"t",B.integer n]
   |SOME ty=>B.bracket(B.str ty))
