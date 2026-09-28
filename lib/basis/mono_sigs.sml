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

   Erratum: `MONO_VECTOR/WideCharVector-must-admit-equality`. The page writes
   `type vector`, not `eqtype`, so that a family whose elements do not admit
   equality can have a vector -- `RealVector` needs that. Where a vector has
   to admit equality the page says so on the instance instead: `CharVector`
   is declared `where type vector = String.string`, and `STRING` writes
   `eqtype string`. **`WideCharVector` is declared `where type elem =
   WideChar.char` and nothing more, and that is not enough.** `TEXT` shares
   `String.string` with `CharVector.vector`, and `WideText` is declared
   `where type String.string = WideString.string`, so
   `WideText.CharVector.vector` is `WideString.string`, which `STRING` makes
   an equality type. Any implementation whose `WideText.CharVector` is the
   top-level `WideCharVector` -- every one that has both -- must therefore
   give `WideCharVector.vector` equality, and the declaration the page gives
   it cannot. **The whole of the defect is one missing constraint**:
   `where type vector = WideString.string`, which `CharVector` has and
   `WideCharVector` does not. That makes this a milder fault than the one on
   the page of `ARRAY2`, where no constraint can help because there is no
   type to pin to; here `WideString.string` is already there and `STRING`
   already makes it an equality type.

   Rune gives the equality the other way, by sealing with `MONO_VECTOR_EQ`.
   That is a consequence of *this* library's order and not of the fault:
   `WideString` is built on `WideCharVector` (`type string = V.vector`, and
   every operation delegates), so `WideCharVector` is where the type name is
   born and there is nothing yet to pin it to. Following the page as it
   should have been written would mean giving `WideString` a representation
   of its own and pinning `WideCharVector` to it -- a change to two files,
   not a rename -- and `MONO_VECTOR_EQ` would then be unnecessary.

   See also: `VECTOR`, `ARRAY`, `VECTOR_SLICE`, `ARRAY_SLICE`, `MONO_ARRAY2`,
   `MONO_VECTOR_EQ`, `TEXT`, `BYTE` *)
