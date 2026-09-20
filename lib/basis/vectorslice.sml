(* VectorSlice: a vector, a start index and a length. The -i functions pass
   the index in the slice.

   Implements: VECTOR_SLICE *)
structure VectorSlice =
struct
  datatype 'a slice = Slice of 'a vector * int * int

  fun length (Slice (_, _, n)) = n
  fun base (Slice t) = t
  fun isEmpty (Slice (_, _, n)) = n = 0
  fun full v = Slice (v, 0, Vector.length v)

  (* The bounds are checked without a sum that could overflow. *)
  fun slice (v, i, NONE) =
      let val len = Vector.length v
      in if i < 0 orelse i > len then raise Subscript else Slice (v, i, len - i) end
    | slice (v, i, SOME n) =
      let val len = Vector.length v
      in if i < 0 orelse n < 0 orelse i > len orelse n > len - i then raise Subscript else Slice (v, i, n) end
  fun subslice (Slice (v, i, n), j, NONE) =
      if j < 0 orelse j > n then raise Subscript else Slice (v, i + j, n - j)
    | subslice (Slice (v, i, n), j, SOME m) =
      if j < 0 orelse m < 0 orelse j > n orelse m > n - j then raise Subscript else Slice (v, i + j, m)

  fun sub (Slice (v, i, n), k) = if k < 0 orelse k >= n then raise Subscript else Vector.sub (v, i + k)
  fun getItem (Slice (v, i, n)) = if n = 0 then NONE else SOME (Vector.sub (v, i), Slice (v, i + 1, n - 1))

  fun foldli f init (Slice (v, i, n)) =
    let fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, Vector.sub (v, i + k), acc))
    in go (0, init) end
  fun foldri f init (Slice (v, i, n)) =
    let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, Vector.sub (v, i + k), acc))
    in go (n - 1, init) end
  fun foldl f init sl = foldli (fn (_, x, acc) => f (x, acc)) init sl
  fun foldr f init sl = foldri (fn (_, x, acc) => f (x, acc)) init sl

  fun vector sl = Vector.fromList (foldr (op ::) [] sl)
  fun concat l = Vector.concat (List.map vector l)

  fun appi f sl = foldli (fn (k, x, ()) => f (k, x)) () sl
  fun app f sl = foldli (fn (_, x, ()) => f x) () sl
  fun mapi f sl = Vector.fromList (List.rev (foldli (fn (k, x, acc) => f (k, x) :: acc) [] sl))
  fun map f sl = mapi (fn (_, x) => f x) sl

  fun findi p (Slice (v, i, n)) =
    let
      fun go k =
        if k >= n then NONE
        else let val x = Vector.sub (v, i + k) in if p (k, x) then SOME (k, x) else go (k + 1) end
    in go 0 end
  fun find p sl = case findi (fn (_, x) => p x) sl of SOME (_, x) => SOME x | NONE => NONE
  fun exists p sl = case find p sl of SOME _ => true | NONE => false
  fun all p sl = not (exists (fn x => not (p x)) sl)

  fun collate cmp (Slice (v, i, n), Slice (w, j, m)) =
    let
      fun go k =
        if k >= n then (if k >= m then EQUAL else LESS)
        else if k >= m then GREATER
        else case cmp (Vector.sub (v, i + k), Vector.sub (w, j + k)) of EQUAL => go (k + 1) | other => other
    in go 0 end
end
