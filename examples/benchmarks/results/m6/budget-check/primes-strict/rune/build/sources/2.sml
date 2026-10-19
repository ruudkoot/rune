(* SML implementations of the finite iterative sieve in nofib
   imaginary/primes/Main.hs. The n-th element uses zero-based indexing.
   Provenance and evaluation-style differences are documented in README.md. *)
structure BenchPrimes =
struct
  datatype 'a cell = Pending of unit -> 'a | Value of 'a
  type 'a delay = 'a cell ref
  fun delay f = ref (Pending f)
  fun force d =
    case !d of
      Value x => x
    | Pending f => let val x = f () in d := Value x; x end

  datatype stream = Empty | More of int * stream delay

  fun interval (lo, hi) =
    if lo > hi then Empty else More (lo, delay (fn () => interval (lo + 1, hi)))

  fun filter p Empty = Empty
    | filter p (More (x, tail)) =
        if p x then More (x, delay (fn () => filter p (force tail)))
        else filter p (force tail)

  fun lazy n =
    let
      fun nth (0, More (p, _)) = p
        | nth (left, More (p, tail)) =
            nth (left - 1, filter (fn x => x mod p <> 0) (force tail))
        | nth (_, Empty) = raise Fail "sieve interval exhausted"
    in nth (n, interval (2, n * n)) end

  fun strict n =
    let
      fun nth (0, p :: _) = p
        | nth (left, p :: rest) = nth (left - 1, List.filter (fn x => x mod p <> 0) rest)
        | nth (_, []) = raise Fail "sieve interval exhausted"
    in nth (n, List.tabulate (n * n - 1, fn i => i + 2)) end

  fun run sieve [size, repetitions] =
        let
          val n = BenchInput.between (3, 2000) (BenchInput.integer size)
          val count = BenchInput.between (1, 10000) (BenchInput.integer repetitions)
        in IntInf.toString (BenchInput.repeat count (fn () => sieve n)) end
    | run _ _ = raise Fail "primes expects size repetitions"
end
