structure Benchmark=struct
 val name="simple-nofib-report-strict"
 structure Check=BenchSimpleCheckFn(val strict=true val report=true val gridMax=100)
 val run=Check.run
end
