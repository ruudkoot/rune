(* The sequences of one element type: vectors, arrays and their slices, as
   `VECTOR`, `ARRAY`, `VECTOR_SLICE` and `ARRAY_SLICE` describe them for any
   element type.

   Fixing the element type lets an implementation pack the elements, so
   `Word8Vector` need not hold one machine word per byte, and it gives the
   byte- and character-oriented parts of the library (`BYTE`, `TEXT`,
   `BIN_IO`) a sequence type to name. The members are those of the
   polymorphic signatures, with `elem` for the element type; what they mean
   is the same, and the pages of `VECTOR` and `ARRAY` describe it at more
   length.

   Area: Sequences

   See also: `VECTOR`, `ARRAY`, `VECTOR_SLICE`, `ARRAY_SLICE`, `MONO_ARRAY2`,
   `TEXT`, `BYTE` *)
signature MONO_VECTOR =
sig
  (* The type of these vectors.

     Deviation: `MONO_VECTOR.vector/not-abstract`. Except for the vectors of
     characters and of bytes, which are strings, a monomorphic vector is the
     polymorphic vector of its elements, and the types are not made abstract: an
     `IntVector.vector` is an `int vector`, and a program that relies on it is
     not portable. The arrays are the same (`IntArray.array` is `int array`),
     and so are those of `MONO_ARRAY2`. *)
  type vector

  (* The type of the elements: `Word8.word` for `Word8Vector`, `char` for `CharVector`. *)
  type elem

  (* The greatest length such a vector may have.

     Implementation: `MONO_VECTOR.maxLen/value`. The same bound as
     `Vector.maxLen` for the families built on the polymorphic vectors, and
     `String.maxSize` for those whose vector is a string. *)
  val maxLen : int

  (* `fromList l` is the sequence of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`. *)
  val fromList : elem list -> vector

  (* `tabulate (n, f)` is the sequence of `f 0`, ..., `f (n - 1)`, applied in order.

     Raises: `Size` if `n < 0` or `n > maxLen`, before `f` is applied. *)
  val tabulate : int * (int -> elem) -> vector

  (* `length x` is the number of elements. *)
  val length : vector -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i` is outside. *)
  val sub : vector * int -> elem

  (* `update (v, i, x)` is a new vector like `v` but with `x` at position `i`.

     Raises: `Subscript` if `i` is outside `v`. *)
  val update : vector * int * elem -> vector

  (* `concat l` is the vectors of `l` one after another.

     Raises: `Size` if the result would be longer than `maxLen`. *)
  val concat : vector list -> vector

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect. *)
  val appi : (int * elem -> unit) -> vector -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect. *)
  val app : (elem -> unit) -> vector -> unit

  (* `mapi f v` is the vector of the results of `f` on the index and the element of each position. *)
  val mapi : (int * elem -> elem) -> vector -> vector

  (* `map f v` is the vector of the results of `f` on each element, in order. *)
  val map : (elem -> elem) -> vector -> vector

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does. *)
  val foldl : (elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does. *)
  val foldr : (elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`. *)
  val findi : (int * elem -> bool) -> vector -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`. *)
  val find : (elem -> bool) -> vector -> elem option

  (* `exists p x` is `true` when some element satisfies `p`. *)
  val exists : (elem -> bool) -> vector -> bool

  (* `all p x` is `true` when every element satisfies `p`. *)
  val all : (elem -> bool) -> vector -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`. *)
  val collate : (elem * elem -> order) -> vector * vector -> order
end

(* Mutable sequences of one element type.

   Area: Sequences

   See also: `ARRAY`, `MONO_VECTOR`, `MONO_ARRAY_SLICE`, `MONO_ARRAY2`

   Implementation: `Word8Array.array/one-value-per-byte`. A `Word8Array.array`
   is an ordinary array with one value of the machine per byte. *)
signature MONO_ARRAY =
sig
  (* The type of these arrays.

     Two are equal when they are the same array, whatever they hold. *)
  eqtype array

  (* The type of the elements: `Word8.word` for `Word8Vector`, `char` for `CharVector`. *)
  type elem

  (* The type of these vectors. *)
  type vector

  (* The greatest length such an array may have.

     Implementation: `MONO_ARRAY.maxLen/value`. `Array.maxLen`, 100,000,000,
     for every instance, those of characters and of bytes too.

     Pinned by: `*Array.maxLen/covers-created-arrays` *)
  val maxLen : int

  (* `array (n, x)` is a new array of `n` elements, each of them `x`.

     Raises: `Size` if `n < 0` or `n > maxLen`. *)
  val array : int * elem -> array

  (* `fromList l` is the sequence of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`. *)
  val fromList : elem list -> array

  (* `tabulate (n, f)` is the sequence of `f 0`, ..., `f (n - 1)`, applied in order.

     Raises: `Size` if `n < 0` or `n > maxLen`, before `f` is applied. *)
  val tabulate : int * (int -> elem) -> array

  (* `length x` is the number of elements. *)
  val length : array -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i` is outside. *)
  val sub : array * int -> elem

  (* `update (arr, i, x)` puts `x` at position `i` of `arr`.

     Raises: `Subscript` if `i` is outside `arr`. *)
  val update : array * int * elem -> unit

  (* `vector arr` is an immutable vector of the elements of `arr`, which is a copy. *)
  val vector : array -> vector

  (* `copy {src, dst, di}` copies `src` into `dst` from position `di` on.

     The two may be one array and may overlap: every element arrives as it
     was before the copy began.

     Raises: `Subscript` if it does not fit, and then nothing has been
     copied. *)
  val copy : {src : array, dst : array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the vector `src` into `dst` from position `di` on.

     Raises: `Subscript` if it does not fit, and then nothing has been
     copied. *)
  val copyVec : {src : vector, dst : array, di : int} -> unit

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect. *)
  val appi : (int * elem -> unit) -> array -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect. *)
  val app : (elem -> unit) -> array -> unit

  (* `modifyi f x` replaces the element at each position by `f` of the index and that element, in place. *)
  val modifyi : (int * elem -> elem) -> array -> unit

  (* `modify f x` replaces every element by `f` of it, in place, from 0 up. *)
  val modify : (elem -> elem) -> array -> unit

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does. *)
  val foldl : (elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does. *)
  val foldr : (elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`. *)
  val findi : (int * elem -> bool) -> array -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`. *)
  val find : (elem -> bool) -> array -> elem option

  (* `exists p x` is `true` when some element satisfies `p`. *)
  val exists : (elem -> bool) -> array -> bool

  (* `all p x` is `true` when every element satisfies `p`. *)
  val all : (elem -> bool) -> array -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`. *)
  val collate : (elem * elem -> order) -> array * array -> order
