(* Pseudo-random numbers: SplitMix64, a generator that can be split into two
   independent ones and read as a hash of a counter.

   A generator is a value, not a place: every draw returns the next
   generator beside the number, and the same generator always gives the same
   numbers. `split` makes two generators from one, for parts of a
   computation that draw independently. The numbers are those of Vigna's
   splitmix64.c and of Java's `SplittableRandom` (Steele, Lea and Flood,
   "Fast splittable pseudorandom number generators", OOPSLA 2014). They are
   good for testing and simulation, and no good for secrets.

   Area: Random numbers *)
signature RANDOM =
sig
  (* A generator: a seed and an odd increment, the gamma. *)
  type gen

  (* `fromSeed s` is the generator of the seed `s`, with the gamma of
     splitmix64.c, so that it draws the numbers that program draws from
     `s`.

     Example: `#1 (word64 (fromSeed 0w0)) = 0wxE220A8397B1DCDAF` *)
  val fromSeed : Word64.word -> gen

  (* `fromEntropy ()` is a generator seeded afresh at every call.

     The seed is the operating system's random bytes (/dev/urandom) where
     there are any, and the clock otherwise. A test that must be repeated
     takes `fromSeed` instead. *)
  val fromEntropy : unit -> gen

  (* `split g` is two generators whose numbers are independent of each other.

     The first is `g` moved on, the second a new one with a gamma of its own,
     as Java's SplittableRandom.split makes it. *)
  val split : gen -> gen * gen

  (* `word64 g` is the next number of `g`, uniform over all 64-bit words,
     and the generator after it. *)
  val word64 : gen -> Word64.word * gen

  (* `below n g` is a number uniform in `[0, n)` and the generator after
     it, by Lemire's multiplication with rejection, which divides only when
     it must.

     Raises: `Domain` if `n` is zero.

     Law: `#1 (below n g) < n = true` for `n <> 0w0`

     Example: `#1 (below 0w1 (fromSeed 0w3)) = 0w0` *)
  val below : Word64.word -> gen -> Word64.word * gen

  (* `int (lo, hi) g` is an integer uniform in `[lo, hi]`, and the generator
     after it.

     Raises: `Domain` if `hi < lo`.

     Example: `let val (d, _) = int (1, 6) (fromSeed 0w7) in 1 <= d andalso d
     <= 6 end` *)
  val int : int * int -> gen -> int * gen

  (* `real g` is a real uniform in `[0, 1)`, a multiple of `2^~53`, and the
     generator after it.

     Example: `let val (x, _) = real (fromSeed 0w1) in 0.0 <= x andalso x <
     1.0 end` *)
  val real : gen -> real * gen

  (* `bool g` is `true` or `false`, each half the time, and the generator
     after it. *)
  val bool : gen -> bool * gen

  (* `hash w` is SplitMix64's finaliser of `w`, a bijection of the 64-bit words.

     It mixes every bit into every other. `hash (s + k * g)` for a counter `k`
     is the generator read at `k`: that is how a tree of generators is read
     without splitting.

     Example: `hash 0w0 = 0w0` *)
  val hash : Word64.word -> Word64.word

  (* `hashString s` is a 64-bit hash of the characters of `s`, for a seed
     named by a string. It is not a cryptographic hash.

     Example: `hashString "a" <> hashString "b"` *)
  val hashString : string -> Word64.word

  (* `toString g` is the seed and the gamma of `g` in hexadecimal, with a
     colon between them: a token from which `fromString` makes `g` again.

     Example: `toString (fromSeed 0w0) = "0000000000000000:9E3779B97F4A7C15"` *)
  val toString : gen -> string

  (* `fromString s` is the generator of a token of `toString`, or `NONE`
     when `s` is none: two hexadecimal numbers with a colon between them,
     the second odd.

     Law: `Option.map toString (fromString (toString g)) = SOME (toString g)`

     Example: `not (isSome (fromString "12:34"))`, for the gamma is even *)
  val fromString : string -> gen option
end
