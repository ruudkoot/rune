structure FemReportPilot=struct
 structure N=BenchFemFn(val strict=false)
 structure E=BenchFemFn(val strict=true)
 structure NR=BenchFemReportFn(N)
 structure ER=BenchFemReportFn(E)
 fun read file=let val stream=TextIO.openIn file in TextIO.inputAll stream before TextIO.closeIn stream end
 fun write file text=let val stream=TextIO.openOut file in TextIO.output(stream,text);TextIO.closeOut stream end
 fun test file=
   let val input=read("source/"^file) val wanted=read(file^".report")
       val nd=N.database input val nu=N.displacement nd val nf=N.forces nd nu
       val actual=NR.render nd nu nf
       val _=write("need-"^file^".report")actual
       val _=if actual=wanted then print("PASS need report "^file^"\n")else raise Fail("need report "^file)
       val ed=E.database input val eu=E.displacement ed val ef=E.forces ed eu
       val actual=ER.render ed eu ef
       val _=write("strict-"^file^".report")actual
       val _=if actual=wanted then print("PASS strict report "^file^"\n")else raise Fail("strict report "^file)
   in TextIO.flushOut TextIO.stdOut end
 val _=List.app test["data.0","data.1","data.2","fem.stdin"]
end
