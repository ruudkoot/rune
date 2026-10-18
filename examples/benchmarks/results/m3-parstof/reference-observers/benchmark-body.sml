 val successText=X.chars"Program correctly parsed!\n"
 fun append left right=L.delay(fn()=>case L.force left of X.End=>L.force right
   |X.Ch(c,rest)=>X.Ch(c,append rest right))
 fun benchmark count input=
   let fun messages i=L.delay(fn()=>if i>count then X.End
          else case c_par_proglist(X.tokenizeAt input 1)of
             Success _=>L.force(append successText(messages(i+1)))
            |ParseFail _=>raise Fail"incorrect result: parstof rejected source program")
       fun consume stream sum length=case L.force stream of
           X.End=>(intText(D.force sum+D.force length)^"/"^intText(D.force length)^"\n")
          |X.Ch(c,rest)=>consume rest(D.delay(fn()=>D.force sum+Char.ord c))(D.delay(fn()=>D.force length+1))
   in consume(messages 1)(D.delay(fn()=>0))(D.delay(fn()=>0))end
