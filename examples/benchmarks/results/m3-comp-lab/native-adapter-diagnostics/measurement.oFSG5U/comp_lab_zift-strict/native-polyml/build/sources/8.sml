structure Benchmark=struct
 val name="comp_lab_zift-strict"
 structure Kernel=BenchCompLabFn(BenchStrict)
 structure Check=BenchCompLabCheckFn(Kernel)
 val run=Check.run true
end
