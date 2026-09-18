(* One of the functors behind the monomorphic vectors, arrays and slices. Each
   is in a file of its own, and so is each application, because a program
   pays for what it loads: BinIO needs Word8Vector and nothing else. *)
functor RuneMonoArraySliceFn (structure V : MONO_VECTOR
                              structure A : MONO_ARRAY where type elem = V.elem where type vector = V.vector
                              structure VS : MONO_VECTOR_SLICE where type elem = V.elem where type vector = V.vector) =
struct
  type elem = V.elem
  type array = A.array
  type vector = V.vector
  type vector_slice = VS.slice
  datatype slice = Slice of array * int * int

  fun length (Slice (_, _, n)) = n
  fun base (Slice t) = t
  fun isEmpty (Slice (_, _, n)) = n = 0
  fun full a = Slice (a, 0, A.length a)
  fun slice (a, i, NONE) =
      let val len = A.length a
      in if i < 0 orelse i > len then raise Subscript else Slice (a, i, len - i) end
    | slice (a, i, SOME n) =
      let val len = A.length a
      in if i < 0 orelse n < 0 orelse i > len orelse n > len - i then raise Subscript else Slice (a, i, n) end
  fun subslice (Slice (a, i, n), j, NONE) =
      if j < 0 orelse j > n then raise Subscript else Slice (a, i + j, n - j)
    | subslice (Slice (a, i, n), j, SOME m) =
      if j < 0 orelse m < 0 orelse j > n orelse m > n - j then raise Subscript else Slice (a, i + j, m)
  fun sub (Slice (a, i, n), k) = if k < 0 orelse k >= n then raise Subscript else A.sub (a, i + k)
  fun update (Slice (a, i, n), k, x) = if k < 0 orelse k >= n then raise Subscript else A.update (a, i + k, x)
  fun getItem (Slice (a, i, n)) = if n = 0 then NONE else SOME (A.sub (a, i), Slice (a, i + 1, n - 1))

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

  (* upwards when the destination is below the source, downwards otherwise:
     right also when dst is the base array of src and the ranges overlap *)
  fun copy {src = Slice (a, i, n), dst, di} =
    if di < 0 orelse di > A.length dst - n then raise Subscript
    else if di <= i then
      let fun up k = if k >= n then () else (A.update (dst, di + k, A.sub (a, i + k)); up (k + 1))
      in up 0 end
    else
      let fun down k = if k < 0 then () else (A.update (dst, di + k, A.sub (a, i + k)); down (k - 1))
      in down (n - 1) end
  fun copyVec {src : vector_slice, dst, di} =
    if di < 0 orelse di > A.length dst - VS.length src then raise Subscript
    else VS.appi (fn (k, x) => A.update (dst, di + k, x)) src

  fun modifyi f (s : slice) =
    let val n = length s
        fun go k = if k >= n then () else (update (s, k, f (k, sub (s, k))); go (k + 1))
    in go 0 end
  fun modify f s = modifyi (fn (_, x) => f x) s
end
