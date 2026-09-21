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

     Deviation: `MONO_ARRAY2.array/not-abstract`. An `IntArray2.array` is an
     `int Array2.array`: the structures are applications of one functor over
     `Array2`, and they are bound to this signature without making their
     types their own. *)
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

     Raises: `Size` if `r < 0`, `c < 0`, or the array would be too large. *)
  val array : int * int * elem -> array

  (* `fromList rows` is a new array of the lists of `rows`, one row each.

     Raises: `Size` if the lists are not all of one length. *)
  val fromList : elem list list -> array

  (* `tabulate trv (r, c, f)` is a new array whose element at `(i, j)` is `f (i, j)`, applied in the order `trv` gives.

     Raises: `Size` if `r < 0`, `c < 0` or the array would be too large. *)
  val tabulate : traversal -> int * int * (int * int -> elem) -> array

  (* ---- Elements ---- *)

  (* `sub (arr, i, j)` is the element in row `i` and column `j`.

     Raises: `Subscript` if `i` or `j` is outside the array. *)
  val sub : array * int * int -> elem

  (* `update (arr, i, j, x)` puts `x` in row `i` and column `j`.

     Raises: `Subscript` if `i` or `j` is outside the array. *)
  val update : array * int * int * elem -> unit

  (* ---- Shape ---- *)

  (* `dimensions arr` is the pair of the number of rows and the number of columns. *)
  val dimensions : array -> int * int

  (* `nCols arr` is the number of columns. *)
  val nCols : array -> int

  (* `nRows arr` is the number of rows. *)
  val nRows : array -> int

  (* `row (arr, i)` is a vector of the elements of row `i`, left to right.

     Raises: `Subscript` if `i` is no row of `arr`. *)
  val row : array * int -> vector

  (* `column (arr, j)` is a vector of the elements of column `j`, top to bottom.

     Raises: `Subscript` if `j` is no column of `arr`. *)
  val column : array * int -> vector

  (* ---- Copying ---- *)

  (* `copy {src, dst, dst_row, dst_col}` copies the region `src` into `dst` at that corner.

     Source and destination may be one array and may overlap: every element
     arrives as it was before the copy began.

     Raises: `Subscript` if `src` is not a valid region, or if it does not
     fit into `dst` at that corner, which can happen for an empty region
     too. *)
  val copy : {src : region, dst : array, dst_row : int, dst_col : int} -> unit

  (* ---- Traversing ---- *)

  (* `appi trv f reg` applies `f` to the row, the column and the element of each position of the region.

     Raises: `Subscript` if `reg` is not a valid region. *)
  val appi : traversal -> (int * int * elem -> unit) -> region -> unit

  (* `app trv f arr` applies `f` to every element, in the order `trv` gives, for its effect. *)
  val app : traversal -> (elem -> unit) -> array -> unit

  (* `foldi trv f init reg` combines the elements of the region, giving `f` the row and the column as well.

     Raises: `Subscript` if `reg` is not a valid region. *)
  val foldi : traversal -> (int * int * elem * 'b -> 'b) -> 'b -> region -> 'b

  (* `fold trv f init arr` combines every element, in the order `trv` gives. *)
  val fold : traversal -> (elem * 'b -> 'b) -> 'b -> array -> 'b

  (* `modifyi trv f reg` replaces each element of the region by `f` of its row, its column and that element.

     Raises: `Subscript` if `reg` is not a valid region. *)
  val modifyi : traversal -> (int * int * elem -> elem) -> region -> unit

  (* `modify trv f arr` replaces every element by `f` of it, in the order `trv` gives. *)
  val modify : traversal -> (elem -> elem) -> array -> unit
end
