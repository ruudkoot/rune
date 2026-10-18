 (* Used GHC Read/Show literal operations, with Unicode escape values kept as
  * integers. Selected benchmark source text is ASCII. *)
 val asciiNames=["NUL","SOH","STX","ETX","EOT","ENQ","ACK","BEL","BS","HT","LF","VT",
   "FF","CR","SO","SI","DLE","DC1","DC2","DC3","DC4","NAK","SYN","ETB","CAN","EM",
   "SUB","ESC","FS","GS","RS","US","SP"]
 val namedEscapes=("SOH",1)::("SO",14)::
   List.filter(fn(name,_)=>name<>"SOH"andalso name<>"SO")
    (ListPair.zip(asciiNames@["DEL"],List.tabulate(33,fn i=>i)@[127]))
 fun uncons chars=case D.force chars of F.Nil=>NONE
   |F.Cons(value,rest)=>SOME(D.force value,rest)
 fun textPrefix [] chars=SOME chars
   |textPrefix(c::cs)chars=case uncons chars of
      SOME(d,rest)=>if c=d then textPrefix cs rest else NONE|NONE=>NONE
 fun dropText predicate chars=case uncons chars of
    SOME(c,rest)=>if predicate c then dropText predicate rest else chars|NONE=>chars
 fun digit base c=
   let val n=if c>= #"0"andalso c<= #"9"then Char.ord c-48
             else if c>= #"a"andalso c<= #"f"then Char.ord c-87
             else if c>= #"A"andalso c<= #"F"then Char.ord c-55 else ~1
   in if n>=0 andalso n<base then SOME n else NONE end
 fun escapeNumber base chars=
   let fun loop value count chars=case uncons chars of
          SOME(c,rest)=>(case digit base c of
             SOME n=>if value>(1114111-n)div base then NONE
               else loop(value*base+n)(count+1)rest
            |NONE=>if count=0 then NONE else SOME(value,chars))
         |NONE=>if count=0 then NONE else SOME(value,chars)
   in loop 0 0 chars end
 fun readEscape chars=
   case uncons chars of NONE=>NONE
    |SOME(c,rest)=>
      let val simple=case c of #"a"=>SOME 7| #"b"=>SOME 8| #"f"=>SOME 12| #"n"=>SOME 10
            | #"r"=>SOME 13| #"t"=>SOME 9| #"v"=>SOME 11| #"\\"=>SOME 92
            | #"\""=>SOME 34| #"'"=>SOME 39|_=>NONE
          fun named []=NONE
            |named((name,value)::names)=
               case textPrefix(String.explode name)chars of SOME after=>SOME(value,after)
                |NONE=>named names
      in case simple of SOME n=>SOME(n,rest)|NONE=>
         if c= #"x"orelse c= #"X"then escapeNumber 16 rest
         else if c= #"o"orelse c= #"O"then escapeNumber 8 rest
         else if Char.isDigit c then escapeNumber 10 chars
         else if c= #"^"then(case uncons rest of SOME(d,after)=>
              if d>= #"@"andalso d<= #"_"then SOME(Char.ord d-64,after)else NONE|NONE=>NONE)
         else named namedEscapes
      end
 fun readCharItem chars=case uncons chars of NONE=>NONE
   |SOME(#"\\",rest)=>(case readEscape rest of NONE=>NONE|SOME(n,after)=>SOME(n,true,after))
   |SOME(c,rest)=>SOME(Char.ord c,false,rest)
 fun readCharacter chars=
   case uncons chars of SOME(#"'",rest)=>
     (case readCharItem rest of SOME(n,escaped,after)=>
        if not escaped andalso n=39 then NONE
        else(case uncons after of SOME(#"'",last)=>SOME([n],last)|_=>NONE)
       |NONE=>NONE)
    |_=>NONE
 fun readString chars=
   let fun body values chars=
         case uncons chars of
          SOME(#"\\",rest)=>(case uncons rest of
            SOME(#"&",after)=>body values after
           |SOME(c,after)=>if Char.isSpace c then
              (case uncons(dropText Char.isSpace after)of SOME(#"\\",last)=>body values last|_=>NONE)
             else item values chars
           |NONE=>NONE)
         |_=>item values chars
       and item values chars=case readCharItem chars of NONE=>NONE
         |SOME(n,escaped,rest)=>if n=34 andalso not escaped then SOME(List.rev values,rest)
                              else body(n::values)rest
   in case uncons chars of SOME(#"\"",rest)=>body[]rest|_=>NONE end
 fun showEscape n next=
   if n>127 then "\\"^Int.toString n^(if next>=48 andalso next<=57 then"\\&"else"")
   else if n=127 then"\\DEL"
   else if n=92 then"\\\\"
   else if n>=32 then String.str(Char.chr n)
   else case n of 7=>"\\a"|8=>"\\b"|12=>"\\f"|10=>"\\n"|13=>"\\r"|9=>"\\t"|11=>"\\v"
       |14=>"\\SO"^(if next=72 then"\\&"else"")
       |_=>"\\"^List.nth(asciiNames,n)
 fun showCharacter[n]=if n=39 then"'\\''"else"'"^showEscape n 39^"'"
   |showCharacter _=internal()
 fun showString values=
   let fun loop [] out=String.concat(List.rev out)
         |loop(n::rest)out=
           loop rest((if n=34 then"\\\""else showEscape n(case rest of[]=>34|x::_=>x))::out)
   in "\""^loop values[]^"\""end
