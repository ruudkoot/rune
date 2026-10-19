
 val endOfLine=[#"\n",#"\012",#"\r"]
 val whiteSpace=[#" ",#"\t"]@endOfLine
 val symbolCharacters=String.explode"!#$&*-+=~<>?/\\.:|@"
 val singleCharacters=List.map Char.chr[44,59,34,96,39,40,41,123,125,91,93,176,185]
 val binderCharacters=List.map Char.chr[208,211,236,177,178,229,196]
 val infixBinderCharacters=List.map Char.chr[183,184,167,182,187]
 val infixOperatorCharacters=List.map Char.chr[179,180,61,172,58]
 fun asciiAlphaNumeric c=(c>= #"A"andalso c<= #"Z")orelse(c>= #"a"andalso c<= #"z")orelse(c>= #"0"andalso c<= #"9")
 fun contains characters c=List.exists(fn value=>c=value)characters
 fun byte n=text(String.str(Char.chr n))
 val reservedTokens: text list=List.map text[
    "empty","signature","extend","combine","with","sharing","++","=","(",")","@","operator",";",":",
    String.str(Char.chr 189),"datatype","|","case","of",String.str(Char.chr 167),"recurse","end","typed","fn","rec",
    "if","then","else","let","in",String.str(Char.chr 168),String.str(Char.chr 169),"{","}","[","]",
    String.str(Char.chr 208),String.str(Char.chr 211),String.str(Char.chr 236),String.str(Char.chr 229),
    String.str(Char.chr 177),String.str(Char.chr 178),".",",",String.str(Char.chr 181),String.str(Char.chr 179),
    String.str(Char.chr 180),String.str(Char.chr 182),String.str(Char.chr 172),String.str(Char.chr 183),
    String.str(Char.chr 184),String.str(Char.chr 185),String.str(Char.chr 176),"BinL","BinR","Pre","Post",
    String.str(Char.chr 196),String.str(Char.chr 187)]
 fun binderCharacter character=case Char.ord character of 208=>PiB|211=>SigmaB|236=>LambdaB
   |177=>ForallB|178=>ExistsB|229=>ChooseB|196=>DeltaB|_=>raise Fail("Mk_bdr: "^String.str character)
 fun tokenCons value rest=C.cons(L.delay(fn()=>value),rest)
 fun tokenize characters=
   let fun scan input current=C.defer(fn()=>case force input of F.Nil=>tokenCons(cell(Clear current))(C.empty())
         |F.Cons(character,rest)=>
           let val c=force character
               fun emitted token=tokenCons(cell(Clear current))(tokenCons token(scan rest(F.empty())))
           in if contains binderCharacters c then emitted(cell(BinderToken(binderCharacter c)))
              else if contains infixBinderCharacters c then emitted(cell(InfixBinderToken(singleton character)))
              else if contains infixOperatorCharacters c then emitted(cell(InfixOperatorToken(singleton character)))
              else if contains singleCharacters c orelse Char.ord c>127 then emitted(cell(Clear(singleton character)))
              else if contains symbolCharacters c then tokenCons(cell(Clear current))(symbolScan rest(singleton character))
              else if contains whiteSpace c then tokenCons(cell(Clear current))(scan rest(F.empty()))
              else if asciiAlphaNumeric c orelse c= #"_"then scan rest(F.cons(character,current))
              else if c= #"%"then tokenCons(cell(Clear current))(scan(discard rest)(F.empty()))
              else if c= #"^"then superScan rest(F.cons(character,current))
              else tokenCons(cell(ScanError(text"\nInvalid character\n")))(C.empty())end)
       and symbolScan input current=C.defer(fn()=>case force input of F.Nil=>tokenCons(cell(Clear current))(C.empty())
         |F.Cons(character,rest)=>let val c=force character
           in if contains symbolCharacters c then symbolScan rest(F.cons(character,current))
              else if c= #"^"then superScan rest(F.cons(character,current))
              else tokenCons(cell(Clear current))(scan input(F.empty()))end)
       and superScan input current=C.defer(fn()=>if equalText current(text"^")then
             tokenCons(cell(ScanError(text"\nAttempt to superscript invalid string\n")))(C.empty())
           else case force input of F.Nil=>tokenCons(cell(ScanError(text"\nEmpty superscript\n")))(C.empty())
            |F.Cons(character,rest)=>if asciiAlphaNumeric(force character)orelse contains symbolCharacters(force character)
                then tokenCons(cell(Clear(F.cons(character,current))))(scan rest(F.empty()))
                else tokenCons(cell(ScanError(text"\nInvalid superscript character\n")))(C.empty()))
       and discard input=F.defer(fn()=>case force input of F.Nil=>F.empty()
          |F.Cons(c,rest)=>if contains endOfLine(force c)then rest else discard rest)
       fun denull tokens=C.defer(fn()=>case L.force tokens of C.Nil=>C.empty()
         |C.Cons(delayed,rest)=>
            let val token=L.force delayed
            in case force token of Clear chars=>if null chars then denull rest
               else let val value=reverse chars
                        val token=cell(if List.exists(fn s=>equalText value s)reservedTokens then Reserved value else Clear value)
                    in tokenCons token(denull rest)end
              |Reserved _=>raise Fail" optimise to trap some reserved earlier and reduce length of reserved set"
              |ScanError _=>tokenCons token(C.empty())
              |_=>tokenCons token(denull rest)end)
   in denull(scan characters(F.empty()))end
