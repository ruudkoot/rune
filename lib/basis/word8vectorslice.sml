(* Word8VectorSlice: a Word8Vector.vector is a string, so a slice of one is a
   substring, and taking its vector is one primitive rather than a walk over
   the elements.

   Implements: MONO_VECTOR_SLICE where type vector = Word8Vector.vector where
   type elem = Word8.word *)
structure Word8VectorSlice : MONO_VECTOR_SLICE =
struct
  type elem = Word8.word
  type vector = Word8Vector.vector
  type slice = Substring.substring

  val length = Substring.size
  fun sub (sl, i) = Word8.fromInt (ord (Substring.sub (sl, i)))
  val full = Substring.full
  val slice = Substring.extract
  val subslice = Substring.slice
  val base = Substring.base
  val vector = Substring.string
  val concat = Substring.concat
  val isEmpty = Substring.isEmpty
  fun getItem sl =
    case Substring.getc sl of
      SOME (c, rest) => SOME (Word8.fromInt (ord c), rest)
    | NONE => NONE

  fun foldli f init sl =
    let val n = length sl
        fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, sub (sl, k), acc))
    in go (0, init) end
  fun foldri f init sl =
    let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, sub (sl, k), acc))
    in go (length sl - 1, init) end
  fun foldl f init sl = foldli (fn (_, x, acc) => f (x, acc)) init sl
  fun foldr f init sl = foldri (fn (_, x, acc) => f (x, acc)) init sl
  fun appi f sl = foldli (fn (k, x, ()) => f (k, x)) () sl
  fun app f sl = foldli (fn (_, x, ()) => f x) () sl
  fun mapi f sl = Word8Vector.tabulate (length sl, fn k => f (k, sub (sl, k)))
  fun map f sl = mapi (fn (_, x) => f x) sl

  fun findi p sl =
    let
      val n = length sl
      fun go k =
        if k >= n then NONE
        else let val x = sub (sl, k) in if p (k, x) then SOME (k, x) else go (k + 1) end
    in go 0 end
  fun find p sl = case findi (fn (_, x) => p x) sl of SOME (_, x) => SOME x | NONE => NONE
  fun exists p sl = case find p sl of SOME _ => true | NONE => false
  fun all p sl = not (exists (fn x => not (p x)) sl)
  fun collate cmp (a, b) =
    let
      val n = length a and m = length b
      fun go k =
        if k >= n then (if k >= m then EQUAL else LESS)
        else if k >= m then GREATER
        else case cmp (sub (a, k), sub (b, k)) of EQUAL => go (k + 1) | other => other
    in go 0 end
end
