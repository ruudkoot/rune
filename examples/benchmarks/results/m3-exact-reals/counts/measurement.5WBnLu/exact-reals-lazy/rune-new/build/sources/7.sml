functor BenchExactRealsDriverFn (K : sig val run : int -> string end) =
struct
  fun run [argument]=
    let val count=BenchInput.between(0,800)(BenchInput.integer argument)
        val result=K.run count
        val expected="0."^String.implode(List.tabulate(40,fn _=> #"0"))
    in if result=expected then result else raise Fail "incorrect result: exact-real sum is not zero to forty digits"end
    |run _=raise Fail "exact reals expects an integer summation limit"
end
