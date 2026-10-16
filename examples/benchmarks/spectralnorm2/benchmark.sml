structure Benchmark =
struct
 val name="spectralnorm2"
 fun close actual expected=BenchInput.closeReal(actual,expected,2.0E~12,2.0E~12)
 fun run [size,reference]=
   let val n=BenchInput.between(1,5500)(BenchInput.integer size)
       val expected=case Real.fromString reference of SOME value=>value | NONE=>raise Fail "invalid norm reference"
       val actual=BenchSpectralNorm.run n
   in if close actual expected then Int.toString n^":checked"
      else raise Fail("spectral norm differs: "^Real.toString actual^", expected "^Real.toString expected)end
   | run _=raise Fail "spectralnorm expects matrix-size reference-value"
end
