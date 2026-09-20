(* CharVectorSlice: its slice is the substring of Substring, so it is written
   on Substring rather than being an instance of RuneMonoVectorSliceFn. The
   -i functions pass the index in the slice.

   Implements: MONO_VECTOR_SLICE where type slice = Substring.substring where
   type vector = String.string where type elem = char *)
structure CharVectorSlice : MONO_VECTOR_SLICE =
struct
  type elem = char
  type vector = string
  type slice = Substring.substring

  val length = Substring.size
  val sub = Substring.sub
  val full = Substring.full
  val slice = Substring.extract
  val subslice = Substring.slice
  val base = Substring.base
  val vector = Substring.string
  val concat = Substring.concat
  val isEmpty = Substring.isEmpty
  val getItem = Substring.getc

  fun foldli f init sl =
    let val n = length sl
        fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, sub (sl, k), acc))
    in go (0, init) end
  fun foldri f init sl =
    let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, sub (sl, k), acc))
    in go (length sl - 1, init) end
  val foldl = Substring.foldl
  val foldr = Substring.foldr
  fun appi f sl = foldli (fn (k, c, ()) => f (k, c)) () sl
  val app = Substring.app
  fun mapi f sl = CharVector.tabulate (length sl, fn k => f (k, sub (sl, k)))
  fun map f sl = mapi (fn (_, c) => f c) sl

  fun findi p sl =
    let
      val n = length sl
      fun go k =
        if k >= n then NONE
        else let val c = sub (sl, k) in if p (k, c) then SOME (k, c) else go (k + 1) end
    in go 0 end
  fun find p sl = case findi (fn (_, c) => p c) sl of SOME (_, c) => SOME c | NONE => NONE
  fun exists p sl = case find p sl of SOME _ => true | NONE => false
  fun all p sl = not (exists (fn c => not (p c)) sl)
  val collate = Substring.collate
end
