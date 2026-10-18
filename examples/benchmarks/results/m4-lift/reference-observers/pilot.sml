structure LiftPilot=struct
 structure N=BenchLiftFn(val strict=false)
 structure E=BenchLiftFn(val strict=true)
 structure NP=BenchLiftPrintFn(N)
 structure EP=BenchLiftPrintFn(E)
 fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
 fun write file text=let val f=TextIO.openOut file in TextIO.output(f,text);TextIO.closeOut f end
 fun test label actual expected=
   (write(label^".output")actual;
    if actual=read(expected^".reference")then print("PASS "^label^"\n")else raise Fail label;
    TextIO.flushOut TextIO.stdOut)
 val n=N.program()
 val e=E.program()
 val _=test"need-input"(NP.expression n)"input"
 val _=test"strict-input"(EP.expression e)"input"
 val _=test"need-plain"(NP.supercombinators(N.lambdaLift n))"plain"
 val _=test"strict-plain"(EP.supercombinators(E.lambdaLift e))"plain"
 val _=test"need-full"(NP.supercombinators(N.fullyLazyLift n))"full"
 val _=test"strict-full"(EP.supercombinators(E.fullyLazyLift e))"full"
end
