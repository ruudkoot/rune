(* A stretch of a vector, without a copy of it: a base vector and a start and
   a length inside it.

   A slice is what a function takes when it is to work on part of a sequence:
   passing `slice (v, i, SOME n)` costs nothing, where passing
   `VectorSlice.vector` of it would copy. The three numbers are what `base`
   gives back. Positions inside a slice are counted from its own start, so
   `sub (sl, 0)` is its first element whatever `sl` begins at in its base.

   Area: Sequences

   See also: `VECTOR`, `ARRAY_SLICE`, `MONO_VECTOR_SLICE`, `SUBSTRING` *)
signature VECTOR_SLICE =
sig
  (* The type of slices of a vector. *)
  type 'a slice

  (* ---- Elements ---- *)

  (* `length sl` is the number of elements of `sl`. *)
  val length : 'a slice -> int

  (* `sub (sl, i)` is the element of `sl` at position `i`, counting from the start of the slice.

     Raises: `Subscript` if `i < 0` or `i >= length sl`. *)
  val sub : 'a slice * int -> 'a

  (* ---- Making a slice ---- *)

  (* `full v` is the whole of `v` as a slice. *)
  val full : 'a Vector.vector -> 'a slice

  (* `slice (v, i, NONE)` is the stretch of `v` from position `i` to its end, and `slice (v, i, SOME n)` the `n` elements from `i`.

     Raises: `Subscript` if `i < 0`, if `i > Vector.length v`, or if `n` is
     given and `i + n > Vector.length v`. *)
  val slice : 'a Vector.vector * int * int option -> 'a slice

  (* `subslice (sl, i, NONE)` is the stretch of `sl` from position `i` on, and `subslice (sl, i, SOME n)` the `n` elements from `i`.

     Raises: `Subscript` if the positions are outside `sl`.

     Reading: `VectorSlice.subslice/NONE-Subscript-beyond`. The bounds are
     those of `sl`, not of the vector it is a slice of: a subslice cannot
     reach back into the rest of the base vector. *)
  val subslice : 'a slice * int * int option -> 'a slice

  (* `base sl` is the triple of the vector that `sl` is a stretch of, where it starts in that vector, and how long it is. *)
  val base : 'a slice -> 'a Vector.vector * int * int

  (* `vector sl` is a vector of the elements of `sl`, which is where the copy happens. *)
  val vector : 'a slice -> 'a Vector.vector

  (* `concat l` is the vector of the elements of the slices of `l`, one after another.

     Raises: `Size` if the result would be longer than `Vector.maxLen`. *)
  val concat : 'a slice list -> 'a Vector.vector

  (* `isEmpty sl` is `true` when `sl` has no elements. *)
  val isEmpty : 'a slice -> bool

  (* `getItem sl` is `NONE` for an empty slice and `SOME (x, rest)` for the first element and what follows it.

     It has the shape of a `StringCvt.reader`, so a slice is a stream that a
     `scan` function can read from. *)
  val getItem : 'a slice -> ('a * 'a slice) option

  (* ---- Traversing ---- *)

  (* `appi f sl` applies `f` to the index and the element of each position, from 0 up, for its effect.

     Reading: `VectorSlice.appi/index-in-the-slice`. The index is "that of
     the corresponding element in the slice": it starts at 0 whatever the
     slice begins at in its base vector. The same holds for `mapi`,
     `foldli`, `foldri` and `findi`. *)
  val appi : (int * 'a -> unit) -> 'a slice -> unit

  (* `app f sl` applies `f` to every element, from 0 up, for its effect. *)
  val app : ('a -> unit) -> 'a slice -> unit

  (* `mapi f sl` is the vector of the results of `f` on the index and the element of each position. *)
  val mapi : (int * 'a -> 'b) -> 'a slice -> 'b Vector.vector

  (* `map f sl` is the vector of the results of `f` on each element, in order. *)
  val map : ('a -> 'b) -> 'a slice -> 'b Vector.vector

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
