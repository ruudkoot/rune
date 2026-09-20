(* ArraySlice: an array, a start index and a length. The -i functions pass
   the index in the slice. *)
structure ArraySlice =
struct
  datatype 'a slice = Slice of 'a array * int * int

  fun length (Slice (_, _, n)) = n
  fun base (Slice t) = t
  fun isEmpty (Slice (_, _, n)) = n = 0
  fun full a = Slice (a, 0, Array.length a)

  (* The bounds are checked without a sum that could overflow. *)
  fun slice (a, i, NONE) =
      let val len = Array.length a
      in if i < 0 orelse i > len then raise Subscript else Slice (a, i, len - i) end
    | slice (a, i, SOME n) =
      let val len = Array.length a
      in if i < 0 orelse n < 0 orelse i > len orelse n > len - i then raise Subscript else Slice (a, i, n) end
  fun subslice (Slice (a, i, n), j, NONE) =
      if j < 0 orelse j > n then raise Subscript else Slice (a, i + j, n - j)
    | subslice (Slice (a, i, n), j, SOME m) =
      if j < 0 orelse m < 0 orelse j > n orelse m > n - j then raise Subscript else Slice (a, i + j, m)

  fun sub (Slice (a, i, n), k) = if k < 0 orelse k >= n then raise Subscript else Array.sub (a, i + k)
  fun update (Slice (a, i, n), k, x) = if k < 0 orelse k >= n then raise Subscript else Array.update (a, i + k, x)
  fun getItem (Slice (a, i, n)) = if n = 0 then NONE else SOME (Array.sub (a, i), Slice (a, i + 1, n - 1))

  fun foldli f init (Slice (a, i, n)) =
    let fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, Array.sub (a, i + k), acc))
    in go (0, init) end
  fun foldri f init (Slice (a, i, n)) =
    let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, Array.sub (a, i + k), acc))
    in go (n - 1, init) end
  fun foldl f init sl = foldli (fn (_, x, acc) => f (x, acc)) init sl
  fun foldr f init sl = foldri (fn (_, x, acc) => f (x, acc)) init sl

  fun vector sl = Vector.fromList (foldr (op ::) [] sl)

  (* When dst is the base array of src the ranges may overlap: copying
     upwards when the destination is below the source, downwards otherwise,
     reads every element before it is overwritten. *)
  fun copy {src = Slice (a, i, n), dst, di} =
    if di < 0 orelse di > Array.length dst - n then raise Subscript
    else if di <= i then
      let fun up k = if k >= n then () else (Array.update (dst, di + k, Array.sub (a, i + k)); up (k + 1))
      in up 0 end
    else
      let fun down k = if k < 0 then () else (Array.update (dst, di + k, Array.sub (a, i + k)); down (k - 1))
      in down (n - 1) end

  fun copyVec {src, dst, di} =
    if di < 0 orelse di > Array.length dst - VectorSlice.length src then raise Subscript
    else VectorSlice.appi (fn (k, x) => Array.update (dst, di + k, x)) src

  fun appi f sl = foldli (fn (k, x, ()) => f (k, x)) () sl
  fun app f sl = foldli (fn (_, x, ()) => f x) () sl
  fun modifyi f (Slice (a, i, n)) =
    let fun go k = if k >= n then () else (Array.update (a, i + k, f (k, Array.sub (a, i + k))); go (k + 1))
    in go 0 end
  fun modify f sl = modifyi (fn (_, x) => f x) sl

  fun findi p (Slice (a, i, n)) =
    let
      fun go k =
        if k >= n then NONE
        else let val x = Array.sub (a, i + k) in if p (k, x) then SOME (k, x) else go (k + 1) end
    in go 0 end
  fun find p sl = case findi (fn (_, x) => p x) sl of SOME (_, x) => SOME x | NONE => NONE
  fun exists p sl = case find p sl of SOME _ => true | NONE => false
  fun all p sl = not (exists (fn x => not (p x)) sl)

  fun collate cmp (Slice (a, i, n), Slice (b, j, m)) =
    let
      fun go k =
        if k >= n then (if k >= m then EQUAL else LESS)
        else if k >= m then GREATER
        else case cmp (Array.sub (a, i + k), Array.sub (b, j + k)) of EQUAL => go (k + 1) | other => other
    in go 0 end
end
