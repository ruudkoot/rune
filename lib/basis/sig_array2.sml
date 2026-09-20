(* Two-dimensional arrays: mutable rectangles of elements, indexed by a row
   and a column.

   Rows and columns are counted from 0, and the first index is the row: `sub
   (arr, i, j)` is the element in row `i` and column `j`. An array of no rows
   or no columns holds nothing but still has its dimensions.

   The traversals take a region, a rectangle inside an array: its `base`,
   the `row` and `col` it starts at, and how many rows and columns it covers,
   where `NONE` means "to the edge". They also take a `traversal`, which says
   whether they go along the rows or down the columns; that decides the order
   the elements are visited in, and so what an effect sees.

   Area: Sequences

   Status: optional

   See also: `ARRAY`, `VECTOR`, `MONO_ARRAY2`

   Erratum: `ARRAY2/sub-indices`. The specification's description of `sub`
   says that "`i` gives the row index, and gives the column index"; the
   second is `j`. *)
signature ARRAY2 =
sig
  (* The type of two-dimensional arrays.

     Two are equal when they are the same array, as for `Array.array`. *)
  eqtype 'a array

  (* A rectangle inside an array: where it starts and how far it reaches.

     `NONE` for `nrows` or `ncols` means "as far as the array goes". A region
     is valid when it lies inside its base, and an empty one is valid too, so
     a region that starts at the edge and covers nothing is allowed and
     traverses nothing.

     Reading: `Array2.region/Subscript-not-Overflow`. Whether a region lies
     inside its array is decided without a sum that could overflow, so a region
     whose `row + nrows` is no `int` raises `Subscript` and never `Overflow`.
     `appi`, `foldi` and `modifyi` find that out before `f` is applied to
     anything, so a bad region changes nothing.

     Pinned by: `Array2.*/Subscript-not-Overflow*`,
     `Array2.appi/Subscript-before-f` *)
  type 'a region = {base : 'a array,       (* the array the rectangle is in *)
                    row : int,             (* the row it starts at *)
                    col : int,             (* the column it starts at *)
                    nrows : int option,    (* how many rows, or NONE for all that are left *)
                    ncols : int option}    (* how many columns, or NONE for all that are left *)

  (* Which way a traversal goes. *)
  datatype traversal
    = RowMajor   (* along each row in turn: (0,0), (0,1), ..., (1,0), ... *)
    | ColMajor   (* down each column in turn: (0,0), (1,0), ..., (0,1), ... *)

  (* ---- Making an array ---- *)

  (* `array (r, c, x)` is a new array of `r` rows and `c` columns, every element `x`.

     Raises: `Size` if `r < 0`, `c < 0`, or the array would be too large.

     Implementation: `Array2.array/Size`. How large is too large is not
     fixed: an array is too large when the number of its elements is no
     `int`, or when it exceeds what an array can hold. *)
  val array : int * int * 'a -> 'a array

  (* `fromList rows` is a new array of the lists of `rows`, one row each.

     Raises: `Size` if the lists are not all of one length.

     Example: `let val a = fromList [[1, 2], [3, 4]] in (sub (a, 1, 0),
     dimensions a) end = (3, (2, 2))` *)
  val fromList : 'a list list -> 'a array

  (* `tabulate trv (r, c, f)` is a new array of `r` rows and `c` columns whose element at `(i, j)` is `f (i, j)`.

     `f` is applied in the order that `trv` gives.

     Raises: `Size` if `r < 0`, `c < 0` or the array would be too large,
     before `f` is applied at all.

     Reading: `Array2.tabulate/traversal-order`. "Initialized in traversal
     order" is read as: `f (0, 0)` is applied first whichever traversal is
     asked for, and its result fills the array before the rest is
     computed. *)
  val tabulate : traversal -> int * int * (int * int -> 'a) -> 'a array

  (* ---- Elements ---- *)

  (* `sub (arr, i, j)` is the element of `arr` in row `i` and column `j`.

     Raises: `Subscript` if `i` or `j` is outside the array. *)
  val sub : 'a array * int * int -> 'a

  (* `update (arr, i, j, x)` puts `x` in row `i` and column `j` of `arr`.

     Raises: `Subscript` if `i` or `j` is outside the array. *)
  val update : 'a array * int * int * 'a -> unit

  (* ---- Shape ---- *)

  (* `dimensions arr` is the pair of the number of rows and the number of columns. *)
  val dimensions : 'a array -> int * int

  (* `nCols arr` is the number of columns. *)
  val nCols : 'a array -> int

  (* `nRows arr` is the number of rows. *)
  val nRows : 'a array -> int

  (* `row (arr, i)` is a vector of the elements of row `i`, left to right.

     Raises: `Subscript` if `i` is no row of `arr`.

     Example: `row (fromList [[1, 2], [3, 4]], 1) = Vector.fromList [3, 4]` *)
  val row : 'a array * int -> 'a Vector.vector

  (* `column (arr, j)` is a vector of the elements of column `j`, top to bottom.

     Raises: `Subscript` if `j` is no column of `arr`.

     Example: `column (fromList [[1, 2], [3, 4]], 1) = Vector.fromList [2, 4]` *)
  val column : 'a array * int -> 'a Vector.vector

  (* ---- Copying ---- *)

  (* `copy {src, dst, dst_row, dst_col}` copies the region `src` into `dst`, with its top left corner at `(dst_row, dst_col)`.

     The source and the destination may be one array and may overlap: every
     element arrives as it was before the copy began.

     Raises: `Subscript` if `src` is not a valid region, or if it does not
     fit into `dst` at that corner.

     Reading: `Array2.copy/Subscript-dst-nothing-row-beyond`. The place the
     region is copied to must be inside `dst` even when the region is empty,
     so a corner outside `dst` raises although nothing would be copied. *)
  val copy : {src : 'a region, dst : 'a array, dst_row : int, dst_col : int} -> unit

  (* ---- Traversing ---- *)

  (* `appi trv f reg` applies `f` to the row, the column and the element of each position of the region, in the order `trv` gives.

     Raises: `Subscript` if `reg` is not a valid region.

     Reading: `Array2.appi/nothing-rows-at-the-end`. "0 <= #row reg <=
     nRows" allows a region to begin at the edge of the array: such a region
     and one of no rows or no columns are valid, and traverse nothing. *)
  val appi : traversal -> (int * int * 'a -> unit) -> 'a region -> unit

  (* `app trv f arr` applies `f` to every element of `arr`, in the order `trv` gives, for its effect. *)
  val app : traversal -> ('a -> unit) -> 'a array -> unit

  (* `foldi trv f init reg` combines the elements of the region, giving `f` the row and the column as well.

     Raises: `Subscript` if `reg` is not a valid region. *)
  val foldi : traversal -> (int * int * 'a * 'b -> 'b) -> 'b -> 'a region -> 'b

  (* `fold trv f init arr` combines every element of `arr`, in the order `trv` gives.

     Example: `fold RowMajor (op ::) [] (fromList [[1, 2], [3, 4]]) = [4, 3, 2,
     1]`

     Example: `fold ColMajor (op ::) [] (fromList [[1, 2], [3, 4]]) = [4, 2, 3,
     1]` *)
  val fold : traversal -> ('a * 'b -> 'b) -> 'b -> 'a array -> 'b

  (* `modifyi trv f reg` replaces each element of the region by `f` of its row, its column and that element.

     Raises: `Subscript` if `reg` is not a valid region. *)
  val modifyi : traversal -> (int * int * 'a -> 'a) -> 'a region -> unit

  (* `modify trv f arr` replaces every element of `arr` by `f` of it, in the order `trv` gives. *)
  val modify : traversal -> ('a -> 'a) -> 'a array -> unit
end
