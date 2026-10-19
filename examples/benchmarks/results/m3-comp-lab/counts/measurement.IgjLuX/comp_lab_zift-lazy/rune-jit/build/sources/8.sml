structure Benchmark=struct
 val name="comp_lab_zift-lazy"
 structure Kernel=BenchCompLabFn(BenchNeed)
 structure Check=BenchCompLabCheckFn(Kernel)
 val run=Check.run true
end
