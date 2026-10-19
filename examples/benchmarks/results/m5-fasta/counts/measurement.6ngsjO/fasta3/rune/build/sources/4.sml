structure Benchmark =
struct
 val name="fasta3"
 fun run[size,aluPath,iubPath,homoPath]=
   let val n=BenchInput.between(1,25000000)(BenchInput.integer size)
       val alu=BenchFastaCycleCheck.read aluPath
       val iub=BenchFastaCycleCheck.read iubPath
       val homo=BenchFastaCycleCheck.read homoPath
   in Int.toString(BenchFastaCycleCheck.run BenchSandmarkFasta.run3 n alu iub homo)end
   | run _=raise Fail "fasta3 expects size alu-oracle iub-cycle homo-cycle"
end
