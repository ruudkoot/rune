(* Word8Vector and Word8VectorSlice: a vector of bytes is a string
   underneath, and a slice of one is a substring, so taking a slice's vector
   is one primitive and not a walk over its elements.

   The specification leaves `Word8Vector.vector` abstract, and it is abstract
   here: no other system makes it a `string` either, and a program goes
   between the two through `Byte`. The two conversions below are how the rest
   of the library crosses, and the seal file keeps them from a program. *)

(* The slice, as the library sees it: the members of the specification and
   the two conversions to and from a substring. `MONO_VECTOR_BYTES`, the
   vector's, is in mono_sigs.sml, where `Substring` is not yet in scope. *)
signature MONO_VECTOR_SLICE_BYTES =
sig
  include MONO_VECTOR_SLICE
  val toSubstring : slice -> Substring.substring
  val fromSubstring : Substring.substring -> slice
end

(* The sealing boundary of the whole byte family: the vector and its slice
   are declared on the representation they share, and this one opaque
   ascription makes the type abstract for everyone outside. Nothing inside
   converts. *)
structure RuneByteVector :>
sig
  structure V : MONO_VECTOR_BYTES where type elem = Word8.word
  structure S : MONO_VECTOR_SLICE_BYTES where type vector = V.vector where type elem = Word8.word
end =
struct
  structure Impl = RuneStringVectorFn (type elem = Word8.word
                                       fun toChar w = chr (Word8.toInt w)
                                       fun fromChar c = Word8.fromInt (ord c))
  structure V =
  struct
    open Impl
    fun toString (v : vector) : string = v
    fun fromString (s : string) : vector = s
  end
  structure S =
  struct
    type elem = Word8.word
    type vector = string
    type slice = Substring.substring
    fun toSubstring (sl : slice) : Substring.substring = sl
    fun fromSubstring (ss : Substring.substring) : slice = ss

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
    fun mapi f sl = Impl.tabulate (length sl, fn k => f (k, sub (sl, k)))
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
end

(* Implements: MONO_VECTOR where type elem = Word8.word *)
structure Word8Vector = RuneByteVector.V
(* Implements: MONO_VECTOR_SLICE where type vector = Word8Vector.vector where
   type elem = Word8.word *)
structure Word8VectorSlice = RuneByteVector.S
