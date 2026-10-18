functor BenchHappyCheckFn(K:sig
 val emitOutput:string->(char->unit)->(char->unit)->unit
end)=struct
 fun read path=let val f=TextIO.openIn path
   in(TextIO.inputAll f before TextIO.closeIn f)
     handle e=>(TextIO.closeIn f;raise e)end
 fun compareFile actualPath expectedPath=
   let val actual=TextIO.openIn actualPath
       val expected=TextIO.openIn expectedPath
       fun loop count=case(TextIO.input1 actual,TextIO.input1 expected)of
            (NONE,NONE)=>count
           |(SOME a,SOME b)=>if a=b then loop(count+1)
              else raise Fail("incorrect result: Happy parser byte "^Int.toString count)
           |_=>raise Fail"incorrect result: Happy parser length"
   in(loop 0 before(TextIO.closeIn actual;TextIO.closeIn expected))
     handle e=>(TextIO.closeIn actual;TextIO.closeIn expected;raise e)end
 fun run[inputPath,referencePath,warningsPath]=
   let val source=read inputPath
       val warnings=read warningsPath
       val warningCount=ref 0
       fun warning c=
         let val index= !warningCount
         in if index<String.size warnings andalso c=String.sub(warnings,index)then
              (TextIO.output1(TextIO.stdErr,c);warningCount:=index+1)
            else raise Fail"incorrect result: Happy warning bytes"end
       val output=TextIO.openOut"TestInput.hs"
       val _=(K.emitOutput source warning(fn c=>TextIO.output1(output,c));TextIO.closeOut output)
         handle e=>(TextIO.closeOut output;raise e)
       val _=if !warningCount=String.size warnings then()
         else raise Fail"incorrect result: missing Happy warnings"
       val bytes=compareFile"TestInput.hs"referencePath
   in Int.toString bytes^":"^Int.toString(!warningCount)end
   |run _=raise Fail"expected grammar, complete parser reference and warning reference"
end
