(* One of the functors behind the monomorphic vectors, arrays and slices. Each
   is in a file of its own, and so is each application, because a program
   pays for what it loads: BinIO needs Word8Vector and nothing else. *)
functor RuneMonoVectorSliceFn (structure V : MONO_VECTOR) =
struct
  type elem = V.elem
  type vector = V.vector
  datatype slice = Slice of vector * int * int

  fun length (Slice (_, _, n)) = n
  fun base (Slice t) = t
  fun isEmpty (Slice (_, _, n)) = n = 0
  fun full v = Slice (v, 0, V.length v)
  fun slice (v, i, NONE) =
      let val len = V.length v
      in if i < 0 orelse i > len then raise Subscript else Slice (v, i, len - i) end
    | slice (v, i, SOME n) =
      let val len = V.length v
      in if i < 0 orelse n < 0 orelse i > len orelse n > len - i then raise Subscript else Slice (v, i, n) end
  fun subslice (Slice (v, i, n), j, NONE) =
      if j < 0 orelse j > n then raise Subscript else Slice (v, i + j, n - j)
    | subslice (Slice (v, i, n), j, SOME m) =
      if j < 0 orelse m < 0 orelse j > n orelse m > n - j then raise Subscript else Slice (v, i + j, m)
  fun sub (Slice (v, i, n), k) = if k < 0 orelse k >= n then raise Subscript else V.sub (v, i + k)
  fun getItem (Slice (v, i, n)) = if n = 0 then NONE else SOME (V.sub (v, i), Slice (v, i + 1, n - 1))

  fun foldli f init (s : slice) =
    let val n = length s
        fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, sub (s, k), acc))
    in go (0, init) end
  fun foldri f init (s : slice) =
    let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, sub (s, k), acc))
    in go (length s - 1, init) end
  fun foldl f init s = foldli (fn (_, x, acc) => f (x, acc)) init s
  fun foldr f init s = foldri (fn (_, x, acc) => f (x, acc)) init s
  fun appi f s = foldli (fn (k, x, ()) => f (k, x)) () s
  fun app f s = foldli (fn (_, x, ()) => f x) () s
  fun findi p (s : slice) =
    let
      val n = length s
      fun go k =
        if k >= n then NONE
        else let val x = sub (s, k) in if p (k, x) then SOME (k, x) else go (k + 1) end
    in go 0 end
  fun find p s = case findi (fn (_, x) => p x) s of SOME (_, x) => SOME x | NONE => NONE
  fun exists p s = case find p s of SOME _ => true | NONE => false
  fun all p s = not (exists (fn x => not (p x)) s)
  fun collate cmp (a : slice, b : slice) =
    let
      val n = length a and m = length b
      fun go k =
        if k >= n then (if k >= m then EQUAL else LESS)
        else if k >= m then GREATER
        else case cmp (sub (a, k), sub (b, k)) of EQUAL => go (k + 1) | other => other
    in go 0 end

  fun vector (s : slice) = V.tabulate (length s, fn k => sub (s, k))
  fun concat l = V.concat (List.map vector l)
  fun mapi f (s : slice) = V.tabulate (length s, fn k => f (k, sub (s, k)))
  fun map f s = mapi (fn (_, x) => f x) s
end
