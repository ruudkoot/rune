(* A stretch of an array, without a copy of it: a base array and a start and
   a length inside it.

   What `VECTOR_SLICE` is to a vector, this is to an array: a way to hand
   part of a sequence to a function for nothing. A slice is a window on the
   array, not a copy of it, so `update` through the slice changes the array,
   and a change to the array is seen through the slice.

   Positions inside a slice are counted from its own start.

   Area: Sequences

   See also: `ARRAY`, `VECTOR_SLICE`, `MONO_ARRAY_SLICE` *)
signature ARRAY_SLICE =
sig
  (* The type of slices of an array. *)
  type 'a slice

  (* ---- Elements ---- *)

  (* `length sl` is the number of elements of `sl`.

     Example: `length (slice (Array.fromList [1, 2, 3, 4], 1, SOME 2)) = 2` *)
  val length : 'a slice -> int

  (* `sub (sl, i)` is the element of `sl` at position `i`, counting from the start of the slice.

     Raises: `Subscript` if `i < 0` or `i >= length sl`.

     Law: `sub (slice (arr, i, NONE), k) = Array.sub (arr, i + k)` for `0 <= k
     andalso k < Array.length arr - i`

     Example: `sub (slice (Array.fromList [1, 2, 3, 4], 1, NONE), 0) = 2` *)
  val sub : 'a slice * int -> 'a

  (* `update (sl, i, x)` puts `x` at position `i` of `sl`, and so of the array it is a slice of.

     Raises: `Subscript` if `i < 0` or `i >= length sl`.

     Law: `(update (sl, i, x); sub (sl, i)) = x` for `0 <= i andalso i < length
     sl`

     Example: `let val a = Array.fromList [1, 2, 3] in update (slice (a, 1,
     NONE), 0, 9); Array.vector a end = Vector.fromList [1, 9, 3]` *)
  val update : 'a slice * int * 'a -> unit

  (* ---- Making a slice ---- *)

  (* `full arr` is the whole of `arr` as a slice: `slice (arr, 0, NONE)`.

     Law: `base (full arr) = (arr, 0, Array.length arr)`

     Example: `length (full (Array.fromList [1, 2, 3])) = 3` *)
  val full : 'a Array.array -> 'a slice

  (* `slice (arr, i, NONE)` is the stretch of `arr` from position `i` to its end, and `slice (arr, i, SOME n)` the `n` elements from `i`.

     Raises: `Subscript` if `i < 0` or `i > Array.length arr`, or, with `SOME
     n`, if `n < 0` or `i + n > Array.length arr`.

     Law: `base (slice (arr, i, SOME n)) = (arr, i, n)` when `(ignore (slice
     (arr, i, SOME n)); true)`

     Example: `vector (slice (Array.fromList [1, 2, 3, 4], 1, SOME 2)) =
     Vector.fromList [2, 3]`

     Reading: `ArraySlice.slice/Subscript-not-Overflow`. When `i + n` is no
     `int` the slice does not exist, and `Subscript` says so, never `Overflow`;
     `subslice`, `copy` and `copyVec` are the same with their sums, and so are
     the slices of the monomorphic arrays.

     Pinned by: `*ArraySlice.s*slice/SOME-Subscript-not-Overflow-sum-*`,
     `*ArraySlice.copy*/Subscript-not-Overflow*` *)
  val slice : 'a Array.array * int * int option -> 'a slice

  (* `subslice (sl, i, NONE)` is the stretch of `sl` from position `i` on, and `subslice (sl, i, SOME n)` the `n` elements from `i`.

     The bounds are those of `sl`, not of the array it is a slice of.

     Raises: `Subscript` if `i < 0` or `i > length sl`, or, with `SOME n`, if
     `n < 0` or `i + n > length sl`.

     Law: `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k
     andalso k < length sl - i`

     Example: `vector (subslice (slice (Array.fromList [1, 2, 3, 4], 1, NONE),
     1, SOME 1)) = Vector.fromList [3]` *)
  val subslice : 'a slice * int * int option -> 'a slice

  (* `base sl` is the triple of the array that `sl` is a stretch of, where it starts in that array, and how long it is.

     Example: `let val (_, i, n) = base (slice (Array.fromList [1, 2, 3, 4], 1,
     SOME 2)) in (i, n) end = (1, 2)` *)
  val base : 'a slice -> 'a Array.array * int * int

  (* `vector sl` is an immutable vector of the elements of `sl`, which is a copy.

     Law: `vector sl = Vector.tabulate (length sl, fn i => sub (sl, i))`

     Example: `vector (slice (Array.fromList [1, 2, 3], 1, NONE)) =
     Vector.fromList [2, 3]` *)
  val vector : 'a slice -> 'a Vector.vector

  (* ---- Copying ---- *)

  (* `copy {src, dst, di}` copies the elements of the slice `src` into the array `dst`, starting at position `di`.

     The slice may be a stretch of `dst` itself and the two may overlap:
     every element arrives as it was before the copy began.

     Raises: `Subscript` if `di < 0` or `di + length src > Array.length dst`,
     and then nothing has been copied.

     Example: `let val a = Array.fromList [1, 2, 3, 4] in copy {src = slice (a,
     0, SOME 3), dst = a, di = 1}; Array.vector a end = Vector.fromList [1, 1,
     2, 3]` *)
  val copy : {src : 'a slice, dst : 'a Array.array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the elements of the vector slice `src` into `dst`, starting at position `di`.

     Raises: `Subscript` if `di < 0` or `di + VectorSlice.length src >
     Array.length dst`, and then nothing has been copied.

     Example: `let val a = Array.array (3, 0) in copyVec {src = VectorSlice.slice
     (Vector.fromList [7, 8, 9], 1, NONE), dst = a, di = 0}; Array.vector a end
     = Vector.fromList [8, 9, 0]` *)
  val copyVec : {src : 'a VectorSlice.slice, dst : 'a Array.array, di : int} -> unit

  (* `isEmpty sl` is `true` when `sl` has no elements.

     Law: `isEmpty sl = (length sl = 0)`

     Example: `isEmpty (slice (Array.fromList [1], 1, NONE)) = true` *)
  val isEmpty : 'a slice -> bool

  (* `getItem sl` is `NONE` for an empty slice and `SOME (x, rest)` for the first element and what follows it.

     `rest` is a slice of the same array, so it is had for nothing.

     Example: `(case getItem (full (Array.fromList [1, 2])) of SOME (x, rest)
     => (x, length rest) | NONE => (0, 0)) = (1, 1)` *)
  val getItem : 'a slice -> ('a * 'a slice) option

  (* ---- Traversing ---- *)

  (* `appi f sl` applies `f` to the index and the element of each position, from 0 up, for its effect.

     The index is that of the element in the slice, counted from 0.

     Example: `let val r = ref [] in appi (fn (i, x) => r := (i, x) :: !r)
     (slice (Array.fromList ["a", "b", "c"], 1, NONE)); !r end = [(1, "c"),
     (0, "b")]` *)
  val appi : (int * 'a -> unit) -> 'a slice -> unit

  (* `app f sl` applies `f` to every element, from 0 up, for its effect.

     Law: `app f sl = appi (f o #2) sl`

     Example: `let val s = ref 0 in app (fn x => s := !s + x) (slice (Array.fromList [1, 2, 3], 1, NONE)); !s end = 5` *)
  val app : ('a -> unit) -> 'a slice -> unit

  (* `modifyi f sl` replaces the element at each position by `f` of the index and that element, in place.

     The index is that of the element in the slice, and the elements are
     replaced from 0 up.

     Example: `let val a = Array.fromList [10, 20, 30] in modifyi (fn (i, x) =>
     x + i) (slice (a, 1, NONE)); Array.vector a end = Vector.fromList [10, 20,
     31]` *)
  val modifyi : (int * 'a -> 'a) -> 'a slice -> unit

  (* `modify f sl` replaces every element by `f` of it, in place, from 0 up.

     Law: `modify f sl = modifyi (fn (_, x) => f x) sl`

     Example: `let val a = Array.fromList [1, 2, 3, 4] in modify (fn _ => 0)
     (slice (a, 1, SOME 2)); Array.vector a end = Vector.fromList [1, 0, 0, 4]` *)
  val modify : ('a -> 'a) -> 'a slice -> unit

  (* `foldli f init sl` combines the elements from the left, giving `f` the index as well.

     The index is that of the element in the slice, counted from 0.

     Example: `foldli (fn (i, x, acc) => (i, x) :: acc) [] (slice
     (Array.fromList ["a", "b", "c"], 1, NONE)) = [(1, "c"), (0, "b")]` *)
  val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* `foldri f init sl` combines the elements from the right, giving `f` the index as well.

     The index is that of the element in the slice, counted from 0.

     Example: `foldri (fn (i, x, acc) => (i, x) :: acc) [] (slice
     (Array.fromList ["a", "b", "c"], 1, NONE)) = [(0, "b"), (1, "c")]` *)
  val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* `foldl f init sl` combines the elements from the left, as `List.foldl` does.

     Law: `foldl f init sl = foldli (fn (_, a, x) => f (a, x)) init sl`

     Example: `foldl (op ::) [] (full (Array.fromList [1, 2, 3])) = [3, 2, 1]` *)
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* `foldr f init sl` combines the elements from the right, as `List.foldr` does.

     Law: `foldr f init sl = foldri (fn (_, a, x) => f (a, x)) init sl`

     Example: `foldr (op ::) [] (full (Array.fromList [1, 2, 3])) = [1, 2, 3]` *)
  val foldr : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* ---- Searching ---- *)

  (* `findi p sl` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`.

     The index is that of the element in the slice; `p` is applied from 0 up,
     and not after the first position that satisfies it.

     Example: `findi (fn (_, x) => x = 3) (slice (Array.fromList [3, 1, 3], 1,
     NONE)) = SOME (1, 3)` *)
  val findi : (int * 'a -> bool) -> 'a slice -> (int * 'a) option

  (* `find p sl` is `SOME x` for the first element that satisfies `p`, or `NONE`.

     Law: `find p sl = Option.map #2 (findi (fn (_, x) => p x) sl)`

     Example: `find (fn x => x > 1) (full (Array.fromList [1, 2, 3])) = SOME 2` *)
  val find : ('a -> bool) -> 'a slice -> 'a option

  (* `exists p sl` is `true` when some element satisfies `p`; it stops at the first that does.

     Only the elements of the slice are looked at, not the rest of its array.

     Law: `exists p sl = isSome (find p sl)`

     Example: `exists (fn x => x = 1) (slice (Array.fromList [1, 2, 3], 1,
     NONE)) = false` *)
  val exists : ('a -> bool) -> 'a slice -> bool

  (* `all p sl` is `true` when every element satisfies `p`; it stops at the first that does not.

     Law: `all p sl = not (exists (not o p) sl)`

     Example: `all (fn x => x > 1) (slice (Array.fromList [1, 2, 3], 1, NONE))
     = true` *)
  val all : ('a -> bool) -> 'a slice -> bool

  (* `collate cmp (sl, tl)` compares the elements of two slices lexicographically with `cmp`.

     Law: `collate cmp (sl, sl') = List.collate cmp (foldr (op ::) [] sl, foldr
     (op ::) [] sl')`

     Example: `collate Int.compare (slice (Array.fromList [1, 2, 3], 1, NONE),
     full (Array.fromList [2])) = GREATER` *)
  val collate : ('a * 'a -> order) -> 'a slice * 'a slice -> order
end
