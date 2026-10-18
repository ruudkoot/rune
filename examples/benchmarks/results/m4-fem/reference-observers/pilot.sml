structure FemPilot=struct
 structure N=BenchFemFn(val strict=false)
 structure E=BenchFemFn(val strict=true)
 structure NS=BenchFemSnapshotFn(N)
 structure ES=BenchFemSnapshotFn(E)
 fun read file=let val stream=TextIO.openIn file in TextIO.inputAll stream before TextIO.closeIn stream end
 fun write file text=let val stream=TextIO.openOut file in TextIO.output(stream,text);TextIO.closeOut stream end
 fun test file=
   let val text=read("source/"^file)
       val need=NS.render text
       val _=write("need-"^file^".observations")need
       val _=print("PASS completed need "^file^"\n")
       val _=TextIO.flushOut TextIO.stdOut
       val strict=ES.render text
       val _=write("strict-"^file^".observations")strict
       val _=print("PASS completed strict "^file^"\n")
   in TextIO.flushOut TextIO.stdOut end
 val _=List.app test["data.0","data.1","data.2","fem.stdin"]
end
