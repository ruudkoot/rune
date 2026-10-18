structure FulsomCheckPilot=
struct
 structure N=BenchFulsomFn(BenchNeed)
 structure E=BenchFulsomFn(BenchStrict)
 structure NC=BenchFulsomCheckFn(N)
 structure EC=BenchFulsomCheckFn(E)
 val _=print(NC.run["1","5","tests/out/benchmarks/nofib-fulsom-originals/depth-5.hex","8553150556328418559"]^"\n")
 val _=print(EC.run["1","5","tests/out/benchmarks/nofib-fulsom-originals/depth-5.hex","8553150556328418559"]^"\n")
end
