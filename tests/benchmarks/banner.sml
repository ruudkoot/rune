structure BannerPilot =
struct
 structure N=BenchBannerFn(BenchBannerNeed)
 structure S=BenchBannerFn(BenchBannerStrict)
 fun text x=String.implode(N.Q.toList x)
 val _=T.check("banner/empty-line",fn()=>text(N.say(N.chars ""))="\n")
 val _=T.check("banner/variants",fn()=>text(N.say(N.chars "Hello."))=String.implode(S.Q.toList(S.say(S.chars "Hello."))))
 val _=T.check("banner/case",fn()=>text(N.say(N.chars "Hi"))=text(N.say(N.chars "hI")))
 val _=T.check("banner/fallback-prefix",fn()=>
   List.map N.Q.toList(N.Q.toList(N.Q.take 3(N.nothing())))=[[],[],[]])
 datatype chain=Next of chain BenchBannerNeed.t
 val _=T.check("banner/knot-sharing",fn()=>
   let val calls=ref 0
       val root=BenchBannerNeed.knot(fn self=>(calls:= !calls+1;Next self))
       val Next tail=BenchBannerNeed.force root
       val _=BenchBannerNeed.force tail
   in !calls=1 end)

 fun read path=let val input=BinIO.openIn path
                   val bytes=BinIO.inputAll input
                   val _=BinIO.closeIn input
               in Byte.bytesToString bytes end
 fun renderN input=
   let fun loop lines result=case BenchBannerNeed.force lines of N.Q.Nil=>String.concat(List.rev result)
         | N.Q.Cons(line,rest)=>loop rest(text(N.say(BenchBannerNeed.force line))::result)
   in loop(N.lines(N.chars input))[]end
 fun renderS input=
   let fun loop lines result=case BenchBannerStrict.force lines of S.Q.Nil=>String.concat(List.rev result)
         | S.Q.Cons(line,rest)=>loop rest(String.implode(S.Q.toList(S.say(BenchBannerStrict.force line)))::result)
   in loop(S.lines(S.chars input))[]end
 val _=List.app(fn name=>T.check("banner/original-"^name,fn()=>
   let val input=read(name^".input")
       val output=read(name^".output")
   in renderN input=output andalso renderS input=output end))
   ["alphabet","digits","punctuation","whitespace","empty","mixed"]
 val _=T.check("banner/unknown-glyph-productive-prefix",fn()=>
   text(N.Q.take 4(N.say(N.chars "@")))="\n\n\n\n")
end
