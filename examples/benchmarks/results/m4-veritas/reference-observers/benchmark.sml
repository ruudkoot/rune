
 type input=char F.seq
 fun input raw=text raw
 fun benchmark input=
   let fun loop hash chars=case force chars of F.Nil=>hash
         |F.Cons(c,rest)=>loop(Word64.+(Word64.*(hash,0w31),Word64.fromInt(Char.ord(force c))))rest
   in loop 0w0(program input)end
 fun signedHash word=
   let val magnitude=Word64.toLargeInt word
       val negative=Word64.andb(word,0wx8000000000000000)<>0w0
       val value=if negative then magnitude-18446744073709551616 else magnitude
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value)end
