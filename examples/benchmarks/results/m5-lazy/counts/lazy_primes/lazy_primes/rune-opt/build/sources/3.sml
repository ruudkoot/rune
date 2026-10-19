(* Sandmark lazy_primes: strict heads, memoized tails, predicate-removing filter. *)
structure BenchOcamlPrimes =
struct
  datatype 'a stream = Cons of 'a * 'a stream BenchLazy.delay
  fun head (Cons (value,_)) = value
  fun tail (Cons (_,rest)) = BenchLazy.force rest
  fun from n = Cons(n,BenchLazy.delay(fn () => from(n+1)))
  fun take 0 _ = []
    | take n stream = head stream :: take(n-1)(tail stream)
  fun drop 0 stream = stream
    | drop n stream = drop(n-1)(tail stream)
  fun filter predicate stream =
    if predicate(head stream) then filter predicate (tail stream)
    else Cons(head stream,BenchLazy.delay(fn () => filter predicate (tail stream)))
  fun sieve stream = Cons(head stream,BenchLazy.delay(fn () =>
    sieve(filter(fn x => x mod head stream=0)(tail stream))))
  val primes = sieve(from 2)
  fun nth n =
    case take 1 (drop(n-1)primes) of
      [prime] => prime
    | _ => raise Fail "impossible prime result"
end
