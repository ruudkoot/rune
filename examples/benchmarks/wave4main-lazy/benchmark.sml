structure Benchmark=struct
 val name="wave4main-lazy"
 structure Kernel=BenchWave4Fn(BenchNeed)
 structure Check=BenchWaveCheckFn(Kernel)
 val run=Check.run
end
