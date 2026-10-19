structure Benchmark =
struct
  val name="fft-sandmark"
  fun run [length] =
    let val n=BenchInput.between(1,1048576)(BenchInput.integer length)
        val _=BenchSandmarkFFT.run n
    in Int.toString n^":checked" end
    | run _=raise Fail "FFT expects a power-of-two length"
end
