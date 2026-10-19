 fun hash chars=
   let fun loop value chars=case D.force chars of F.Nil=>value
         |F.Cons(c,rest)=>loop(W.+(W.fromInt(Char.ord(D.force c)),W.*(value,0w31)))rest
   in loop 0w0 chars end
 fun signedHash word=
   let val n=W.toLargeInt word
       val signed=if S.negative word then n-18446744073709551616 else n
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString signed)end
 type input=inputLines
 fun benchmark input=hash(program input)
