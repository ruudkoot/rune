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
     `Vector.maxLen`.

     Example: `maxLen = 100000000` *)
  val maxLen : int

  (* ---- Making an array ---- *)

  (* `array (n, x)` is a new array of `n` elements, each of them `x`.

     Raises: `Size` if `n < 0` or `n > maxLen`.

     Law: `sub (array (n, x), i) = x` for `0 <= i < n`

     Example: `vector (array (3, #"x")) = Vector.fromList [#"x", #"x", #"x"]` *)
  val array : int * 'a -> 'a array

  (* `fromList l` is a new array of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`.

     Law: `sub (fromList l, i) = List.nth (l, i)` for `0 <= i < List.length l`

     Example: `sub (fromList [10, 20, 30], 1) = 20` *)
  val fromList : 'a list -> 'a array

  (* `tabulate (n, f)` is a new array of `f 0`, `f 1`, ..., `f (n - 1)`.

     `f` is applied in order of increasing index.

     Raises: `Size` if `n < 0` or `n > maxLen`.

     Reading: `Array.tabulate/Size-before-f`. The specification does not say
     whether the length is checked before `f` is applied. It is: a length out
     of range raises `Size` without applying `f` at all, so no effect of `f`
     happens for an array that is never made.

     Law: `sub (tabulate (n, f), i) = f i` for `0 <= i < n`, when `f` has no
     effects

     Example: `vector (tabulate (4, fn i => i * i)) = Vector.fromList [0, 1, 4, 9]` *)
  val tabulate : int * (int -> 'a) -> 'a array

  (* ---- Elements ---- *)

  (* `length arr` is the number of elements of `arr`.

     Law: `length (fromList l) = List.length l`

     Example: `length (fromList [1, 2, 3]) = 3` *)
  val length : 'a array -> int

  (* `sub (arr, i)` is the element of `arr` at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length arr`.

     Example: `sub (fromList [#"a", #"b"], 1) = #"b"` *)
  val sub : 'a array * int -> 'a

  (* `update (arr, i, x)` puts `x` at position `i` of `arr`.

     Raises: `Subscript` if `i < 0` or `i >= length arr`.

     Law: `(update (arr, i, x); sub (arr, i)) = x` for `0 <= i < length arr`

     Example: `let val a = array (3, 0) in update (a, 1, 5); foldr (op ::) [] a
     end = [0, 5, 0]` *)
  val update : 'a array * int * 'a -> unit

  (* `vector arr` is an immutable vector of the elements of `arr`.

     It is a copy: a later `update` of `arr` does not touch it.

     Law: `vector arr = Vector.tabulate (length arr, fn i => sub (arr, i))`

     Example: `vector (fromList [1, 2]) = Vector.fromList [1, 2]` *)
  val vector : 'a array -> 'a vector

  (* ---- Copying ---- *)

  (* `copy {src, dst, di}` copies the elements of `src` into `dst`, starting at position `di`.

     `src` and `dst` may be the same array, and then `di` must be 0: an array
     cannot hold itself at any other position, so any other `di` raises
     `Subscript`, and at 0 the copy changes nothing. Two stretches of one array
     that overlap are what `ArraySlice.copy` is for.

     Raises: `Subscript` if `di < 0` or `di + length src > length dst`, and
     then nothing has been copied.

     Law: `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)`
     for `0 <= i < length src`, when `src` and `dst` are not the same array

     Example: `let val a = fromList [1, 2, 3, 4] in copy {src = a, dst = a, di
     = 0}; vector a end = Vector.fromList [1, 2, 3, 4]` *)
  val copy : {src : 'a array, dst : 'a array, di : int} -> unit

  (* `copyVec {src, dst, di}` copies the elements of the vector `src` into `dst`, starting at position `di`.

     Raises: `Subscript` if `di < 0` or `di + Vector.length src > length dst`,
     and then nothing has been copied.

     Law: `(copyVec {src = v, dst = dst, di = di}; sub (dst, di + i)) = Vector.sub (v, i)`
     for `0 <= i < Vector.length v`

     Example: `let val a = array (4, 0) in copyVec {src = Vector.fromList [1,
     2], dst = a, di = 1}; vector a end = Vector.fromList [0, 1, 2, 0]` *)
  val copyVec : {src : 'a vector, dst : 'a array, di : int} -> unit

  (* ---- Traversing ---- *)

  (* `appi f arr` applies `f` to the index and the element of each position, from 0 up, for its effect.

     Example: `let val r = ref [] in appi (fn (i, x) => r := (i, x) :: !r)
     (fromList ["a", "b"]); !r end = [(1, "b"), (0, "a")]` *)
  val appi : (int * 'a -> unit) -> 'a array -> unit

  (* `app f arr` applies `f` to every element, from 0 up, for its effect.

     Law: `app f arr = appi (fn (_, x) => f x) arr`

     Example: `let val s = ref 0 in app (fn x => s := !s + x) (fromList [1, 2, 3]); !s end = 6` *)
  val app : ('a -> unit) -> 'a array -> unit

  (* `modifyi f arr` replaces the element at each position by `f` of the index and that element.

     The array is changed in place, from 0 up.

     Example: `let val a = fromList [10, 20, 30] in modifyi (fn (i, x) => x + i)
     a; vector a end = Vector.fromList [10, 21, 32]` *)
  val modifyi : (int * 'a -> 'a) -> 'a array -> unit

  (* `modify f arr` replaces every element by `f` of it, in place, from 0 up.

     Law: `modify f arr = modifyi (fn (_, x) => f x) arr`

     Example: `let val a = fromList [1, 2, 3] in modify (fn x => x * 2) a;
     vector a end = Vector.fromList [2, 4, 6]` *)
  val modify : ('a -> 'a) -> 'a array -> unit

  (* `foldli f init arr` combines the elements from the left, giving `f` the index as well.

     Example: `foldli (fn (i, x, acc) => (i, x) :: acc) [] (fromList ["a", "b"])
     = [(1, "b"), (0, "a")]` *)
  val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* `foldri f init arr` combines the elements from the right, giving `f` the index as well.

     Example: `foldri (fn (i, x, acc) => (i, x) :: acc) [] (fromList ["a", "b"])
     = [(0, "a"), (1, "b")]` *)
  val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* `foldl f init arr` combines the elements from the left, as `List.foldl` does.

     Law: `foldl f init arr = foldli (fn (_, x, acc) => f (x, acc)) init arr`

     Example: `foldl (op ::) [] (fromList [1, 2, 3]) = [3, 2, 1]` *)
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* `foldr f init arr` combines the elements from the right, as `List.foldr` does.

     Law: `foldr f init arr = foldri (fn (_, x, acc) => f (x, acc)) init arr`

     Example: `foldr (op ::) [] (fromList [1, 2, 3]) = [1, 2, 3]` *)
  val foldr : ('a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* ---- Searching ---- *)

  (* `findi p arr` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`.

     `p` is applied from 0 up, and not after the first position that
     satisfies it.

     Example: `findi (fn (i, x) => i > 0 andalso x = 0) (fromList [0, 5, 0]) = SOME (2, 0)` *)
  val findi : (int * 'a -> bool) -> 'a array -> (int * 'a) option

  (* `find p arr` is `SOME x` for the first element that satisfies `p`, or `NONE`.

     Law: `find p arr = Option.map #2 (findi (fn (_, x) => p x) arr)`

     Example: `find (fn x => x > 1) (fromList [1, 2, 3]) = SOME 2` *)
  val find : ('a -> bool) -> 'a array -> 'a option

  (* `exists p arr` is `true` when some element satisfies `p`; it stops at the first that does.

     Law: `exists p arr = isSome (find p arr)`

     Example: `exists (fn x => x > 2) (fromList [1, 2, 3]) = true` *)
  val exists : ('a -> bool) -> 'a array -> bool

  (* `all p arr` is `true` when every element satisfies `p`; it stops at the first that does not.

     Law: `all p arr = not (exists (not o p) arr)`

     Example: `all (fn x => x > 0) (fromList [1, 2, 3]) = true` *)
  val all : ('a -> bool) -> 'a array -> bool

  (* `collate cmp (a, b)` compares the elements of two arrays lexicographically with `cmp`.

     This compares what the arrays hold, where `=` compares which array it
     is.

     Law: `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)`

     Example: `collate Int.compare (fromList [1, 2], fromList [1, 3]) = LESS` *)
  val collate : ('a * 'a -> order) -> 'a array * 'a array -> order
end
