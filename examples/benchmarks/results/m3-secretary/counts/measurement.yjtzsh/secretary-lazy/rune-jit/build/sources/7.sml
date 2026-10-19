functor BenchSecretaryDriverFn (K : sig val run : int -> int -> int * real end) =
struct
  fun run [trials, path] =
    let val n = BenchInput.between (1, 50000) (BenchInput.integer trials)
        val results = List.map (K.run n) [35, 36, 37, 38, 39]
        val _ = SecretaryCheck.validate n results path
    in Int.toString n ^ ":checked" end
    | run _ = raise Fail "secretary expects trial count and result reference"
end
