structure Benchmark=struct
 val name="nucleic2-strict"
 structure Kernel=BenchNucleic2Fn(structure D=BenchStrict val shared=false)
 structure Check=BenchNucleic2CheckFn(Kernel)
 val run=Check.run
end
