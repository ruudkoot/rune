structure FemNormalPilot=struct
 structure N=BenchFemFn(val strict=false)
 structure E=BenchFemFn(val strict=true)
 structure NC=BenchFemCheckFn(N)
 structure EC=BenchFemCheckFn(E)
 val args=["100","source/fem.stdin","fem.stdin.report","fem.stdin.reference"]
 val _=print("need "^NC.run args^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("strict "^EC.run args^"\n")
end