end


(* The same as `MONO_VECTOR`, with a vector type that admits equality.

   Area: Sequences

   Status: extension

   Deviation: `MONO_VECTOR_EQ/not-in-the-specification`. This signature is
   not in the specification. `MONO_VECTOR` writes `type vector`, not
   `eqtype`, so that a family whose elements do not admit equality (the reals)
   can have one; a family whose vector is a type of its own and does admit it
   is sealed with this instead. `WideCharVector` needs that, because
   `WideString.string` must be a type name of its own for wide string
   constants to be overloaded at it. *)
signature MONO_VECTOR_EQ =
sig
  (* The type of these vectors, which admits equality. *)
  eqtype vector

  (* The type of the elements: `WideChar.char` for `WideCharVector`. *)
  type elem

  (* The greatest length such a vector may have.

     Implementation: `MONO_VECTOR_EQ.maxLen/value`. `String.maxSize`, the
     bound of the families of `MONO_VECTOR` whose vector is a string. *)
  val maxLen : int

  (* `fromList l` is the sequence of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`. *)
  val fromList : elem list -> vector

  (* `tabulate (n, f)` is the sequence of `f 0`, ..., `f (n - 1)`, applied in order.

     Raises: `Size` if `n < 0` or `n > maxLen`, before `f` is applied. *)
  val tabulate : int * (int -> elem) -> vector

  (* `length x` is the number of elements. *)
  val length : vector -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i` is outside. *)
  val sub : vector * int -> elem

  (* `update (v, i, x)` is a new vector like `v` but with `x` at position `i`.

     Raises: `Subscript` if `i` is outside `v`. *)
  val update : vector * int * elem -> vector

  (* `concat l` is the vectors of `l` one after another.

     Raises: `Size` if the result would be longer than `maxLen`. *)
  val concat : vector list -> vector

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect. *)
  val appi : (int * elem -> unit) -> vector -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect. *)
  val app : (elem -> unit) -> vector -> unit

  (* `mapi f v` is the vector of the results of `f` on the index and the element of each position. *)
  val mapi : (int * elem -> elem) -> vector -> vector

  (* `map f v` is the vector of the results of `f` on each element, in order. *)
  val map : (elem -> elem) -> vector -> vector

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * elem * 'b -> 'b) -> 'b -> vector -> 'b

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does. *)
  val foldl : (elem * 'b -> 'b) -> 'b -> vector -> 'b

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does. *)
  val foldr : (elem * 'b -> 'b) -> 'b -> vector -> 'b

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`. *)
  val findi : (int * elem -> bool) -> vector -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`. *)
  val find : (elem -> bool) -> vector -> elem option

  (* `exists p x` is `true` when some element satisfies `p`. *)
  val exists : (elem -> bool) -> vector -> bool

  (* `all p x` is `true` when every element satisfies `p`. *)
  val all : (elem -> bool) -> vector -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`. *)
  val collate : (elem * elem -> order) -> vector * vector -> order
end

(* A stretch of a vector of one element type, without a copy of it.

   Area: Sequences

   See also: `VECTOR_SLICE`, `MONO_VECTOR`, `SUBSTRING`

   Implementation: `CharVectorSlice.slice/substring`. The slice of a vector
   of characters is `Substring.substring`, and the slice of one of bytes is a
   substring too. *)
signature MONO_VECTOR_SLICE =
sig
  (* The type of the elements: `Word8.word` for `Word8Vector`, `char` for `CharVector`. *)
  type elem

  (* The type of these vectors. *)
  type vector

  (* The type of slices of one of these. *)
  type slice

  (* `length x` is the number of elements. *)
  val length : slice -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i` is outside. *)
  val sub : slice * int -> elem

  (* `full v` is the whole of `v` as a slice. *)
  val full : vector -> slice

  (* `slice (v, i, sz)` is the stretch of `v` from `i`, of `sz` elements or to the end.

     Raises: `Subscript` if the positions are outside `v`. *)
  val slice : vector * int * int option -> slice

  (* `subslice (sl, i, sz)` is the stretch of `sl` from `i`, of `sz` elements or to its end.

     The bounds are those of `sl`, not of what it is a slice of.

     Raises: `Subscript` if the positions are outside `sl`. *)
  val subslice : slice * int * int option -> slice

  (* `base sl` is the vector `sl` is a stretch of, where it starts and how long it is. *)
  val base : slice -> vector * int * int

  (* `vector sl` is a vector of the elements of `sl`, which is where the copy happens. *)
  val vector : slice -> vector

  (* `concat l` is the vector of the elements of the slices of `l`, one after another.

     Raises: `Size` if the result would be longer than `maxLen`. *)
  val concat : slice list -> vector

  (* `isEmpty sl` is `true` when `sl` has no elements. *)
  val isEmpty : slice -> bool

  (* `getItem sl` is `NONE` when `sl` is empty, and `SOME (x, rest)` otherwise.

     It has the shape of a `StringCvt.reader`. *)
  val getItem : slice -> (elem * slice) option

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect. *)
  val appi : (int * elem -> unit) -> slice -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect. *)
  val app : (elem -> unit) -> slice -> unit

  (* `mapi f sl` is the vector of the results of `f` on the index and the element of each position. *)
  val mapi : (int * elem -> elem) -> slice -> vector

  (* `map f sl` is the vector of the results of `f` on each element, in order. *)
  val map : (elem -> elem) -> slice -> vector

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does. *)
  val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does. *)
  val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`. *)
  val findi : (int * elem -> bool) -> slice -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`. *)
  val find : (elem -> bool) -> slice -> elem option

  (* `exists p x` is `true` when some element satisfies `p`. *)
  val exists : (elem -> bool) -> slice -> bool

  (* `all p x` is `true` when every element satisfies `p`. *)
  val all : (elem -> bool) -> slice -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`. *)
  val collate : (elem * elem -> order) -> slice * slice -> order
end

(* A stretch of an array of one element type, without a copy of it.

   Area: Sequences

   See also: `ARRAY_SLICE`, `MONO_ARRAY`, `MONO_VECTOR_SLICE` *)
signature MONO_ARRAY_SLICE =
sig
  (* The type of the elements: `Word8.word` for `Word8Vector`, `char` for `CharVector`. *)
  type elem

  (* The type of these arrays. *)
  type array

  (* The type of slices of one of these. *)
  type slice

  (* The type of these vectors. *)
  type vector

  (* The type of slices of the corresponding vector. *)
  type vector_slice

  (* `length x` is the number of elements. *)
  val length : slice -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i` is outside. *)
  val sub : slice * int -> elem

  (* `update (sl, i, x)` puts `x` at position `i` of `sl`, and so of its array.

     Raises: `Subscript` if `i` is outside `sl`. *)
  val update : slice * int * elem -> unit

  (* `full arr` is the whole of `arr` as a slice. *)
  val full : array -> slice

  (* `slice (arr, i, sz)` is the stretch of `arr` from `i`, of `sz` elements or to the end.

     Raises: `Subscript` if the positions are outside `arr`. *)
  val slice : array * int * int option -> slice

  (* `subslice (sl, i, sz)` is the stretch of `sl` from `i`, of `sz` elements or to its end.

     The bounds are those of `sl`, not of what it is a slice of.

     Raises: `Subscript` if the positions are outside `sl`. *)
  val subslice : slice * int * int option -> slice

  (* `base sl` is the array `sl` is a stretch of, where it starts and how long it is. *)
  val base : slice -> array * int * int

  (* `vector sl` is a vector of the elements of `sl`, which is where the copy happens. *)
  val vector : slice -> vector

  (* `copy {src, dst, di}` copies the slice `src` into `dst` from position `di` on.

     They may overlap: every element arrives as it was before the copy
     began.

     Raises: `Subscript` if it does not fit, and then nothing has been
     copied. *)
  val copy : {src : slice, dst : array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the vector slice `src` into `dst` from position `di` on.

     Raises: `Subscript` if it does not fit, and then nothing has been
     copied. *)
  val copyVec : {src : vector_slice, dst : array, di : int} -> unit

  (* `isEmpty sl` is `true` when `sl` has no elements. *)
  val isEmpty : slice -> bool

  (* `getItem sl` is `NONE` when `sl` is empty, and `SOME (x, rest)` otherwise.

     It has the shape of a `StringCvt.reader`. *)
  val getItem : slice -> (elem * slice) option

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect. *)
  val appi : (int * elem -> unit) -> slice -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect. *)
  val app : (elem -> unit) -> slice -> unit

  (* `modifyi f x` replaces the element at each position by `f` of the index and that element, in place. *)
  val modifyi : (int * elem -> elem) -> slice -> unit

  (* `modify f x` replaces every element by `f` of it, in place, from 0 up. *)
  val modify : (elem -> elem) -> slice -> unit

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does. *)
  val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does. *)
  val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`. *)
  val findi : (int * elem -> bool) -> slice -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`. *)
  val find : (elem -> bool) -> slice -> elem option

  (* `exists p x` is `true` when some element satisfies `p`. *)
  val exists : (elem -> bool) -> slice -> bool

  (* `all p x` is `true` when every element satisfies `p`. *)
  val all : (elem -> bool) -> slice -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`. *)
  val collate : (elem * elem -> order) -> slice * slice -> order
end

(* `Word8Vector`, as the library sees it: the members of the specification and
   the two conversions that say a vector of bytes is a string underneath. A
   program sees `MONO_VECTOR`, which the seal file gives it. The slice's own
   signature is in word8vector.sml, where `Substring` is in scope. *)
signature MONO_VECTOR_BYTES =
sig
  include MONO_VECTOR_EQ
  val toString : vector -> string
  val fromString : string -> vector
end
