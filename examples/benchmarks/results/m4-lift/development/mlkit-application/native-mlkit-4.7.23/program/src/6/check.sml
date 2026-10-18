functor BenchLiftCheckFn(K:sig
 type name=string BenchLazy.delay
 datatype constant=CNum of IntInf.int|CBool of bool|CFun of name
 datatype 'b exprNode=EConst of constant|EVar of name
  |EAp of 'b exprNode BenchLazy.delay*'b exprNode BenchLazy.delay
  |ELam of 'b list*'b exprNode BenchLazy.delay
  |ELet of bool*('b*'b exprNode BenchLazy.delay)list*'b exprNode BenchLazy.delay
 type 'b expr='b exprNode BenchLazy.delay
 val program:unit->name expr
 val lambdaLift:name expr->(name*name list*name expr)list
 val fullyLazyLift:name expr->(name*name list*name expr)list
end)=
struct
 structure L=BenchLazy
 structure P=BenchLiftPrintFn(K)
 structure W=Word64
 fun read file=let val f=TextIO.openIn file in
   (TextIO.inputAll f before TextIO.closeIn f)
   handle ex=>(TextIO.closeIn f;raise ex)end
 fun hash text=List.foldl(fn(c,h)=>W.+(W.fromInt(Char.ord c),W.*(h,0w31)))0w0(String.explode text)
 fun report input="\nInput expression "^P.expression input^
   "\nResult\n"^P.supercombinators(K.lambdaLift input)^
   "\nFully lazy \n"^P.supercombinators(K.fullyLazyLift input)^"\n"
 fun run[repsText,reportPath,hashText]=
   let val reps=BenchInput.between(0,100000)(BenchInput.integer repsText)
       val wanted=read reportPath
       val wantedHash=case W.fromString("0wx"^hashText)of SOME n=>n|NONE=>raise Fail"invalid lift hash"
       val input=L.delay K.program
       fun loop 0 count bytes=Int.toString count^":"^Int.toString bytes
         |loop n count bytes=let val text=report(L.force input)
             val _=if text=wanted andalso hash text=wantedHash then()
               else raise Fail"incorrect result: lift complete report or hash"
           in loop(n-1)(count+1)(bytes+String.size text)end
   in loop reps 0 0 end
 |run _=raise Fail"expected repetitions, report file and modular Word64 hash"
end
