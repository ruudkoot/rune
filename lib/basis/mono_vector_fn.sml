(* One of the functors behind the monomorphic vectors, arrays and slices. Each
   is in a file of its own, and so is each application, because a program
   pays for what it loads: BinIO needs Word8Vector and nothing else. *)
(* A vector of characters or bytes is a string. *)
functor RuneStringVectorFn (type elem val toChar : elem -> char val fromChar : char -> elem) =
struct
  type vector = string
  type elem = elem
  val maxLen = String.maxSize
  val length = size
  fun sub (v : vector, i) = fromChar (String.sub (v, i))
  fun fromList l = implode (map toChar l)
  fun tabulate (n, f) =
    if n < 0 orelse n > maxLen then raise Size
    else implode (List.tabulate (n, fn i => toChar (f i)))
  fun update (v : vector, i, x) =
    if i < 0 orelse i >= size v then raise Subscript
    else String.concat [String.substring (v, 0, i), str (toChar x), String.extract (v, i + 1, NONE)]
  val concat = String.concat

  fun foldli f init (s : vector) =
    let val n = length s
        fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, sub (s, k), acc))
    in go (0, init) end
  fun foldri f init (s : vector) =
    let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, sub (s, k), acc))
    in go (length s - 1, init) end
  fun foldl f init s = foldli (fn (_, x, acc) => f (x, acc)) init s
  fun foldr f init s = foldri (fn (_, x, acc) => f (x, acc)) init s
  fun appi f s = foldli (fn (k, x, ()) => f (k, x)) () s
  fun app f s = foldli (fn (_, x, ()) => f x) () s
  fun findi p (s : vector) =
    let
      val n = length s
      fun go k =
        if k >= n then NONE
        else let val x = sub (s, k) in if p (k, x) then SOME (k, x) else go (k + 1) end
    in go 0 end
  fun find p s = case findi (fn (_, x) => p x) s of SOME (_, x) => SOME x | NONE => NONE
  fun exists p s = case find p s of SOME _ => true | NONE => false
  fun all p s = not (exists (fn x => not (p x)) s)
  fun collate cmp (a : vector, b : vector) =
    let
      val n = length a and m = length b
      fun go k =
        if k >= n then (if k >= m then EQUAL else LESS)
        else if k >= m then GREATER
        else case cmp (sub (a, k), sub (b, k)) of EQUAL => go (k + 1) | other => other
    in go 0 end

  fun mapi f v = tabulate (length v, fn i => f (i, sub (v, i)))
  fun map f v = mapi (fn (_, x) => f x) v
end
