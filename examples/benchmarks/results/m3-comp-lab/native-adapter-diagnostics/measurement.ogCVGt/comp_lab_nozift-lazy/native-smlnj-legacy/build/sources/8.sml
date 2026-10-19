structure Benchmark=struct
 val name="comp_lab_nozift-lazy"
 structure Kernel=BenchCompLabFn(BenchNeed)
 structure Check=BenchCompLabCheckFn(Kernel)
 val run=Check.run false
end
