 structure W=Word64
 fun hash chars=
   let fun loop value chars=case D.force chars of F.Nil=>value
         |F.Cons(c,rest)=>loop(W.+(W.fromInt(Char.ord(D.force c)),W.*(value,0w31)))rest
   in loop 0w0 chars end
 fun signedHash word=
   let val n=W.toLargeInt word
       val value=if W.andb(word,0wx8000000000000000)=0w0 then n else n-18446744073709551616
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value)end
 fun benchmark input=hash(report(parse input))

 type input=X.input
 val input=X.input
