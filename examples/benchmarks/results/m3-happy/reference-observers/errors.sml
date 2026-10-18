 (* MaybeErr control values remain memoized in both finite-data policies.
  * parE deliberately passes a poison value after failure, matching source. *)
 datatype 'a outcome=Succeeded of 'a L.delay|Rejected of text F.seq
 fun succeeded value=Succeeded(L.delay(fn()=>value))
 fun thenE outcome next=case outcome of Rejected errors=>Rejected errors|Succeeded value=>next value
 fun parE outcome next=case outcome of
    Rejected errors=>(case next(L.delay(fn()=>raise Fail"parE"))of
       Rejected more=>Rejected(F.append errors more)|Succeeded _=>Rejected errors)
   |Succeeded value=>next value
 fun parEs values=case values of []=>succeeded(F.empty())
   |value::rest=>parE value(fn first=>parE(parEs rest)(fn tail=>
      Succeeded(L.delay(fn()=>F.cons(D.delay(fn()=>L.force first),F.defer(fn()=>L.force tail))))))
 fun failMap f outcome=case outcome of Succeeded value=>Succeeded value
   |Rejected errors=>Rejected(F.map f errors)
 fun reject message=Rejected(singleton(D.delay(fn()=>X.text message)))
 fun appendText a b=F.append a b
 fun decimal n=X.text(Int.toString n)
 fun happyVar n="happy_var_"^Int.toString n
 fun readReference chars=
   let fun collect base value count chars=case uncons chars of
          SOME(c,rest)=>(case digit base c of
            SOME n=>let val(limit,remainder)=case base of 10=>(107374182,3)
                       |16=>(67108863,15)|8=>(134217727,7)|_=>raise Domain
                    in if value>limit orelse(value=limit andalso n>remainder)then NONE
                    else collect base(value*base+n)(count+1)rest end
           |NONE=>if count=0 then NONE else SOME(value,chars))
         |NONE=>if count=0 then NONE else SOME(value,chars)
       fun digitsStart chars=case uncons chars of SOME(c,_)=>Char.isDigit c|NONE=>false
       fun exponentStart chars=case uncons chars of SOME(c,rest)=>
             if c= #"+"orelse c= #"-"then digitsStart rest else Char.isDigit c|NONE=>false
       fun floatingSuffix chars=case uncons chars of SOME(c,rest)=>
             if c= #"."then digitsStart rest
             else if c= #"e"orelse c= #"E"then exponentStart rest else false|NONE=>false
       fun decimal chars=case collect 10 0 0 chars of
             result as SOME(_,rest)=>if floatingSuffix rest then NONE else result|NONE=>NONE
   in case uncons chars of SOME(#"0",rest)=>
        (case uncons rest of SOME(c,after)=>
          if c= #"x"orelse c= #"X"then
            (case uncons after of SOME(c,_)=>if Option.isSome(digit 16 c)then collect 16 0 0 after else decimal chars
             |NONE=>decimal chars)
          else if c= #"o"orelse c= #"O"then
            (case uncons after of SOME(c,_)=>if Option.isSome(digit 8 c)then collect 8 0 0 after else decimal chars
             |NONE=>decimal chars)
          else decimal chars
         |NONE=>decimal chars)
      |_=>decimal chars end
 fun doCheckCode arity code=
   let fun finish acc used=
         Succeeded(L.delay(fn()=>(F.defer(fn()=>F.fromList(List.rev acc)),F.fromList used)))
       fun add output acc=List.rev(String.explode output)@acc
       fun go chars acc used=case uncons chars of NONE=>finish acc used
        |SOME(c,rest)=>
          if c= #"\""then
            (case readString chars of NONE=>go rest(c::acc)used
             |SOME(value,after)=>go after(add(showString value)acc)used)
          else if Char.isAlphaNum c then
            (case uncons rest of SOME(#"'",after)=>go after(#"'"::c::acc)used
             |_=>go rest(c::acc)used)
          else if c= #"'"then
            (case readCharacter chars of NONE=>go rest(c::acc)used
             |SOME(value,after)=>go after(add(showCharacter value)acc)used)
          else if c= #"\\"then
            (case uncons rest of SOME(#"$",after)=>go after(#"$"::acc)used
             |_=>go rest(c::acc)used)
          else if c= #"$"then
            (case uncons rest of
              SOME(#">",after)=>if arity=0 then reject"$> in empty rule"
               else go after(add(happyVar arity)acc)(arity::used)
             |SOME(n,_)=>if Char.isDigit n then
                 (case readReference rest of NONE=>raise Fail"reference integer outside recorded 31-bit domain"
                  |SOME(index,after)=>if index>arity then
                     parE(reject("$"^Int.toString index^" out of range"))(fn _=>go after acc used)
                    else go after(add(happyVar index)acc)(index::used))
                else go rest(c::acc)used
             |NONE=>go rest(c::acc)used)
          else go rest(c::acc)used
   in go code[][]end
