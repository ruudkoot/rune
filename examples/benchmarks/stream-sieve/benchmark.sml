(* streams.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure Streams : sig

    type 'a t

    val make : 'a * (unit -> 'a t) -> 'a t

    val unfold : 'a t -> 'a * 'a t

    val get : 'a t * int -> 'a

    val take : 'a t * int -> 'a list

  end = struct

    datatype 'a t = S of 'a * (unit -> 'a t)

    val make = S

    fun unfold (S(fst, thunk)) = (fst, thunk())

    fun get (strm, n) = if (n < 0)
          then raise Subscript
          else let
            fun lp (0, S(fst, _)) = fst
              | lp (n, S(_, thunk)) = lp (n-1, thunk())
            in
              lp (n, strm)
            end

    fun take (strm, n) = if (n < 0)
          then raise Subscript
          else let
            fun lp (0, _) = []
              | lp (n, S(fst, thunk)) = fst :: lp(n-1, thunk())
            in
              lp (n, strm)
            end

  end

(* sieve.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure Sieve : sig

    val primes : int Streams.t

  end = struct

    fun countFromN n = Streams.make (n, fn () => countFromN (n+1))

    fun sift (n, strm) = let
          val (k, strm') = Streams.unfold strm
          in
            if Int.rem(k, n) = 0
              then sift (n, strm')
              else Streams.make(k, fn () => sift (n, strm'))
          end

    (* Sieve of Eratosthenes *)
    fun sieve strm = let
          val (k, strm') = Streams.unfold strm
          in
            Streams.make (k, fn () => sieve (sift (k, strm')))
          end

    val primes = sieve (countFromN 2)

  end

structure Benchmark =
struct
  val name="stream-sieve"
  fun run [index]=Int.toString(Streams.get(Sieve.primes,BenchInput.between(0,20000)(BenchInput.integer index)))
  | run _=raise Fail "stream-sieve expects zero-based prime index"
end
