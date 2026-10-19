structure Benchmark =
struct
  val name = "knucleotide3-32"
  structure Kernel = BenchKnucleotidePackedFn (struct val threshold = 15 end)
  structure Check = PackedNucleotideCheckFn (Kernel)
  fun run [input, reference] = Int.toString (Check.run input reference)
    | run _ = raise Fail "packed nucleotide expects FASTA input and complete output reference"
end
