structure BenchMiniParse=
struct
 datatype input=Input of{tokens:string vector,position:int ref}
 exception End
 fun read path=
   let val stream=TextIO.openIn path
       val text=(TextIO.inputAll stream before TextIO.closeIn stream)
         handle ex=>(TextIO.closeIn stream;raise ex)
       val tokens=String.tokens Char.isSpace(String.map(fn c=>if c= #"("orelse c= #")"then #" "else c)text)
   in Input{tokens=Vector.fromList tokens,position=ref 0}end
 fun next(Input{tokens,position})=
   if !position=Vector.length tokens then raise End
   else let val text=Vector.sub(tokens,!position)val _=position:= !position+1 in text end
 fun integer input=case Int.fromString(next input)of SOME n=>n|NONE=>raise Fail"invalid MiniLight integer"
 fun real input=case Real.fromString(next input)of SOME x=>x|NONE=>raise Fail"invalid MiniLight real"
 fun vector input=let val x=real input val y=real input val z=real input
   in BenchMiniVector.create x y z end
end
