structure Benchmark =
struct
  val name = "knucleotide3-64"
  structure Kernel = BenchKnucleotidePackedFn (struct val threshold = 31 end)
  structure Check = PackedNucleotideCheckFn (Kernel)
  fun run [input, reference] = Int.toString (Check.run input reference)
    | run _ = raise Fail "packed nucleotide expects FASTA input and complete output reference"
end
