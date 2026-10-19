functor BenchHartelFftDriverFn (K : sig
  val reference : int -> (real * real) vector
  val run : int -> (real * real) vector -> string
end) =
struct
  fun run [size,repetitions] =
    let val coarse=BenchInput.between(0,5)(BenchInput.integer size)
        val repeats=BenchInput.between(1,360)(BenchInput.integer repetitions)
        val expected=K.reference coarse
        val n=64*Word32.toInt(Word32.<<(0w1,Word.fromInt coarse))
        val wanted=Int.toString(117*n)^"/"^Int.toString n
        fun loop(0,bytes)=Int.toString repeats^":"^wanted^":"^Int.toString bytes
          |loop(left,bytes)=
             let val observed=K.run coarse expected
                 val _=if observed=wanted then()else raise Fail "incorrect result: FFT status output differs"
             in loop(left-1,bytes+String.size observed+1)end
    in loop(repeats,0)end
    |run _=raise Fail "Hartel FFT expects input-doubling count and repetitions"
end
