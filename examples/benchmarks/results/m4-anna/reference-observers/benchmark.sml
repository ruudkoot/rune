
 type input=char C.seq
 type table=(domain*integer)F.seq
 fun benchmark chars table=
   let val report=strictAnalyze table(F.empty())chars
       fun hash value chars=case force chars of F.Nil=>value
         |F.Cons(c,rest)=>hash(W.+(W.*(value,0w31),W.fromInt(Char.ord(force c))))rest
   in hash 0w0 report end
 fun signedHash word=signed(cell word)
