structure Benchmark=struct
 val name="simple-nofib-strict"
 structure Check=BenchSimpleCheckFn(val strict=true val report=false val gridMax=8)
 val run=Check.run
end
