structure Benchmark=struct
 val name="nucleic2-shared-strict"
 structure Kernel=BenchNucleic2Fn(structure D=BenchStrict val shared=true)
 structure Check=BenchNucleic2CheckFn(Kernel)
 val run=Check.run
end