signature MONO_VECTOR =
sig
  (* The type of these vectors.

     Implementation: `MONO_VECTOR.vector/abstract-over-the-polymorphic-one`.
     A monomorphic vector is the polymorphic vector of its elements
     underneath -- the vectors of characters are strings, which the
     specification requires -- but the type is abstract: an `IntVector.vector`
     is no `int vector` for a program, as it is none in MLton or SML/NJ. The
     arrays and the two-dimensional arrays are the same. Sealing them costs
     nothing: the instruction counts of `runevm --count` do not change at
     all, because no file of the library goes between the two. No check of
     the suite can pin this -- that a type is abstract is not something a
     program can observe at run time -- and what holds it is the page of the
     types that are one type, which `make check` compares with the library as
     it stands. *)
  type vector

  (* The type of the elements: `Word8.word` for `Word8Vector`, `char` for `CharVector`. *)
  type elem

  (* The greatest length such a vector may have.

     Implementation: `MONO_VECTOR.maxLen/value`. The same bound as
     `Vector.maxLen` for the families built on the polymorphic vectors, and
     `String.maxSize` for those whose vector is a string.

     Example: `maxLen = String.maxSize` *)
  val maxLen : int

  (* `fromList l` is a vector of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`.

     Law: `sub (fromList l, i) = List.nth (l, i)` for `0 <= i andalso i <
     List.length l`

     Example: `fromList [#"a", #"b"] = "ab"` *)
  val fromList : elem list -> vector

  (* `tabulate (n, f)` is a vector of `f 0`, ..., `f (n - 1)`, applied in order.

     Raises: `Size` if `n < 0` or `n > maxLen`.

     Reading: `MONO_VECTOR.tabulate/Size-before-f`. The specification does not
     say whether the length is checked before `f` is applied. It is: a length
     out of range raises `Size` without applying `f` at all.

     Pinned by: `*Vector.tabulate/Size-before-f`

     Law: `sub (tabulate (n, f), i) = f i` for `0 <= i andalso i < n`, when `f`
     has no effects

     Example: `tabulate (3, fn i => Char.chr (97 + i)) = "abc"` *)
  val tabulate : int * (int -> elem) -> vector

  (* `length x` is the number of elements.

     Law: `length (fromList l) = List.length l`

     Example: `length "abc" = 3` *)
  val length : vector -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length x`.

     Example: `sub ("abc", 1) = #"b"` *)
  val sub : vector * int -> elem

  (* `update (v, i, x)` is a new vector like `v` but with `x` at position `i`.

     `v` itself is not changed.

     Raises: `Subscript` if `i < 0` or `i >= length v`.

     Law: `sub (update (v, i, x), i) = x`

     Law: `sub (update (v, i, x), j) = sub (v, j)` for `j <> i andalso 0 <= j
     andalso j < length v`

     Example: `update ("abc", 1, #"x") = "axc"` *)
  val update : vector * int * elem -> vector

  (* `concat l` is the vectors of `l` one after another.

     Raises: `Size` if the result would be longer than `maxLen`.

     Law: `length (concat l) = List.foldl (fn (v, n) => length v + n) 0 l`

     Example: `concat ["ab", "", "c"] = "abc"` *)
  val concat : vector list -> vector

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

     Example: `let val r = ref [] in appi (fn (i, c) => r := (i, c) :: !r)
     "ab"; !r end = [(1, #"b"), (0, #"a")]` *)
  val appi : (int * elem -> unit) -> vector -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect.

     Law: `app f x = appi (fn (_, e) => f e) x`

     Example: `let val s = ref 0 in app (fn c => s := !s + Char.ord c) (fromList [#"a", #"b"]); !s end = 195` *)
  val app : (elem -> unit) -> vector -> unit

  (* `mapi f v` is the vector of the results of `f` on the index and the element of each position.

     `f` is applied from 0 up.

     Example: `mapi (fn (i, c) => if i = 0 then Char.toUpper c else c) "abc" =
     "Abc"` *)
  val mapi : (int * elem -> elem) -> vector -> vector

  (* `map f v` is the vector of the results of `f` on each element, in order.

     Law: `map f v = mapi (fn (_, e) => f e) v`

     Example: `map Char.toUpper "abc" = "ABC"` *)
  val map : (elem -> elem) -> vector -> vector

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well.

     Example: `foldli (fn (i, c, acc) => (i, c) :: acc) [] "ab" = [(1, #"b"),
     (0, #"a")]` *)
  val foldli : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well.

     Example: `foldri (fn (i, c, acc) => (i, c) :: acc) [] "ab" = [(0, #"a"),
     (1, #"b")]` *)
  val foldri : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does.

     Law: `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldl (op ::) [] "abc" = [#"c", #"b", #"a"]` *)
  val foldl : (elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does.

     Law: `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldr (op ::) [] "abc" = [#"a", #"b", #"c"]` *)
  val foldr : (elem * 'a -> 'a) -> 'a -> vector -> 'a

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

     `p` is applied from 0 up, and not after the first position that
     satisfies it.

     Example: `findi (fn (i, c) => i > 0 andalso c = #"a") "aba" = SOME (2,
     #"a")` *)
  val findi : (int * elem -> bool) -> vector -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

     Law: `find p x = Option.map #2 (findi (fn (_, e) => p e) x)`

     Example: `find Char.isDigit "a12" = SOME #"1"` *)
  val find : (elem -> bool) -> vector -> elem option

  (* `exists p x` is `true` when some element satisfies `p`; it stops at the first that does.

     Law: `exists p x = isSome (find p x)`

     Example: `exists Char.isDigit "ab" = false` *)
  val exists : (elem -> bool) -> vector -> bool

  (* `all p x` is `true` when every element satisfies `p`; it stops at the first that does not.

     Law: `all p x = not (exists (not o p) x)`

     Example: `all Char.isLower "ab" = true` *)
  val all : (elem -> bool) -> vector -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

     Law: `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)`

     Example: `collate Char.compare ("ab", "ac") = LESS` *)
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

  (* The type of the elements: `Word8.word` for `Word8Array`, `char` for `CharArray`. *)
  type elem

  (* The type of these vectors. *)
  type vector

  (* The greatest length such an array may have.

     Implementation: `MONO_ARRAY.maxLen/value`. `Array.maxLen`, 100,000,000,
     for every instance, those of characters and of bytes too.

     Pinned by: `*Array.maxLen/covers-created-arrays`

     Example: `maxLen = 100000000` *)
  val maxLen : int

  (* `array (n, x)` is a new array of `n` elements, each of them `x`.

     Raises: `Size` if `n < 0` or `n > maxLen`.

     Law: `sub (array (n, x), i) = x` for `0 <= i andalso i < n`

     Example: `vector (array (3, #"x")) = "xxx"` *)
  val array : int * elem -> array

  (* `fromList l` is a new array of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`.

     Law: `sub (fromList l, i) = List.nth (l, i)` for `0 <= i andalso i <
     List.length l`

     Example: `sub (fromList [#"a", #"b"], 1) = #"b"` *)
  val fromList : elem list -> array

  (* `tabulate (n, f)` is a new array of `f 0`, ..., `f (n - 1)`, applied in order.

     Raises: `Size` if `n < 0` or `n > maxLen`.

     Reading: `MONO_ARRAY.tabulate/Size-before-f`. The specification does not
     say whether the length is checked before `f` is applied. It is, as for
     `Array.tabulate`: a length out of range raises `Size` without applying
     `f` at all.

     Pinned by: `*Array.tabulate/Size-before-f`

     Law: `sub (tabulate (n, f), i) = f i` for `0 <= i andalso i < n`, when `f`
     has no effects

     Example: `vector (tabulate (3, fn i => Char.chr (97 + i))) = "abc"` *)
  val tabulate : int * (int -> elem) -> array

  (* `length x` is the number of elements.

     Law: `length (fromList l) = List.length l`

     Example: `length (fromList [#"a", #"b"]) = 2` *)
  val length : array -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length x`.

     Example: `sub (fromList [#"a", #"b"], 0) = #"a"` *)
  val sub : array * int -> elem

  (* `update (arr, i, x)` puts `x` at position `i` of `arr`.

     Raises: `Subscript` if `i < 0` or `i >= length arr`.

     Law: `(update (arr, i, x); sub (arr, i)) = x` for `0 <= i andalso i <
     length arr`

     Example: `let val a = array (3, #"-") in update (a, 1, #"x"); vector a end
     = "-x-"` *)
  val update : array * int * elem -> unit

  (* `vector arr` is an immutable vector of the elements of `arr`, which is a copy.

     Example: `vector (fromList [#"h", #"i"]) = "hi"` *)
  val vector : array -> vector

  (* `copy {src, dst, di}` copies `src` into `dst` from position `di` on.

     `src` and `dst` may be the same array, and then `di` must be 0: an array
     cannot hold itself at any other position, so any other `di` raises
     `Subscript`, and at 0 the copy changes nothing. Two stretches of one array
     that overlap are what `MONO_ARRAY_SLICE.copy` is for.

     Raises: `Subscript` if `di < 0` or `di + length src > length dst`, and
     then nothing has been copied.

     Law: `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub
     (src, i)` for `0 <= i andalso i < length src andalso src <> dst`

     Example: `let val b = array (4, #".") in copy {src = fromList [#"a", #"b",
     #"c"], dst = b, di = 1}; vector b end = ".abc"` *)
  val copy : {src : array, dst : array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the vector `src` into `dst` from position `di` on.

     Raises: `Subscript` if `di < 0` or `di` plus the length of `src` is more
     than `length dst`, and then nothing has been copied.

     Example: `let val a = array (4, #".") in copyVec {src = "ab", dst = a, di =
     2}; vector a end = "..ab"` *)
  val copyVec : {src : vector, dst : array, di : int} -> unit

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

     Example: `let val r = ref [] in appi (fn (i, c) => r := (i, c) :: !r)
     (fromList [#"a", #"b"]); !r end = [(1, #"b"), (0, #"a")]` *)
  val appi : (int * elem -> unit) -> array -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect.

     Law: `app f x = appi (fn (_, e) => f e) x`

     Example: `let val s = ref 0 in app (fn c => s := !s + Char.ord c) (fromList [#"a", #"b"]); !s end = 195` *)
  val app : (elem -> unit) -> array -> unit

  (* `modifyi f x` replaces the element at each position by `f` of the index and that element, in place, from 0 up.

     Example: `let val a = fromList [#"a", #"b", #"c"] in modifyi (fn (i, c) =>
     if i = 1 then Char.toUpper c else c) a; vector a end = "aBc"` *)
  val modifyi : (int * elem -> elem) -> array -> unit

  (* `modify f x` replaces every element by `f` of it, in place, from 0 up.

     Law: `modify f x = modifyi (fn (_, e) => f e) x`

     Example: `let val a = fromList [#"a", #"b"] in modify Char.toUpper a;
     vector a end = "AB"` *)
  val modify : (elem -> elem) -> array -> unit

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well.

     Example: `foldli (fn (i, c, acc) => (i, c) :: acc) [] (fromList [#"a",
     #"b"]) = [(1, #"b"), (0, #"a")]` *)
  val foldli : (int * elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well.

     Example: `foldri (fn (i, c, acc) => (i, c) :: acc) [] (fromList [#"a",
     #"b"]) = [(0, #"a"), (1, #"b")]` *)
  val foldri : (int * elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does.

     Law: `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldl (op ::) [] (fromList [#"a", #"b", #"c"]) = [#"c", #"b",
     #"a"]` *)
  val foldl : (elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does.

     Law: `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldr (op ::) [] (fromList [#"a", #"b", #"c"]) = [#"a", #"b",
     #"c"]` *)
  val foldr : (elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

     `p` is applied from 0 up, and not after the first position that
     satisfies it.

     Example: `findi (fn (i, c) => i > 0 andalso c = #"a") (fromList [#"a",
     #"b", #"a"]) = SOME (2, #"a")` *)
  val findi : (int * elem -> bool) -> array -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

     Law: `find p x = Option.map #2 (findi (fn (_, e) => p e) x)`

     Example: `find Char.isDigit (fromList [#"a", #"1", #"2"]) = SOME #"1"` *)
  val find : (elem -> bool) -> array -> elem option

  (* `exists p x` is `true` when some element satisfies `p`; it stops at the first that does.

     Law: `exists p x = isSome (find p x)`

     Example: `exists Char.isDigit (fromList [#"a", #"b"]) = false` *)
  val exists : (elem -> bool) -> array -> bool

  (* `all p x` is `true` when every element satisfies `p`; it stops at the first that does not.

     Law: `all p x = not (exists (not o p) x)`

     Example: `all Char.isLower (fromList [#"a", #"b"]) = true` *)
  val all : (elem -> bool) -> array -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

     This compares what the arrays hold, where `=` compares which array it
     is.

     Law: `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)`

     Example: `collate Char.compare (fromList [#"a", #"b"], fromList [#"a",
     #"c"]) = LESS` *)
  val collate : (elem * elem -> order) -> array * array -> order
