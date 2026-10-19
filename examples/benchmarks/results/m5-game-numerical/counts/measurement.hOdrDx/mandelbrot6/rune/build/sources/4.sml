structure Benchmark =
struct
  val name="mandelbrot6"
  structure Check=BenchPBMCheckFn(BenchMandelbrotSix)
  fun run [size,path]=
    let val width=BenchInput.between(1,16000)(BenchInput.integer size)
        val bytes=Check.run width path
    in Int.toString width^":"^Int.toString bytes end
    | run _=raise Fail "Mandelbrot expects width and PBM reference"
end
