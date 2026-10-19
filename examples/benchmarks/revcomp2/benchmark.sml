structure Benchmark =
struct
  val name = "revcomp2"
  fun run [input, reference] = Int.toString (RevcompCheck.run input reference)
    | run _ = raise Fail "revcomp2 expects FASTA input and complete output reference"
end