end


(* The same as `MONO_VECTOR`, with a vector type that admits equality.

   Area: Sequences

   Status: extension

   Deviation: `MONO_VECTOR_EQ/not-in-the-specification`. This signature is
   not in the specification, and it is here because the specification asks
   for something it gives no way to say: `WideCharVector.vector` has to admit
   equality, and the declaration the page gives `WideCharVector` cannot make
   it -- see the erratum `MONO_VECTOR/WideCharVector-must-admit-equality`.
   `MONO_VECTOR` writes `type vector`, not `eqtype`, so that a family whose
   elements do not admit equality can have a vector; a family whose vector is
   a type of its own and does admit it is sealed with this instead. The
   specification's own way out is `where type vector = WideString.string` on
   the instance, which Rune cannot use because `WideString` is declared after
   `WideCharVector` and is built on it -- `WideString.string` must be a type
   name of its own for wide string constants to be overloaded at it. *)
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

     Raises: `Size` if `l` is longer than `maxLen`.

     Example: `fromList [WideChar.chr 65, WideChar.chr 0x3BB] = fromList [WideChar.chr 65, WideChar.chr 0x3BB]` *)
  val fromList : elem list -> vector

  (* `tabulate (n, f)` is the sequence of `f 0`, ..., `f (n - 1)`, applied in order.

     Raises: `Size` if `n < 0` or `n > maxLen`, before `f` is applied. *)
  val tabulate : int * (int -> elem) -> vector

  (* `length x` is the number of elements.

     Example: `length (fromList [WideChar.chr 0x10000]) = 1` *)
  val length : vector -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i` is outside.

     Example: `WideChar.ord (sub (fromList [WideChar.chr 65, WideChar.chr 0x3BB], 1)) = 0x3BB` *)
  val sub : vector * int -> elem

  (* `update (v, i, x)` is a new vector like `v` but with `x` at position `i`.

     Raises: `Subscript` if `i` is outside `v`.

     Example: `update (fromList [WideChar.chr 65], 0, WideChar.chr 66) = fromList [WideChar.chr 66]` *)
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

  (* `map f v` is the vector of the results of `f` on each element, in order.

     Example: `map WideChar.toUpper (fromList [WideChar.chr 97]) = fromList [WideChar.chr 65]` *)
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

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

     Example: `collate WideChar.compare (fromList [WideChar.chr 65], fromList [WideChar.chr 66]) = LESS` *)
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
  (* The type of the elements: `Word8.word` for `Word8VectorSlice`, `char` for `CharVectorSlice`. *)
  type elem

  (* The type of these vectors. *)
  type vector

  (* The type of slices of one of these. *)
  type slice

  (* `length x` is the number of elements.

     Law: `length (slice (v, i, SOME n)) = n` when `(ignore (slice (v, i, SOME
     n)); true)`

     Example: `length (slice ("abc", 1, NONE)) = 2` *)
  val length : slice -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length x`.

     Example: `sub (slice ("abc", 1, NONE), 0) = #"b"` *)
  val sub : slice * int -> elem

  (* `full v` is the whole of `v` as a slice: `slice (v, 0, NONE)`.

     Law: `vector (full v) = v` for a vector type that admits equality

     Example: `vector (full "hi") = "hi"` *)
  val full : vector -> slice

  (* `slice (v, i, sz)` is the stretch of `v` from `i`, of `sz` elements or to the end.

     Raises: `Subscript` if `i < 0` or `i` is more than the length of `v`, or,
     with `SOME n`, if `n < 0` or `i + n` is more than the length of `v`.

     Example: `vector (slice ("abcd", 1, SOME 2)) = "bc"` *)
  val slice : vector * int * int option -> slice

  (* `subslice (sl, i, sz)` is the stretch of `sl` from `i`, of `sz` elements or to its end.

     The bounds are those of `sl`, not of what it is a slice of.

     Raises: `Subscript` if `i < 0` or `i > length sl`, or, with `SOME n`, if
     `n < 0` or `i + n > length sl`.

     Law: `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k
     andalso k < length sl - i`

     Example: `vector (subslice (slice ("abcd", 1, NONE), 1, SOME 1)) = "c"` *)
  val subslice : slice * int * int option -> slice

  (* `base sl` is the vector `sl` is a stretch of, where it starts and how long it is.

     Example: `base (slice ("abcd", 1, SOME 2)) = ("abcd", 1, 2)` *)
  val base : slice -> vector * int * int

  (* `vector sl` is a vector of the elements of `sl`, which is a copy of them.

     Example: `vector (slice ("abc", 1, NONE)) = "bc"` *)
  val vector : slice -> vector

  (* `concat l` is the vector of the elements of the slices of `l`, one after another.

     Raises: `Size` if the result would be longer than a vector can be: the
     `maxLen` of the vector structure.

     Law: `length (full (concat l)) = List.foldl (fn (sl, n) => length sl + n) 0 l`

     Example: `concat [slice ("abc", 1, NONE), full "d"] = "bcd"` *)
  val concat : slice list -> vector

  (* `isEmpty sl` is `true` when `sl` has no elements.

     Law: `isEmpty sl = (length sl = 0)`

     Example: `isEmpty (slice ("a", 1, NONE)) = true` *)
  val isEmpty : slice -> bool

  (* `getItem sl` is `NONE` when `sl` is empty, and `SOME (x, rest)` otherwise.

     It has the shape of a `StringCvt.reader`. `rest` is a slice of the same
     vector, so it is had for nothing.

     Example: `(case getItem (full "ab") of SOME (c, rest) => (c, vector rest)
     | NONE => (#" ", "")) = (#"a", "b")` *)
  val getItem : slice -> (elem * slice) option

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

     The index is that of the element in the slice, counted from 0.

     Example: `let val r = ref [] in appi (fn (i, c) => r := (i, c) :: !r)
     (slice ("abc", 1, NONE)); !r end = [(1, #"c"), (0, #"b")]` *)
  val appi : (int * elem -> unit) -> slice -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect.

     Law: `app f x = appi (fn (_, e) => f e) x` *)
  val app : (elem -> unit) -> slice -> unit

  (* `mapi f sl` is the vector of the results of `f` on the index and the element of each position.

     The index is that of the element in the slice, and `f` is applied from
     0 up.

     Example: `mapi (fn (i, c) => if i = 0 then Char.toUpper c else c) (slice
     ("abc", 1, NONE)) = "Bc"` *)
  val mapi : (int * elem -> elem) -> slice -> vector

  (* `map f sl` is the vector of the results of `f` on each element, in order.

     Law: `map f sl = mapi (fn (_, e) => f e) sl`

     Example: `map Char.toUpper (slice ("abc", 1, NONE)) = "BC"` *)
  val map : (elem -> elem) -> slice -> vector

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well.

     The index is that of the element in the slice, counted from 0.

     Example: `foldli (fn (i, c, acc) => (i, c) :: acc) [] (slice ("abc", 1,
     NONE)) = [(1, #"c"), (0, #"b")]` *)
  val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does.

     Law: `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldr (op ::) [] (full "ab") = [#"a", #"b"]` *)
  val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does.

     Law: `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldl (op ::) [] (full "ab") = [#"b", #"a"]` *)
  val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well.

     The index is that of the element in the slice, counted from 0.

     Example: `foldri (fn (i, c, acc) => (i, c) :: acc) [] (slice ("abc", 1,
     NONE)) = [(0, #"b"), (1, #"c")]` *)
  val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

     The index is that of the element in the slice; `p` is applied from 0 up,
     and not after the first position that satisfies it.

     Example: `findi (fn (_, c) => c = #"a") (slice ("aba", 1, NONE)) = SOME
     (1, #"a")` *)
  val findi : (int * elem -> bool) -> slice -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

     Law: `find p x = Option.map #2 (findi (fn (_, e) => p e) x)`

     Example: `find Char.isDigit (full "a1") = SOME #"1"` *)
  val find : (elem -> bool) -> slice -> elem option

  (* `exists p x` is `true` when some element satisfies `p`; it stops at the first that does.

     Only the elements of the slice are looked at, not the rest of its vector.

     Law: `exists p x = isSome (find p x)`

     Example: `exists (fn c => c = #"a") (slice ("ab", 1, NONE)) = false` *)
  val exists : (elem -> bool) -> slice -> bool

  (* `all p x` is `true` when every element satisfies `p`; it stops at the first that does not.

     Law: `all p x = not (exists (not o p) x)`

     Example: `all Char.isLower (slice ("Ab", 1, NONE)) = true` *)
  val all : (elem -> bool) -> slice -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

     Law: `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)`

     Example: `collate Char.compare (slice ("abc", 1, NONE), full "b") =
     GREATER` *)
  val collate : (elem * elem -> order) -> slice * slice -> order
