functor BenchPrettyDriverFn (K : sig val run : int -> int -> (char -> unit) -> unit end) =
struct
  structure Check = PrettyCheckFn (K)
  fun run [width, words, reference] =
    let val w = BenchInput.between (0, 65535) (BenchInput.integer width)
        val n = BenchInput.between (0, 5000) (BenchInput.integer words)
        val count = Check.run w n reference
    in Int.toString w ^ ":" ^ Int.toString n ^ ":" ^ Int.toString count end
    | run _ = raise Fail "pretty expects width, word count and complete output reference"
end
