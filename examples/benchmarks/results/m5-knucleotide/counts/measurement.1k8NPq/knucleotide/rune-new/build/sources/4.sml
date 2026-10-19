structure Benchmark =
struct
  val name = "knucleotide"
  fun run [input, reference] = Int.toString (KnucleotideCheck.run input reference)
    | run _ = raise Fail "knucleotide expects FASTA input and complete output reference"
end
