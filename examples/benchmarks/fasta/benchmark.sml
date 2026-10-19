structure Benchmark =
struct
  val name = "fasta"
  fun run [size,reference] =
    let val n = BenchInput.between(1,25000000)(BenchInput.integer size)
        val actual = BenchFasta.output n
        val file = TextIO.openIn reference
        val expected = TextIO.inputAll file
        val _ = TextIO.closeIn file
        val _ = if actual=expected then () else raise Fail "fasta complete output differs"
    in Int.toString(String.size actual) end
    | run _ = raise Fail "fasta expects size reference"
end
