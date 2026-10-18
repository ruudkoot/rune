structure FemCheckPilot=struct
 structure N=BenchFemFn(val strict=false)
 structure E=BenchFemFn(val strict=true)
 structure NC=BenchFemCheckFn(N)
 structure EC=BenchFemCheckFn(E)
 fun test file=
   let val a=NC.run["1","source/"^file,file^".report",file^".reference"]
       val b=EC.run["1","source/"^file,file^".report",file^".reference"]
       val _=if a=b then()else raise Fail"FEM policy result mismatch"
   in print("PASS "^file^" "^a^"\n");TextIO.flushOut TextIO.stdOut end
 val _=List.app test["data.0","data.1","data.2","fem.stdin"]
end
