functor BenchBoyerTwoDriverFn (K : sig val test : int -> bool end) =
struct
  fun run [argument] =
    let val n = BenchInput.between (0, 3000) (BenchInput.integer argument)
        fun loop i = if i > n then () else
          if K.test i then loop (i + 1)
          else raise Fail ("incorrect result: Boyer2 rejected theorem " ^ Int.toString i)
        val _ = loop 1
    in Int.toString n ^ ":proved" end
    | run _ = raise Fail "Boyer2 expects theorem count"
end
