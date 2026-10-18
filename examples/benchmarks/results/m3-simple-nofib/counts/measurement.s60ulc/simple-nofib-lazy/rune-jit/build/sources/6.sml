structure Benchmark=struct
 val name="simple-nofib-lazy"
 structure Check=BenchSimpleCheckFn(val strict=false val report=false val gridMax=100)
 val run=Check.run
end
