 fun paNumber tokens=paApply(paSatisfy(fn text=>case force text of F.Nil=>false
   |F.Cons(c,_)=>Char.isDigit(force c)))numericValue tokens
 fun tableLex line chars=C.defer(fn()=>case charUncons chars of NONE=>C.empty()
   |SOME(c,rest)=>if c= #"\n"then tableLex(add line(int 1))rest
      else if c= #" "orelse c= #"\t"then tableLex line rest
      else if List.exists(fn x=>x=c)[#"(",#")",#"[",#"]",#","]
        then token line(name(String.str c))(tableLex line rest)
      else let
          fun keyword []=NONE
            |keyword((source,target)::more)=case prefixChars source chars of
               SOME tail=>SOME(target,tail)|NONE=>keyword more
        in case keyword[("Two","T"),("Func","F"),("Lift1","L"),("Lift2","M")]of
          SOME(text,tail)=>token line(name text)(tableLex line tail)
         |NONE=>if Char.isDigit c then
             let val(digits,tail)=charSpan Char.isDigit rest
             in token line(F.cons(cell c,charsToName digits))(tableLex line tail)end
           else myFail("Illegal character "^String.str c^" in lattice table, line "^signed line^".")end)
 fun tableComma parser=paThen2(fn a=>fn _=>a)parser(literal",")
 fun tableListMain parser tokens=paAlts[
     (tokenIs"]",paApply(literal"]")(fn _=>F.empty())),
     (fn _=>true,paThen3(fn xs=>fn x=>fn _=>F.append xs(singleton x))
        (paZeroOrMore(tableComma parser))parser(literal"]"))]tokens
 fun tableList parser=paThen2(fn _=>fn values=>values)(literal"[")(tableListMain parser)
 val tableDomainSlot:domainNode parser option ref=ref NONE
 fun tableDomain tokens=
   let val parser=case !tableDomainSlot of SOME p=>p|NONE=>
       let val p=paAlts[
         (tokenIs"(",paThen3(fn _=>fn d=>fn _=>d)(literal"(")tableDomain(literal")")),
         (tokenIs"T",paApply(literal"T")(fn _=>cell Two)),
         (tokenIs"L",paThen2(fn _=>fn ds=>cell(Lift1 ds))(literal"L")(tableList tableDomain)),
         (tokenIs"M",paThen2(fn _=>fn ds=>cell(Lift2 ds))(literal"M")(tableList tableDomain)),
         (tokenIs"F",paThen3(fn _=>fn ds=>fn d=>cell(Func(ds,d)))
             (literal"F")(tableList tableDomain)tableDomain)]
       in tableDomainSlot:=SOME p;p end
   in parser tokens end
 fun tablePair first second=paThen4(fn _=>fn a=>fn _=>fn b=>pair a b)
    (literal"(")first(literal",")(paThen2(fn b=>fn _=>b)second(literal")"))
 val tableParser:(domain*integer)F.node parser=tableList(tablePair tableDomain paNumber)
 fun readTable chars=
   case L.force(tableParser(tableLex(int 1)chars))of
      PFail rest=>(case L.force rest of C.Nil=>myFail"Unexpected end of lattice table"
        |C.Cons(tok,_)=>let val(line,_)=L.force tok
            in myFail("Syntax error in lattice table, line "^signed line^".")end)
     |POk(values,rest)=>(case L.force rest of C.Nil=>values
        |C.Cons(tok,_)=>let val(line,_)=L.force tok
            in myFail("Syntax error in lattice table, line "^signed line^".")end)
