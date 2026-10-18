structure Benchmark=struct
 val name="simple-nofib-report-lazy"
 structure Check=BenchSimpleCheckFn(val strict=false val report=true val gridMax=100)
 val run=Check.run
end
