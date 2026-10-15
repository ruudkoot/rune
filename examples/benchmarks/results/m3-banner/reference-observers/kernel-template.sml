(* Mark P Jones's glyph tables and ragged transpose/banner composition. *)
functor BenchBannerFn(D : BENCH_BANNER_SUSPEND) =
struct
 structure Q=BenchCellSequenceFn(D)
 type row=char Q.sequence
 type picture=row Q.sequence
 fun chars text=Q.fromList(String.explode text)
 fun picture rows=D.delay(fn()=>case rows of []=>Q.Nil
   | row::rest=>Q.Cons(D.delay(fn()=>chars row),picture rest))
 fun fontTable rows=D.delay(fn()=>case rows of []=>Q.Nil
   | glyph::rest=>Q.Cons(D.delay(fn()=>picture glyph),fontTable rest))
 fun punctTable rows=D.delay(fn()=>case rows of []=>Q.Nil
   | (key,glyph)::rest=>Q.Cons(D.delay(fn()=>(key,D.delay(fn()=>picture glyph))),punctTable rest))
 TABLES
 val emptyRow : row=Q.empty()
 val nothingCache=ref(NONE:picture option)
 fun nothing()=case !nothingCache of SOME rows=>rows
   | NONE=>let val rows=D.knot(fn self=>Q.Cons(Q.value emptyRow,self))
               val _=nothingCache:=SOME rows
           in rows end
 fun nth xs n=case D.force xs of Q.Nil=>raise Subscript
   | Q.Cons(x,rest)=>if n=0 then D.force x else nth rest(n-1)
 fun picChar c=if Char.isUpper c then nth alphas(Char.ord c-Char.ord #"A")
   else if Char.isLower c then nth alphas(Char.ord c-Char.ord #"a")
   else if Char.isSpace c then blank
   else if Char.isDigit c then nth digits(Char.ord c-Char.ord #"0")
   else if c= #"/" then slant
   else if c= #"\\" then reverse slant
   else punctuation c
 and reverse rows=Q.fromList(List.rev(Q.toList rows))
 and punctuation c=
   let fun find entries=case D.force entries of Q.Nil=>nothing()
         | Q.Cons(entry,rest)=>let val(key,glyph)=D.force entry
             in if key=c then D.force glyph else find rest end
   in find punct end
 fun unconsRows rows=D.delay(fn()=>case D.force rows of Q.Nil=>(Q.empty(),Q.empty())
   | Q.Cons(row,rest)=>case D.force(D.force row)of Q.Nil=>D.force(unconsRows rest)
     | Q.Cons(first,tail)=>
         let val others=unconsRows rest
         in(Q.cons first(D.delay(fn()=>D.force(#1(D.force others)))),
            Q.cons(Q.value tail)(D.delay(fn()=>D.force(#2(D.force others)))))end)
 fun transpose rows=D.delay(fn()=>
   let val parts=unconsRows rows
       val heads=D.delay(fn()=>D.force(#1(D.force parts)))
   in case D.force heads of Q.Nil=>Q.Nil
     | _=>Q.Cons(Q.value heads,transpose(D.delay(fn()=>D.force(#2(D.force parts)))))end)
 val spacer=chars "  "
 fun join rows=D.delay(fn()=>case D.force rows of Q.Nil=>raise Empty
   | Q.Cons(first,rest)=>case D.force rest of Q.Nil=>D.force(D.force first)
     | _=>D.force(Q.append(D.force first)(Q.append spacer(join rest))))
 fun unlines rows=D.delay(fn()=>case D.force rows of Q.Nil=>Q.Nil
   | Q.Cons(row,rest)=>D.force(Q.append(D.force row)(Q.cons(Q.value #"\n")(unlines rest))))
 fun say input=Q.cons(Q.value #"\n")(unlines(Q.map join(transpose(Q.map picChar input))))
 fun repeatInput 0 _=Q.empty()
   | repeatInput n text=D.delay(fn()=>D.force(Q.append(chars text)(repeatInput(n-1)text)))
 fun splitLine input=D.delay(fn()=>case D.force input of Q.Nil=>(Q.empty(),Q.empty())
   | Q.Cons(c,rest)=>if D.force c= #"\n" then(Q.empty(),rest)else
       let val pair=splitLine rest
       in(Q.cons c(D.delay(fn()=>D.force(#1(D.force pair)))),
          D.delay(fn()=>D.force(#2(D.force pair))))end)
 fun lines input=D.delay(fn()=>case D.force input of Q.Nil=>Q.Nil
   | _=>let val pair=splitLine input
        in Q.Cons(D.delay(fn()=> #1(D.force pair)),D.delay(fn()=>D.force(lines(#2(D.force pair)))))end)
end