end

(* A stretch of an array of one element type, without a copy of it.

   Area: Sequences

   See also: `ARRAY_SLICE`, `MONO_ARRAY`, `MONO_VECTOR_SLICE` *)
signature MONO_ARRAY_SLICE =
sig
  (* The type of the elements: `Word8.word` for `Word8ArraySlice`, `char` for `CharArraySlice`. *)
  type elem

  (* The type of these arrays. *)
  type array

  (* The type of slices of one of these. *)
  type slice

  (* The type of these vectors. *)
  type vector

  (* The type of slices of the corresponding vector. *)
  type vector_slice

  (* `length x` is the number of elements.

     Example: `length (slice (CharArray.fromList [#"a", #"b", #"c"], 1, NONE)) = 2` *)
  val length : slice -> int

  (* `sub (x, i)` is the element at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length x`.

     Example: `sub (slice (CharArray.fromList [#"a", #"b", #"c"], 1, NONE), 0) = #"b"` *)
  val sub : slice * int -> elem

  (* `update (sl, i, x)` puts `x` at position `i` of `sl`, and so of its array.

     Raises: `Subscript` if `i < 0` or `i >= length sl`.

     Law: `(update (sl, i, x); sub (sl, i)) = x` for `0 <= i andalso i < length
     sl`

     Example: `let val a = CharArray.fromList [#"a", #"b", #"c"] in update (slice (a, 1,
     NONE), 0, #"x"); CharArray.vector a end = "axc"` *)
  val update : slice * int * elem -> unit

  (* `full arr` is the whole of `arr` as a slice: `slice (arr, 0, NONE)`.

     Example: `vector (full (CharArray.fromList [#"h", #"i"])) = "hi"` *)
  val full : array -> slice

  (* `slice (arr, i, sz)` is the stretch of `arr` from `i`, of `sz` elements or to the end.

     Raises: `Subscript` if `i < 0` or `i` is more than the length of `arr`,
     or, with `SOME n`, if `n < 0` or `i + n` is more than the length of
     `arr`; never `Overflow` (`ArraySlice.slice/Subscript-not-Overflow`).

     Example: `vector (slice (CharArray.fromList [#"a", #"b", #"c", #"d"], 1,
     SOME 2)) = "bc"` *)
  val slice : array * int * int option -> slice

  (* `subslice (sl, i, sz)` is the stretch of `sl` from `i`, of `sz` elements or to its end.

     The bounds are those of `sl`, not of what it is a slice of.

     Raises: `Subscript` if `i < 0` or `i > length sl`, or, with `SOME n`, if
     `n < 0` or `i + n > length sl`.

     Law: `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k
     andalso k < length sl - i`

     Example: `vector (subslice (slice (CharArray.fromList [#"a", #"b", #"c",
     #"d"], 1, NONE), 1, SOME 1)) = "c"` *)
  val subslice : slice * int * int option -> slice

  (* `base sl` is the array `sl` is a stretch of, where it starts and how long it is.

     Example: `let val (_, i, n) = base (slice (CharArray.fromList [#"a", #"b",
     #"c", #"d"], 1, SOME 2)) in (i, n) end = (1, 2)` *)
  val base : slice -> array * int * int

  (* `vector sl` is a vector of the elements of `sl`, which is a copy of them.

     Example: `vector (slice (CharArray.fromList [#"a", #"b"], 1, NONE)) = "b"` *)
  val vector : slice -> vector

  (* `copy {src, dst, di}` copies the slice `src` into `dst` from position `di` on.

     The slice may be a stretch of `dst` itself and the two may overlap:
     every element arrives as it was before the copy began.

     Raises: `Subscript` if `di < 0` or `di + length src` is more than the
     length of `dst`, and then nothing has been copied.

     Example: `let val a = CharArray.fromList [#"a", #"b", #"c", #"d"] in copy
     {src = slice (a, 0, SOME 3), dst = a, di = 1}; CharArray.vector a end =
     "aabc"` *)
  val copy : {src : slice, dst : array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the vector slice `src` into `dst` from position `di` on.

     Raises: `Subscript` if `di < 0` or `di` plus the length of `src` is more
     than the length of `dst`, and then nothing has been copied.

     Example: `let val a = CharArray.array (3, #".") in copyVec {src =
     CharVectorSlice.slice ("xyz", 1, NONE), dst = a, di = 0};
     CharArray.vector a end = "yz."` *)
  val copyVec : {src : vector_slice, dst : array, di : int} -> unit

  (* `isEmpty sl` is `true` when `sl` has no elements.

     Law: `isEmpty sl = (length sl = 0)`

     Example: `isEmpty (slice (CharArray.fromList [#"a"], 1, NONE)) = true` *)
  val isEmpty : slice -> bool

  (* `getItem sl` is `NONE` when `sl` is empty, and `SOME (x, rest)` otherwise.

     It has the shape of a `StringCvt.reader`. `rest` is a slice of the same
     array, so it is had for nothing.

     Example: `(case getItem (full (CharArray.fromList [#"a", #"b"])) of SOME
     (c, rest) => (c, length rest) | NONE => (#" ", 0)) = (#"a", 1)` *)
  val getItem : slice -> (elem * slice) option

  (* `appi f x` applies `f` to the index and the element of each position, from 0 up, for its effect.

     The index is that of the element in the slice, counted from 0.

     Example: `let val r = ref [] in appi (fn (i, c) => r := (i, c) :: !r)
     (slice (CharArray.fromList [#"a", #"b", #"c"], 1, NONE)); !r end = [(1, #"c"), (0,
     #"b")]` *)
  val appi : (int * elem -> unit) -> slice -> unit

  (* `app f x` applies `f` to every element, from 0 up, for its effect.

     Law: `app f x = appi (fn (_, e) => f e) x`

     Example: `let val s = ref 0 in app (fn c => s := !s + Char.ord c) (full (CharArray.fromList [#"a", #"b"])); !s end = 195` *)
  val app : (elem -> unit) -> slice -> unit

  (* `modifyi f x` replaces the element at each position by `f` of the index and that element, in place.

     The index is that of the element in the slice, and the elements are
     replaced from 0 up.

     Example: `let val a = CharArray.fromList [#"a", #"b", #"c"] in modifyi (fn (i, c) =>
     if i = 0 then Char.toUpper c else c) (slice (a, 1, NONE));
     CharArray.vector a end = "aBc"` *)
  val modifyi : (int * elem -> elem) -> slice -> unit

  (* `modify f x` replaces every element by `f` of it, in place, from 0 up.

     Law: `modify f x = modifyi (fn (_, e) => f e) x`

     Example: `let val a = CharArray.fromList [#"a", #"b", #"c"] in modify Char.toUpper
     (slice (a, 1, NONE)); CharArray.vector a end = "aBC"` *)
  val modify : (elem -> elem) -> slice -> unit

  (* `foldli f init x` combines the elements from the left, giving `f` the index as well.

     The index is that of the element in the slice, counted from 0.

     Example: `foldli (fn (i, c, acc) => (i, c) :: acc) [] (slice (CharArray.fromList [#"a", #"b", #"c"], 1, NONE)) = [(1, #"c"), (0, #"b")]` *)
  val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldr f init x` combines the elements from the right, as `List.foldr` does.

     Law: `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldr (op ::) [] (full (CharArray.fromList [#"a", #"b"])) =
     [#"a", #"b"]` *)
  val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldl f init x` combines the elements from the left, as `List.foldl` does.

     Law: `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x`

     Example: `foldl (op ::) [] (full (CharArray.fromList [#"a", #"b"])) =
     [#"b", #"a"]` *)
  val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `foldri f init x` combines the elements from the right, giving `f` the index as well.

     The index is that of the element in the slice, counted from 0.

     Example: `foldri (fn (i, c, acc) => (i, c) :: acc) [] (slice (CharArray.fromList [#"a", #"b", #"c"], 1, NONE)) = [(0, #"b"), (1, #"c")]` *)
  val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b

  (* `findi p x` is `SOME (i, e)` for the first position whose index and element satisfy `p`, or `NONE`.

     The index is that of the element in the slice; `p` is applied from 0 up,
     and not after the first position that satisfies it.

     Example: `findi (fn (_, c) => c = #"a") (slice (CharArray.fromList [#"a",
     #"b", #"a"], 1, NONE)) = SOME (1, #"a")` *)
  val findi : (int * elem -> bool) -> slice -> (int * elem) option

  (* `find p x` is `SOME e` for the first element that satisfies `p`, or `NONE`.

     Law: `find p x = Option.map #2 (findi (fn (_, e) => p e) x)`

     Example: `find Char.isDigit (full (CharArray.fromList [#"a", #"1"])) =
     SOME #"1"` *)
  val find : (elem -> bool) -> slice -> elem option

  (* `exists p x` is `true` when some element satisfies `p`; it stops at the first that does.

     Only the elements of the slice are looked at, not the rest of its array.

     Law: `exists p x = isSome (find p x)`

     Example: `exists (fn c => c = #"a") (slice (CharArray.fromList [#"a",
     #"b"], 1, NONE)) = false` *)
  val exists : (elem -> bool) -> slice -> bool

  (* `all p x` is `true` when every element satisfies `p`; it stops at the first that does not.

     Law: `all p x = not (exists (not o p) x)`

     Example: `all Char.isLower (slice (CharArray.fromList [#"A", #"b"], 1,
     NONE)) = true` *)
  val all : (elem -> bool) -> slice -> bool

  (* `collate cmp (a, b)` compares the elements of two of these lexicographically with `cmp`.

     Law: `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)`

     Example: `collate Char.compare (slice (CharArray.fromList [#"a", #"b", #"c"], 1,
     NONE), full (CharArray.fromList [#"b"])) = GREATER` *)
  val collate : (elem * elem -> order) -> slice * slice -> order
end

(* `Word8Vector`, as the library sees it: the members of the specification and
   the two conversions that say a vector of bytes is a string underneath. A
   program sees `MONO_VECTOR`, which the seal file gives it. The slice's own
   signature is in word8vector.sml, where `Substring` is in scope. *)
signature RUNE_MONO_VECTOR_BYTES =
sig
  include MONO_VECTOR_EQ
  val toString : vector -> string
  val fromString : string -> vector
end
