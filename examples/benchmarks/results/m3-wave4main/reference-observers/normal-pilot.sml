structure WaveNormalPilot=
struct
 structure N=BenchWave4Fn(BenchNeed)
 structure E=BenchWave4Fn(BenchStrict)
 structure NC=BenchWaveCheckFn(N)
 structure EC=BenchWaveCheckFn(E)
 val _=print(NC.run["500","80","tests/out/benchmarks/hartel-wave4main-originals/steps-80.reference"]^" lazy\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print(EC.run["500","80","tests/out/benchmarks/hartel-wave4main-originals/steps-80.reference"]^" strict\n")
end
