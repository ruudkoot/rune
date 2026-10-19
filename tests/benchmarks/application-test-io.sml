structure BenchApplicationTestIO=struct
 fun read path=let val f=TextIO.openIn path
   in(TextIO.inputAll f before TextIO.closeIn f)handle e=>(TextIO.closeIn f;raise e)end
 fun compare(label,expected,actual)=T.check(label,fn()=>
   if actual=expected then true else
     let val path="failure-"^String.map(fn c=>if Char.isAlphaNum c then c else #"-")label^".actual"
         val f=TextIO.openOut path
     in TextIO.output(f,actual);TextIO.closeOut f;false end)
end
