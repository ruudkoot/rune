(* Two-dimensional arrays of one element type, as `ARRAY2` describes them for
   any element type.

   Everything here means what it means in `ARRAY2`, whose page describes
   regions and traversals at more length; only the element type is fixed, and
   `row` and `column` give the vector of that element type rather than a
   polymorphic one.

   Area: Sequences

   Status: optional

   See also: `ARRAY2`, `MONO_ARRAY`, `MONO_VECTOR`

   Erratum: `MONO_ARRAY2/instance-constraints`. The specification writes the
   identity of `vector` with the family's vector and of `elem` with its
   element as constraints on the structure; they are checked in the suite
   instead, structure by structure. *)
signature MONO_ARRAY2 =
sig
  (* The type of these two-dimensional arrays.

     Two are equal when they are the same array.

     Implementation: `MONO_ARRAY2.array/abstract-over-Array2`. An
     `IntArray2.array` is an `Array2.array` of its elements underneath, but
     the type is abstract. It is built on the implementation beneath the
     sealed `Array2` rather than on `Array2` itself, because this signature
     asks for an `eqtype array` and a sealed `'a Array2.array` gives none at
     `real` -- see the erratum `ARRAY2/sealed-and-equal-at-any-element`. As
     for `MONO_VECTOR.vector`, no check can pin an abstract type; what holds
     it is the page of the types that are one type. *)
  eqtype array

  (* The type of the elements. *)
  type elem

  (* The type of the vectors that `row` and `column` give: the one of the family. *)
  type vector

  (* A rectangle inside an array, as in `ARRAY2`: where it starts and how far
     it reaches, with `NONE` for "to the edge".

     Reading: `MONO_ARRAY2.region/at-the-end`. A region that starts at the
     edge of the array, and one of no rows or no columns, is valid and
     covers nothing. *)
  type region = {base : array, row : int, col : int, nrows : int option, ncols : int option}

  (* Which way a traversal goes: the `traversal` of `Array2`, so that the two
     structures speak of one type. *)
  datatype traversal = datatype Array2.traversal

  (* ---- Making an array ---- *)

  (* `array (r, c, x)` is a new array of `r` rows and `c` columns, every element `x`.

     Raises: `Size` if `r < 0`, `c < 0`, or the array would be too large.

     Law: `sub (array (r, c, x), i, j) = x` for `0 <= i < r` and `0 <= j < c`

     Example: `dimensions (array (2, 3, 0)) = (2, 3)` *)
  val array : int * int * elem -> array

  (* `fromList rows` is a new array of the lists of `rows`, one row each.

     Raises: `Size` if the lists are not all of one length, or if the array
     would be too large.

     Law: `sub (fromList rows, i, j) = List.nth (List.nth (rows, i), j)` for
     every row `i` and column `j` of the array

     Example: `sub (fromList [[1, 2], [3, 4]], 1, 0) = 3` *)
  val fromList : elem list list -> array

  (* `tabulate trv (r, c, f)` is a new array whose element at `(i, j)` is `f (i, j)`, applied in the order `trv` gives.

     Raises: `Size` if `r < 0`, `c < 0` or the array would be too large.

     Reading: `MONO_ARRAY2.tabulate/Size-before-f`. The specification does not
     say whether the dimensions are checked before `f` is applied. They are,
     as for `Array2.tabulate`: a negative dimension, or an array that is too
     large, raises `Size` without applying `f` at all.

     Pinned by: `*Array2.tabulate/Size-before-f`

     Law: `sub (tabulate trv (r, c, f), i, j) = f (i, j)` for `0 <= i < r` and
     `0 <= j < c`, when `f` has no effects

     Example: `IntVector.foldr (op ::) [] (row (tabulate RowMajor (2, 3, fn (i, j) => 10 * i + j), 1)) = [10, 11, 12]` *)
  val tabulate : traversal -> int * int * (int * int -> elem) -> array

  (* ---- Elements ---- *)

  (* `sub (arr, i, j)` is the element in row `i` and column `j`.

     Raises: `Subscript` if `i` or `j` is outside the array.

     Example: `sub (fromList [[1, 2], [3, 4]], 0, 1) = 2` *)
  val sub : array * int * int -> elem

  (* `update (arr, i, j, x)` puts `x` in row `i` and column `j`.

     Raises: `Subscript` if `i` or `j` is outside the array.

     Law: `(update (arr, i, j, x); sub (arr, i, j)) = x` for every row `i` and
     column `j` of `arr`

     Example: `let val a = array (2, 2, 0) in update (a, 1, 0, 7); IntVector.foldr (op ::) [] (row (a, 1)) end
     = [7, 0]` *)
  val update : array * int * int * elem -> unit

  (* ---- Shape ---- *)

  (* `dimensions arr` is the pair of the number of rows and the number of columns.

     Example: `dimensions (fromList [[1, 2, 3]]) = (1, 3)` *)
  val dimensions : array -> int * int

  (* `nCols arr` is the number of columns.

     Law: `nCols arr = #2 (dimensions arr)`

     Example: `nCols (fromList [[1, 2, 3]]) = 3` *)
  val nCols : array -> int

  (* `nRows arr` is the number of rows.

     Law: `nRows arr = #1 (dimensions arr)`

     Example: `nRows (fromList [[1, 2, 3]]) = 1` *)
  val nRows : array -> int

  (* `row (arr, i)` is a vector of the elements of row `i`, left to right.

     Raises: `Subscript` if `i` is no row of `arr`.

     Example: `IntVector.foldr (op ::) [] (row (fromList [[1, 2], [3, 4]], 1)) = [3, 4]` *)
  val row : array * int -> vector

  (* `column (arr, j)` is a vector of the elements of column `j`, top to bottom.

     Raises: `Subscript` if `j` is no column of `arr`.

     Example: `IntVector.foldr (op ::) [] (column (fromList [[1, 2], [3, 4]], 1)) = [2, 4]` *)
  val column : array * int -> vector

  (* ---- Copying ---- *)

  (* `copy {src, dst, dst_row, dst_col}` copies the region `src` into `dst` at that corner.

     Source and destination may be one array and may overlap: every element
     arrives as it was before the copy began.

     Raises: `Subscript` if `src` is not a valid region, or if it does not
     fit into `dst` at that corner, which can happen for an empty region
     too.

     Example: `let val a = fromList [[1, 2], [3, 4]] in copy {src = {base = a,
     row = 0, col = 0, nrows = SOME 1, ncols = NONE}, dst = a, dst_row = 1,
     dst_col = 0}; IntVector.foldr (op ::) [] (row (a, 1)) end = [1, 2]` *)
  val copy : {src : region, dst : array, dst_row : int, dst_col : int} -> unit

  (* ---- Traversing ---- *)

  (* `appi trv f reg` applies `f` to the row, the column and the element of each position of the region.

     Raises: `Subscript` if `reg` is not a valid region.

     Example: `let val r = ref [] in appi ColMajor (fn (i, j, _) => r := (i, j)
     :: !r) {base = array (2, 2, 0), row = 0, col = 0, nrows = NONE, ncols =
     NONE}; !r end = [(1, 1), (0, 1), (1, 0), (0, 0)]` *)
  val appi : traversal -> (int * int * elem -> unit) -> region -> unit

  (* `app trv f arr` applies `f` to every element, in the order `trv` gives, for its effect.

     Law: `app trv f arr = appi trv (fn (_, _, x) => f x) {base = arr, row =
     0, col = 0, nrows = NONE, ncols = NONE}`

     Example: `let val r = ref [] in app ColMajor (fn x => r := x :: !r)
     (fromList [[1, 2], [3, 4]]); !r end = [4, 2, 3, 1]` *)
  val app : traversal -> (elem -> unit) -> array -> unit

  (* `foldi trv f init reg` combines the elements of the region, giving `f` the row and the column as well.

     Raises: `Subscript` if `reg` is not a valid region.

     Example: `foldi RowMajor (fn (i, j, x, acc) => (i, j, x) :: acc) [] {base
     = fromList [[1, 2], [3, 4]], row = 1, col = 0, nrows = NONE, ncols =
     NONE} = [(1, 1, 4), (1, 0, 3)]` *)
  val foldi : traversal -> (int * int * elem * 'b -> 'b) -> 'b -> region -> 'b

  (* `fold trv f init arr` combines every element, in the order `trv` gives.

     Law: `fold trv f init arr = foldi trv (fn (_, _, x, acc) => f (x, acc))
     init {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}`

     Example: `fold ColMajor (op ::) [] (fromList [[1, 2], [3, 4]]) = [4, 2, 3,
     1]` *)
  val fold : traversal -> (elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `modifyi trv f reg` replaces each element of the region by `f` of its row, its column and that element.

     Raises: `Subscript` if `reg` is not a valid region.

     Example: `let val a = fromList [[1, 2], [3, 4]] in modifyi RowMajor (fn
     (i, _, x) => x + 10 * i) {base = a, row = 0, col = 1, nrows = NONE, ncols
     = NONE}; IntVector.foldr (op ::) [] (column (a, 1)) end = [2, 14]` *)
  val modifyi : traversal -> (int * int * elem -> elem) -> region -> unit

  (* `modify trv f arr` replaces every element by `f` of it, in the order `trv` gives.

     Law: `modify trv f arr = modifyi trv (fn (_, _, x) => f x) {base = arr,
     row = 0, col = 0, nrows = NONE, ncols = NONE}`

     Example: `let val a = fromList [[1, 2], [3, 4]] in modify RowMajor (fn x
     => x * x) a; IntVector.foldr (op ::) [] (row (a, 1)) end = [9, 16]` *)
  val modify : traversal -> (elem -> elem) -> array -> unit
end
