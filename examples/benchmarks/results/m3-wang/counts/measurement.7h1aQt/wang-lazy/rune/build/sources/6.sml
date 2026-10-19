functor BenchWangDriverFn (K : sig val run : int -> string end) =
struct
  fun run [size,repetitions] =
    let val n = BenchInput.between (2,150) (BenchInput.integer size)
        val repeats = BenchInput.between (1,500) (BenchInput.integer repetitions)
        val expected = Int.toString (95*n*n+292*n+130) ^ "/" ^ Int.toString (2*n*n+5*n)
        fun loop (0,bytes) = Int.toString repeats ^ ":" ^ expected ^ ":" ^ Int.toString bytes
          | loop (left,bytes) =
              let val observed = K.run n
                  val _ = if observed = expected then ()
                    else raise Fail "incorrect result: rendered solution checksum differs"
              in loop (left-1,bytes+String.size observed+1) end
    in loop (repeats,0) end
    | run _ = raise Fail "Wang solver expects block size and repetition count"
end
