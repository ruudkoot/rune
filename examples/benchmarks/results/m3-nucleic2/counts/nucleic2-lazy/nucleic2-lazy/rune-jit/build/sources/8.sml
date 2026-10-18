structure Benchmark=struct
 val name="nucleic2-lazy"
 structure Kernel=BenchNucleic2Fn(structure D=BenchNeed val shared=false)
 structure Check=BenchNucleic2CheckFn(Kernel)
 val run=Check.run
end
