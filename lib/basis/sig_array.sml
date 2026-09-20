(* Arrays: mutable sequences of a fixed length, of any element type.

   An array is indexed from 0; `update` changes an element in place, and two
   arrays are equal only when they are the same array, whatever they hold. An
   array of length 0 is still an array of its own, so `array (0, x) = array
   (0, x)` is `false`.

   `VECTOR` is the immutable counterpart, and `vector` and `copyVec` convert
   between the two. `ARRAY_SLICE` describes a stretch of an array without
   copying it, and `ARRAY2` is the two-dimensional version.

   Area: Sequences

   See also: `VECTOR`, `ARRAY_SLICE`, `ARRAY2`, `MONO_ARRAY`, `LIST`

   Erratum: `ARRAY/array-spec`. The specification writes `eqtype 'a array =
   'a array`, which the Definition does not allow as a specification; it is
   written here as an abbreviation of the top-level `array`, which admits
   equality whatever its element type is. *)
signature ARRAY =
sig
  (* The type of arrays, the one of the top-level environment.

     Two arrays are equal when they are the same array: equality is identity,
     not a comparison of the elements. *)
  type 'a array = 'a array

  (* The type of the vectors that `vector` and `copyVec` work with. *)
  type 'a vector = 'a Vector.vector

  (* The greatest length an array may have.

     Implementation: `Array.maxLen/value`. 100000000, the same as
     `Vector.maxLen`. *)
  val maxLen : int

  (* ---- Making an array ---- *)

  (* `array (n, x)` is a new array of `n` elements, each of them `x`.

     Raises: `Size` if `n < 0` or `n > maxLen`. *)
  val array : int * 'a -> 'a array

  (* `fromList l` is a new array of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`. *)
  val fromList : 'a list -> 'a array

  (* `tabulate (n, f)` is a new array of `f 0`, `f 1`, ..., `f (n - 1)`.

     `f` is applied in order of increasing index.

     Raises: `Size` if `n < 0` or `n > maxLen`, before `f` is applied at all. *)
  val tabulate : int * (int -> 'a) -> 'a array

  (* ---- Elements ---- *)

  (* `length arr` is the number of elements of `arr`. *)
  val length : 'a array -> int

  (* `sub (arr, i)` is the element of `arr` at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length arr`. *)
  val sub : 'a array * int -> 'a

  (* `update (arr, i, x)` puts `x` at position `i` of `arr`.

     Raises: `Subscript` if `i < 0` or `i >= length arr`. *)
  val update : 'a array * int * 'a -> unit

  (* `vector arr` is an immutable vector of the elements of `arr`.

     It is a copy: a later `update` of `arr` does not touch it. *)
  val vector : 'a array -> 'a vector

  (* ---- Copying ---- *)

  (* `copy {src, dst, di}` copies the elements of `src` into `dst`, starting at position `di`.

     `src` and `dst` may be the same array and the stretches may overlap:
     every element arrives as it was before the copy began.

     Raises: `Subscript` if `di < 0` or `di + length src > length dst`, and
     then nothing has been copied. *)
  val copy : {src : 'a array, dst : 'a array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the elements of the vector `src` into `dst`, starting at position `di`.

     Raises: `Subscript` if `di < 0` or `di + Vector.length src > length dst`,
     and then nothing has been copied. *)
  val copyVec : {src : 'a vector, dst : 'a array, di : int} -> unit

  (* ---- Traversing ---- *)

  (* `appi f arr` applies `f` to the index and the element of each position, from 0 up, for its effect. *)
  val appi : (int * 'a -> unit) -> 'a array -> unit

  (* `app f arr` applies `f` to every element, from 0 up, for its effect. *)
  val app : ('a -> unit) -> 'a array -> unit

  (* `modifyi f arr` replaces the element at each position by `f` of the index and that element.

     The array is changed in place, from 0 up. *)
  val modifyi : (int * 'a -> 'a) -> 'a array -> unit

  (* `modify f arr` replaces every element by `f` of it, in place, from 0 up. *)
  val modify : ('a -> 'a) -> 'a array -> unit

  (* `foldli f init arr` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* `foldri f init arr` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* `foldl f init arr` combines the elements from the left, as `List.foldl` does. *)
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* `foldr f init arr` combines the elements from the right, as `List.foldr` does. *)
  val foldr : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* ---- Searching ---- *)

  (* `findi p arr` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`. *)
  val findi : (int * 'a -> bool) -> 'a array -> (int * 'a) option

  (* `find p arr` is `SOME x` for the first element that satisfies `p`, or `NONE`. *)
  val find : ('a -> bool) -> 'a array -> 'a option

  (* `exists p arr` is `true` when some element satisfies `p`; it stops at the first that does. *)
  val exists : ('a -> bool) -> 'a array -> bool

  (* `all p arr` is `true` when every element satisfies `p`; it stops at the first that does not. *)
  val all : ('a -> bool) -> 'a array -> bool

  (* `collate cmp (a, b)` compares the elements of two arrays lexicographically with `cmp`.

     This compares what the arrays hold, where `=` compares which array it
     is. *)
  val collate : ('a * 'a -> order) -> 'a array * 'a array -> order
end
