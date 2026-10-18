structure Benchmark=struct
 val name="nucleic2-shared-lazy"
 structure Kernel=BenchNucleic2Fn(structure D=BenchNeed val shared=true)
 structure Check=BenchNucleic2CheckFn(Kernel)
 val run=Check.run
end
