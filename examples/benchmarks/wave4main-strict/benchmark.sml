structure Benchmark=struct
 val name="wave4main-strict"
 structure Kernel=BenchWave4Fn(BenchStrict)
 structure Check=BenchWaveCheckFn(Kernel)
 val run=Check.run
end
