structure Benchmark=struct
 val name="comp_lab_nozift-strict"
 structure Kernel=BenchCompLabFn(BenchStrict)
 structure Check=BenchCompLabCheckFn(Kernel)
 val run=Check.run false
end
