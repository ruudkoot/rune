structure Benchmark=struct
 val name="simple-nofib-report-lazy"
 structure Check=BenchSimpleCheckFn(val strict=false val report=true val gridMax=8)
 val run=Check.run
end
