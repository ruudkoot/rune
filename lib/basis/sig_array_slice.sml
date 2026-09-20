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

  (* `length sl` is the number of elements of `sl`. *)
  val length : 'a slice -> int

  (* `sub (sl, i)` is the element of `sl` at position `i`, counting from the start of the slice.

     Raises: `Subscript` if `i < 0` or `i >= length sl`. *)
  val sub : 'a slice * int -> 'a

  (* `update (sl, i, x)` puts `x` at position `i` of `sl`, and so of the array it is a slice of.

     Raises: `Subscript` if `i < 0` or `i >= length sl`. *)
  val update : 'a slice * int * 'a -> unit

  (* ---- Making a slice ---- *)

  (* `full arr` is the whole of `arr` as a slice. *)
  val full : 'a Array.array -> 'a slice

  (* `slice (arr, i, NONE)` is the stretch of `arr` from position `i` to its end, and `slice (arr, i, SOME n)` the `n` elements from `i`.

     Raises: `Subscript` if the positions are outside `arr`. *)
  val slice : 'a Array.array * int * int option -> 'a slice

  (* `subslice (sl, i, NONE)` is the stretch of `sl` from position `i` on, and `subslice (sl, i, SOME n)` the `n` elements from `i`.

     The bounds are those of `sl`, not of the array it is a slice of.

     Raises: `Subscript` if the positions are outside `sl`. *)
  val subslice : 'a slice * int * int option -> 'a slice

  (* `base sl` is the triple of the array that `sl` is a stretch of, where it starts in that array, and how long it is. *)
  val base : 'a slice -> 'a Array.array * int * int

  (* `vector sl` is an immutable vector of the elements of `sl`, which is a copy. *)
  val vector : 'a slice -> 'a Vector.vector

  (* ---- Copying ---- *)

  (* `copy {src, dst, di}` copies the elements of the slice `src` into the array `dst`, starting at position `di`.

     The slice may be a stretch of `dst` itself and the two may overlap:
     every element arrives as it was before the copy began.

     Raises: `Subscript` if `di < 0` or `di + length src > Array.length dst`,
     and then nothing has been copied. *)
  val copy : {src : 'a slice, dst : 'a Array.array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the elements of the vector slice `src` into `dst`, starting at position `di`.

     Raises: `Subscript` if they do not fit, and then nothing has been
     copied. *)
  val copyVec : {src : 'a VectorSlice.slice, dst : 'a Array.array, di : int} -> unit

  (* `isEmpty sl` is `true` when `sl` has no elements. *)
  val isEmpty : 'a slice -> bool

  (* `getItem sl` is `NONE` for an empty slice and `SOME (x, rest)` for the first element and what follows it. *)
  val getItem : 'a slice -> ('a * 'a slice) option

  (* ---- Traversing ---- *)

  (* `appi f sl` applies `f` to the index and the element of each position, from 0 up, for its effect.

     The index is that of the element in the slice, counted from 0. *)
  val appi : (int * 'a -> unit) -> 'a slice -> unit

  (* `app f sl` applies `f` to every element, from 0 up, for its effect. *)
  val app : ('a -> unit) -> 'a slice -> unit

  (* `modifyi f sl` replaces the element at each position by `f` of the index and that element, in place. *)
  val modifyi : (int * 'a -> 'a) -> 'a slice -> unit

  (* `modify f sl` replaces every element by `f` of it, in place, from 0 up. *)
  val modify : ('a -> 'a) -> 'a slice -> unit

  (* `foldli f init sl` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* `foldri f init sl` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* `foldl f init sl` combines the elements from the left, as `List.foldl` does. *)
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* `foldr f init sl` combines the elements from the right, as `List.foldr` does. *)
  val foldr : ('a * 'b -> 'b) -> 'b -> 'a slice -> 'b

  (* ---- Searching ---- *)

  (* `findi p sl` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`. *)
  val findi : (int * 'a -> bool) -> 'a slice -> (int * 'a) option

  (* `find p sl` is `SOME x` for the first element that satisfies `p`, or `NONE`. *)
  val find : ('a -> bool) -> 'a slice -> 'a option

  (* `exists p sl` is `true` when some element satisfies `p`. *)
  val exists : ('a -> bool) -> 'a slice -> bool

  (* `all p sl` is `true` when every element satisfies `p`. *)
  val all : ('a -> bool) -> 'a slice -> bool

  (* `collate cmp (sl, tl)` compares the elements of two slices lexicographically with `cmp`. *)
  val collate : ('a * 'a -> order) -> 'a slice * 'a slice -> order
end
