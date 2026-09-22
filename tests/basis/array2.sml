(* requires: Array2 Vector List *)
(* The Array2 structure (signature ARRAY2). Expected values follow the text of
   https://smlfamily.github.io/Basis/array2.html.

   "The elements of 2-dimensional arrays are indexed by pair of integers (i,j)
   where i gives the row index, and [j] gives the column index."

   Arrays are read back as lists of rows with nRows, nCols and sub. The arrays
   of a check are made inside its thunk: a check never sees the updates of
   another one. The coordinates that appi, foldi and modifyi pass are "the
   element's coordinates in the base array", not those in the region. *)
structure TestArray2 =
struct
  structure A = Array2

  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val eqM = T.eq (T.list (T.list T.int))
  val eqD = T.eq (T.pair (T.int, T.int))
  val eqT = T.eq (T.list (T.triple (T.int, T.int, T.int)))

  fun vectorToList (v : 'a vector) : 'a list = List.tabulate (Vector.length v, fn i => Vector.sub (v, i))
  fun rows (a : 'a A.array) : 'a list list =
    List.tabulate (A.nRows a, fn i => List.tabulate (A.nCols a, fn j => A.sub (a, i, j)))

  (* eqA (label, expected, f): the rows of the array f () are expected. *)
  fun eqA (label, expected : int list list, f : unit -> int A.array) : unit =
    eqM (label, expected, fn () => rows (f ()))

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end

  (* counter (): a function that returns 0, 1, 2, ... whatever it is given *)
  fun counter () = let val n = ref 0 in fn _ => !n before n := !n + 1 end

  fun region (a, r, c, nr, nc) : int A.region = {base = a, row = r, col = c, nrows = nr, ncols = nc}
  fun whole a = region (a, 0, 0, NONE, NONE)

  (* 3 rows and 4 columns; the element (i, j) is 10 * i + j *)
  val l34 = [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
  fun m34 () = A.fromList l34
  val l23 = [[1, 2, 3], [4, 5, 6]]
  fun m23 () = A.fromList l23
  (* the region of the rows 1 and 2 and the columns 1 and 2 of a:
     11 12
     21 22 *)
  fun inner a = region (a, 1, 1, SOME 2, SOME 2)
  (* 4 rows and 4 columns; the element (i, j) is 10 * i + j *)
  fun m44 () = A.tabulate A.RowMajor (4, 4, fn (i, j) => 10 * i + j)
  fun zeros (r, c) = A.array (r, c, 0)
  (* The negative index of sub, update, row and column is read from a ref: the
     compiler of Poly/ML 5.7.1 stops with "Overflow unexpectedly raised while
     compiling" on Array2.sub (a, ~1, 0) with the constant index ~1. *)
  val minusOne = ref ~1

  (* ---- RowMajor, ColMajor: "RowMajor indicates that, given a region, the
     rows are traversed from left to right (smallest column index to largest
     column index), starting with the first row in the region, then the
     second, and so on until the last row is traversed. ColMajor reverses the
     roles of row and column, traversing the columns from top down (smallest
     row index to largest row index), starting with the first column, then the
     second, and so on" ---- *)
  val () = eqL ("Array2.RowMajor/rows-from-left-to-right", [1, 2, 3, 4, 5, 6],
                fn () => let val (f, seen) = trace (fn _ => ()) in A.app A.RowMajor f (m23 ()); seen () end)
  val () = eqL ("Array2.ColMajor/columns-from-top-down", [1, 4, 2, 5, 3, 6],
                fn () => let val (f, seen) = trace (fn _ => ()) in A.app A.ColMajor f (m23 ()); seen () end)
  val () = eqL ("Array2.RowMajor/is-a-constructor", [1, 2],
                fn () => List.map (fn A.RowMajor => 1 | A.ColMajor => 2) [A.RowMajor, A.ColMajor])
  val () = eqB ("Array2.ColMajor/is-not-RowMajor", true, fn () => A.RowMajor <> A.ColMajor andalso A.ColMajor = A.ColMajor)

  (* ---- array: "creates a new array with r rows and c columns, with each
     element initialized to the value init. If r < 0, c < 0 or the resulting
     array would be too large, the Size exception is raised." ---- *)
  val () = eqA ("Array2.array/basic", [[7, 7, 7], [7, 7, 7]], fn () => A.array (2, 3, 7))
  val () = eqA ("Array2.array/one", [[7]], fn () => A.array (1, 1, 7))
  val () = eqD ("Array2.array/dimensions", (2, 3), fn () => A.dimensions (A.array (2, 3, 7)))
  val () = eqD ("Array2.array/no-rows", (0, 3), fn () => A.dimensions (A.array (0, 3, 7)))
  val () = eqD ("Array2.array/no-columns", (2, 0), fn () => A.dimensions (A.array (2, 0, 7)))
  val () = eqD ("Array2.array/no-rows-no-columns", (0, 0), fn () => A.dimensions (A.array (0, 0, 7)))
  val () = eqA ("Array2.array/no-columns-rows", [[], []], fn () => A.array (2, 0, 7))
  val () = T.raises ("Array2.array/Size-negative-rows", T.isSize, fn () => A.array (~1, 3, 7))
  val () = T.raises ("Array2.array/Size-negative-columns", T.isSize, fn () => A.array (3, ~1, 7))
  val () = T.raises ("Array2.array/Size-negative-both", T.isSize, fn () => A.array (~1, ~1, 7))
  val () = T.raises ("Array2.array/Size-negative-rows-no-columns", T.isSize, fn () => A.array (~1, 0, 7))
  val () = T.raises ("Array2.array/Size-negative-columns-no-rows", T.isSize, fn () => A.array (0, ~1, 7))
  val () = eqA ("Array2.array/elements-are-separate", [[7, 7, 7], [7, 8, 7]],
                fn () => let val a = A.array (2, 3, 7) in A.update (a, 1, 1, 8); a end)
  val () = eqI ("Array2.array/every-element-is-init", 5,
                fn () => let val a = A.array (2, 2, ref 0) in A.sub (a, 0, 1) := 5; !(A.sub (a, 1, 0)) end)

  (* ---- fromList: "The elements should be presented in row major form, i.e.,
     hd l gives the first row, hd (tl l) gives the second row, etc. This
     raises the Size exception if the resulting array would be too large or if
     the lists in l do not all have the same length." ---- *)
  val () = eqA ("Array2.fromList/basic", l23, fn () => A.fromList l23)
  val () = eqD ("Array2.fromList/dimensions", (2, 3), fn () => A.dimensions (A.fromList l23))
  val () = eqI ("Array2.fromList/second-row-first-column", 4, fn () => A.sub (A.fromList l23, 1, 0))
  val () = eqI ("Array2.fromList/first-row-last-column", 3, fn () => A.sub (A.fromList l23, 0, 2))
  val () = eqD ("Array2.fromList/one-row", (1, 3), fn () => A.dimensions (A.fromList [[1, 2, 3]]))
  val () = eqD ("Array2.fromList/one-column", (3, 1), fn () => A.dimensions (A.fromList [[1], [2], [3]]))
  val () = eqA ("Array2.fromList/one-element", [[7]], fn () => A.fromList [[7]])
  val () = eqD ("Array2.fromList/no-rows", (0, 0), fn () => A.dimensions (A.fromList ([] : int list list)))
  val () = eqD ("Array2.fromList/empty-rows", (3, 0), fn () => A.dimensions (A.fromList ([[], [], []] : int list list)))
  val () = T.eq (T.list (T.list T.string)) ("Array2.fromList/strings", [["a", ""], ["bc", "d"]],
                                            fn () => rows (A.fromList [["a", ""], ["bc", "d"]]))
  val () = T.raises ("Array2.fromList/Size-second-shorter", T.isSize, fn () => A.fromList [[1, 2], [3]])
  val () = T.raises ("Array2.fromList/Size-second-longer", T.isSize, fn () => A.fromList [[1], [2, 3]])
  val () = T.raises ("Array2.fromList/Size-last-shorter", T.isSize, fn () => A.fromList [[1, 2], [3, 4], [5]])
  val () = T.raises ("Array2.fromList/Size-first-empty", T.isSize, fn () => A.fromList [[], [1]])
  val () = T.raises ("Array2.fromList/Size-second-empty", T.isSize, fn () => A.fromList [[1], []])

  (* ---- tabulate: "creates a new array with r rows and c columns, with the
     (i,j)(th) element initialized to f (i,j). The elements are initialized in
     the traversal order specified by trv. If r < 0, c < 0 or the resulting
     array would be too large, the Size exception is raised." ---- *)
  val eqP = T.eq (T.list (T.pair (T.int, T.int)))
  val () = eqA ("Array2.tabulate/RowMajor", [[0, 1, 2], [10, 11, 12]], fn () => A.tabulate A.RowMajor (2, 3, fn (i, j) => 10 * i + j))
  val () = eqA ("Array2.tabulate/ColMajor", [[0, 1, 2], [10, 11, 12]], fn () => A.tabulate A.ColMajor (2, 3, fn (i, j) => 10 * i + j))
  val () = eqD ("Array2.tabulate/dimensions", (2, 3), fn () => A.dimensions (A.tabulate A.ColMajor (2, 3, fn _ => 0)))
  val () = eqP ("Array2.tabulate/RowMajor-order", [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)],
                fn () => let val (f, seen) = trace (fn _ => 0) in ignore (A.tabulate A.RowMajor (2, 3, f)); seen () end)
  val () = eqP ("Array2.tabulate/ColMajor-order", [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2)],
                fn () => let val (f, seen) = trace (fn _ => 0) in ignore (A.tabulate A.ColMajor (2, 3, f)); seen () end)
  val () = eqA ("Array2.tabulate/RowMajor-counter", [[0, 1, 2], [3, 4, 5]], fn () => A.tabulate A.RowMajor (2, 3, counter ()))
  val () = eqA ("Array2.tabulate/ColMajor-counter", [[0, 2, 4], [1, 3, 5]], fn () => A.tabulate A.ColMajor (2, 3, counter ()))
  val () = eqA ("Array2.tabulate/one", [[5]], fn () => A.tabulate A.RowMajor (1, 1, fn _ => 5))
  val () = eqD ("Array2.tabulate/no-rows", (0, 3), fn () => A.dimensions (A.tabulate A.RowMajor (0, 3, fn _ => 0)))
  val () = eqD ("Array2.tabulate/no-columns", (2, 0), fn () => A.dimensions (A.tabulate A.ColMajor (2, 0, fn _ => 0)))
  val () = eqP ("Array2.tabulate/no-elements-no-f", [],
                fn () => let val (f, seen) = trace (fn _ => 0)
                         in ignore (A.tabulate A.RowMajor (0, 3, f)); ignore (A.tabulate A.ColMajor (2, 0, f)); seen () end)
  val () = T.raises ("Array2.tabulate/Size-negative-rows", T.isSize, fn () => A.tabulate A.RowMajor (~1, 3, fn _ => 0))
  val () = T.raises ("Array2.tabulate/Size-negative-columns", T.isSize, fn () => A.tabulate A.RowMajor (3, ~1, fn _ => 0))
  val () = T.raises ("Array2.tabulate/Size-negative-ColMajor", T.isSize, fn () => A.tabulate A.ColMajor (3, ~1, fn _ => 0))
  val () = eqP ("Array2.tabulate/Size-before-f", [],
                fn () => let val (f, seen) = trace (fn _ => 0)
                         in ignore (A.tabulate A.RowMajor (3, ~1, f)) handle Size => ();
                            ignore (A.tabulate A.ColMajor (~1, 3, f)) handle Size => ();
                            seen ()
                         end)

  (* ---- sub: "returns the (i,j)(th) element of the array arr. If i < 0,
     j < 0, nRows arr <= i, or nCols arr <= j, then the Subscript exception is
     raised." ---- *)
  val () = eqI ("Array2.sub/first", 0, fn () => A.sub (m34 (), 0, 0))
  val () = eqI ("Array2.sub/end-of-first-row", 3, fn () => A.sub (m34 (), 0, 3))
  val () = eqI ("Array2.sub/start-of-last-row", 20, fn () => A.sub (m34 (), 2, 0))
  val () = eqI ("Array2.sub/middle", 12, fn () => A.sub (m34 (), 1, 2))
  val () = eqI ("Array2.sub/last", 23, fn () => A.sub (m34 (), 2, 3))
  val () = T.raises ("Array2.sub/Subscript-row-nRows", T.isSubscript, fn () => A.sub (m34 (), 3, 0))
  val () = T.raises ("Array2.sub/Subscript-column-nCols", T.isSubscript, fn () => A.sub (m34 (), 0, 4))
  val () = T.raises ("Array2.sub/Subscript-column-nCols-last-row", T.isSubscript, fn () => A.sub (m34 (), 2, 4))
  val () = T.raises ("Array2.sub/Subscript-negative-row", T.isSubscript, fn () => A.sub (m34 (), !minusOne, 0))
  val () = T.raises ("Array2.sub/Subscript-negative-column", T.isSubscript, fn () => A.sub (m34 (), 1, !minusOne))
  val () = T.raises ("Array2.sub/Subscript-negative-row-column-beyond", T.isSubscript, fn () => A.sub (m34 (), !minusOne, 5))
  val () = T.raises ("Array2.sub/Subscript-column-is-a-row-index", T.isSubscript, fn () => A.sub (A.fromList [[1, 2], [3, 4], [5, 6]], 1, 2))
  val () = T.raises ("Array2.sub/Subscript-row-is-a-column-index", T.isSubscript, fn () => A.sub (m23 (), 2, 1))
  val () = T.raises ("Array2.sub/Subscript-no-rows", T.isSubscript, fn () => A.sub (zeros (0, 3), 0, 0))
  val () = T.raises ("Array2.sub/Subscript-no-columns", T.isSubscript, fn () => A.sub (zeros (3, 0), 0, 0))

  (* ---- update: "sets the (i,j)(th) element of the array arr to a. If i < 0,
     j < 0, nRows arr <= i, or nCols arr <= j, then the Subscript exception is
     raised." ---- *)
  val () = eqA ("Array2.update/first", [[9, 2, 3], [4, 5, 6]], fn () => let val a = m23 () in A.update (a, 0, 0, 9); a end)
  val () = eqA ("Array2.update/end-of-first-row", [[1, 2, 9], [4, 5, 6]], fn () => let val a = m23 () in A.update (a, 0, 2, 9); a end)
  val () = eqA ("Array2.update/start-of-last-row", [[1, 2, 3], [9, 5, 6]], fn () => let val a = m23 () in A.update (a, 1, 0, 9); a end)
  val () = eqA ("Array2.update/last", [[1, 2, 3], [4, 5, 9]], fn () => let val a = m23 () in A.update (a, 1, 2, 9); a end)
  val () = eqA ("Array2.update/twice-same-element", [[1, 2, 3], [4, 7, 6]],
                fn () => let val a = m23 () in A.update (a, 1, 1, 9); A.update (a, 1, 1, 7); a end)
  val () = eqI ("Array2.update/seen-through-alias", 9,
                fn () => let val a = m23 () val b = a in A.update (b, 1, 1, 9); A.sub (a, 1, 1) end)
  val () = T.raises ("Array2.update/Subscript-row-nRows", T.isSubscript, fn () => A.update (m23 (), 2, 0, 9))
  val () = T.raises ("Array2.update/Subscript-column-nCols", T.isSubscript, fn () => A.update (m23 (), 0, 3, 9))
  val () = T.raises ("Array2.update/Subscript-negative-row", T.isSubscript, fn () => A.update (m23 (), !minusOne, 0, 9))
  val () = T.raises ("Array2.update/Subscript-negative-column", T.isSubscript, fn () => A.update (m23 (), 1, !minusOne, 9))
  val () = T.raises ("Array2.update/Subscript-no-rows", T.isSubscript, fn () => A.update (zeros (0, 3), 0, 0, 9))
  val () = T.raises ("Array2.update/Subscript-no-columns", T.isSubscript, fn () => A.update (zeros (3, 0), 0, 0, 9))
  val () = eqA ("Array2.update/Subscript-changes-nothing", l23,
                fn () => let val a = m23 ()
                         in A.update (a, 0, 3, 9) handle Subscript => ();
                            A.update (a, 1, !minusOne, 9) handle Subscript => ();
                            A.update (a, 2, 0, 9) handle Subscript => ();
                            a
                         end)

  (* ---- dimensions, nCols, nRows: "nCols returns the number of columns, nRows
     returns the number of rows, and dimension returns a pair containing the
     number of rows and the number of columns of the array. The functions
     nRows and nCols are respectively equivalent to #1 o dimensions and
     #2 o dimensions" ---- *)
  val () = eqD ("Array2.dimensions/rows-then-columns", (3, 4), fn () => A.dimensions (m34 ()))
  val () = eqD ("Array2.dimensions/one-row", (1, 3), fn () => A.dimensions (zeros (1, 3)))
  val () = eqI ("Array2.nRows/basic", 3, fn () => A.nRows (m34 ()))
  val () = eqI ("Array2.nCols/basic", 4, fn () => A.nCols (m34 ()))
  val () = eqI ("Array2.nRows/no-rows", 0, fn () => A.nRows (zeros (0, 3)))
  val () = eqI ("Array2.nCols/no-rows", 3, fn () => A.nCols (zeros (0, 3)))
  val () = eqI ("Array2.nRows/no-columns", 3, fn () => A.nRows (zeros (3, 0)))
  val () = eqI ("Array2.nCols/no-columns", 0, fn () => A.nCols (zeros (3, 0)))
  val () = eqB ("Array2.nRows/is-first-of-dimensions", true, fn () => let val a = m34 () in A.nRows a = #1 (A.dimensions a) end)
  val () = eqB ("Array2.nCols/is-second-of-dimensions", true, fn () => let val a = m34 () in A.nCols a = #2 (A.dimensions a) end)

  (* ---- row: "returns row i of arr. If (nRows arr) <= i or i < 0, this raises
     Subscript." ---- *)
  val () = eqL ("Array2.row/first", [0, 1, 2, 3], fn () => vectorToList (A.row (m34 (), 0)))
  val () = eqL ("Array2.row/middle", [10, 11, 12, 13], fn () => vectorToList (A.row (m34 (), 1)))
  val () = eqL ("Array2.row/last", [20, 21, 22, 23], fn () => vectorToList (A.row (m34 (), 2)))
  val () = eqL ("Array2.row/no-columns", [], fn () => vectorToList (A.row (zeros (3, 0), 2)))
  val () = eqL ("Array2.row/is-a-snapshot", [10, 11, 12, 13],
                fn () => let val a = m34 () val v = A.row (a, 1) in A.update (a, 1, 1, 99); vectorToList v end)
  val () = T.raises ("Array2.row/Subscript-nRows", T.isSubscript, fn () => A.row (m34 (), 3))
  val () = T.raises ("Array2.row/Subscript-is-a-column-index", T.isSubscript, fn () => A.row (m23 (), 2))
  val () = T.raises ("Array2.row/Subscript-negative", T.isSubscript, fn () => A.row (m34 (), !minusOne))
  val () = T.raises ("Array2.row/Subscript-no-rows", T.isSubscript, fn () => A.row (zeros (0, 3), 0))

  (* ---- column: "returns column j of arr. This raises Subscript if j < 0 or
     nCols arr <= j." ---- *)
  val () = eqL ("Array2.column/first", [0, 10, 20], fn () => vectorToList (A.column (m34 (), 0)))
  val () = eqL ("Array2.column/middle", [2, 12, 22], fn () => vectorToList (A.column (m34 (), 2)))
  val () = eqL ("Array2.column/last", [3, 13, 23], fn () => vectorToList (A.column (m34 (), 3)))
  val () = eqL ("Array2.column/no-rows", [], fn () => vectorToList (A.column (zeros (0, 3), 2)))
  val () = eqL ("Array2.column/is-a-snapshot", [1, 11, 21],
                fn () => let val a = m34 () val v = A.column (a, 1) in A.update (a, 1, 1, 99); vectorToList v end)
  val () = T.raises ("Array2.column/Subscript-nCols", T.isSubscript, fn () => A.column (m34 (), 4))
  val () = T.raises ("Array2.column/Subscript-is-a-row-index", T.isSubscript, fn () => A.column (A.fromList [[1, 2], [3, 4], [5, 6]], 2))
  val () = T.raises ("Array2.column/Subscript-negative", T.isSubscript, fn () => A.column (m34 (), !minusOne))
  val () = T.raises ("Array2.column/Subscript-no-columns", T.isSubscript, fn () => A.column (zeros (3, 0), 0))

  (* ---- regions: "reg is valid if 0 <= #row reg <= nRows (#base reg) when
     #nrows reg = NONE, or 0 <= #row reg <= (#row reg)+nr <= nRows (#base reg)
     when #nrows reg = SOME(nr), and the analogous conditions hold for
     columns." The regions below are for an array of 3 rows and 4 columns. ---- *)
  val invalid : (string * (int A.array -> int A.region)) list =
    [("negative-row", fn a => region (a, ~1, 0, NONE, NONE)),
     ("negative-col", fn a => region (a, 0, ~1, NONE, NONE)),
     ("negative-row-SOME", fn a => region (a, ~1, 0, SOME 1, NONE)),
     ("negative-col-SOME", fn a => region (a, 0, ~1, NONE, SOME 1)),
     ("row-beyond", fn a => region (a, 4, 0, NONE, NONE)),
     ("col-beyond", fn a => region (a, 0, 5, NONE, NONE)),
     ("row-beyond-zero-nrows", fn a => region (a, 4, 0, SOME 0, NONE)),
     ("col-beyond-zero-ncols", fn a => region (a, 0, 5, NONE, SOME 0)),
     ("row-beyond-no-cols", fn a => region (a, 4, 4, NONE, NONE)),
     ("col-beyond-no-rows", fn a => region (a, 3, 5, NONE, NONE)),
     ("negative-nrows", fn a => region (a, 1, 0, SOME ~1, NONE)),
     ("negative-ncols", fn a => region (a, 0, 1, NONE, SOME ~1)),
     ("too-many-rows", fn a => region (a, 2, 0, SOME 2, NONE)),
     ("too-many-cols", fn a => region (a, 0, 3, NONE, SOME 2)),
     ("all-rows-and-one", fn a => region (a, 0, 0, SOME 4, NONE)),
     ("all-cols-and-one", fn a => region (a, 0, 0, NONE, SOME 5)),
     ("one-row-at-the-end", fn a => region (a, 3, 0, SOME 1, NONE)),
     ("one-col-at-the-end", fn a => region (a, 0, 4, NONE, SOME 1))]

  (* ---- copy: "copies the region src into the array dst, with the element at
     position (#row src, #col src) copied into the destination array at
     position (dst_row,dst_col). If the source region is not valid, then the
     Subscript exception is raised. Similarly, if the derived destination
     region (the source region src translated to (dst_row,dst_col)) is not
     valid in dst, then the Subscript exception is raised." ---- *)
  fun copyTo (src, dims, r, c) = let val d = zeros dims in A.copy {src = src, dst = d, dst_row = r, dst_col = c}; d end
  val () = eqA ("Array2.copy/region", [[0, 0, 0, 0, 0], [0, 0, 11, 12, 0], [0, 0, 21, 22, 0], [0, 0, 0, 0, 0]],
                fn () => copyTo (inner (m34 ()), (4, 5), 1, 2))
  val () = eqA ("Array2.copy/to-the-first-corner", [[11, 12, 0, 0, 0], [21, 22, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]],
                fn () => copyTo (inner (m34 ()), (4, 5), 0, 0))
  val () = eqA ("Array2.copy/to-the-last-corner", [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 11, 12], [0, 0, 0, 21, 22]],
                fn () => copyTo (inner (m34 ()), (4, 5), 2, 3))
  val () = eqA ("Array2.copy/whole-NONE", [[0, 0, 0, 0, 0], [0, 0, 1, 2, 3], [0, 10, 11, 12, 13], [0, 20, 21, 22, 23]],
                fn () => copyTo (whole (m34 ()), (4, 5), 1, 1))
  val () = eqA ("Array2.copy/whole-same-dimensions", l34, fn () => copyTo (whole (m34 ()), (3, 4), 0, 0))
  val () = eqA ("Array2.copy/NONE-rows-SOME-cols", [[0, 0, 0], [11, 12, 0], [21, 22, 0]],
                fn () => copyTo (region (m34 (), 1, 1, NONE, SOME 2), (3, 3), 1, 0))
  val () = eqA ("Array2.copy/SOME-rows-NONE-cols", [[0, 0, 0], [12, 13, 0]],
                fn () => copyTo (region (m34 (), 1, 2, SOME 1, NONE), (2, 3), 1, 0))
  val () = eqA ("Array2.copy/field-order", [[0, 0, 0], [0, 11, 12], [0, 21, 22]],
                fn () => let val d = zeros (3, 3) val a = m34 ()
                         in A.copy {dst_col = 1, dst_row = 1, dst = d, src = {ncols = SOME 2, nrows = SOME 2, col = 1, row = 1, base = a}}; d end)
  val () = eqA ("Array2.copy/src-unchanged", l34, fn () => let val a = m34 () in ignore (copyTo (inner a, (4, 5), 1, 2)); a end)
  val () = eqA ("Array2.copy/copies-elements-not-the-array", [[11, 12], [21, 22]],
                fn () => let val a = m34 () val d = copyTo (inner a, (2, 2), 0, 0) in A.update (a, 1, 1, 99); d end)
  val () = List.app (fn (name, reg) =>
             T.raises ("Array2.copy/Subscript-src-" ^ name, T.isSubscript, fn () => copyTo (reg (m34 ()), (8, 8), 0, 0))) invalid
  val () = T.raises ("Array2.copy/Subscript-dst-negative-row", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), ~1, 0))
  val () = T.raises ("Array2.copy/Subscript-dst-negative-col", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, ~1))
  val () = T.raises ("Array2.copy/Subscript-dst-one-row-too-far", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 3, 0))
  val () = T.raises ("Array2.copy/Subscript-dst-one-col-too-far", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, 4))
  val () = T.raises ("Array2.copy/Subscript-dst-row-nRows", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 4, 0))
  val () = T.raises ("Array2.copy/Subscript-dst-col-nCols", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, 5))
  val () = T.raises ("Array2.copy/Subscript-dst-smaller", T.isSubscript, fn () => copyTo (whole (m34 ()), (3, 3), 0, 0))
  val () = T.raises ("Array2.copy/Subscript-dst-no-rows", T.isSubscript, fn () => copyTo (inner (m34 ()), (0, 5), 0, 0))
  (* The page does not say what is left in dst when Subscript is raised; the
     test takes it that nothing is copied, as the conditions are on the
     arguments alone. *)
  val () = eqA ("Array2.copy/Subscript-changes-nothing", [[0, 0, 0], [0, 0, 0], [0, 0, 0]],
                fn () => let val d = zeros (3, 3)
                         in A.copy {src = inner (m34 ()), dst = d, dst_row = 2, dst_col = 0} handle Subscript => ();
                            A.copy {src = inner (m34 ()), dst = d, dst_row = 0, dst_col = 2} handle Subscript => ();
                            d
                         end)
  (* "The copy function must correctly handle the case in which the #base src
     and the dst arrays are equal, and the source and destination regions
     overlap": the elements arrive as they were before the copy, whichever way
     they move. *)
  fun within (r, c, nr, nc, dr, dc) =
    let val a = m44 () in A.copy {src = region (a, r, c, nr, nc), dst = a, dst_row = dr, dst_col = dc}; a end
  val () = eqA ("Array2.copy/overlap-down-right", [[0, 1, 2, 3], [10, 0, 1, 2], [20, 10, 11, 12], [30, 20, 21, 22]],
                fn () => within (0, 0, SOME 3, SOME 3, 1, 1))
  val () = eqA ("Array2.copy/overlap-up-left", [[11, 12, 13, 3], [21, 22, 23, 13], [31, 32, 33, 23], [30, 31, 32, 33]],
                fn () => within (1, 1, NONE, NONE, 0, 0))
  val () = eqA ("Array2.copy/overlap-down-left", [[0, 1, 2, 3], [1, 2, 3, 13], [11, 12, 13, 23], [21, 22, 23, 33]],
                fn () => within (0, 1, SOME 3, NONE, 1, 0))
  val () = eqA ("Array2.copy/overlap-up-right", [[0, 10, 11, 12], [10, 20, 21, 22], [20, 30, 31, 32], [30, 31, 32, 33]],
                fn () => within (1, 0, NONE, SOME 3, 0, 1))
  val () = eqA ("Array2.copy/overlap-right", [[0, 0, 1, 2], [10, 10, 11, 12], [20, 20, 21, 22], [30, 30, 31, 32]],
                fn () => within (0, 0, NONE, SOME 3, 0, 1))
  val () = eqA ("Array2.copy/overlap-left", [[1, 2, 3, 3], [11, 12, 13, 13], [21, 22, 23, 23], [31, 32, 33, 33]],
                fn () => within (0, 1, NONE, NONE, 0, 0))
  val () = eqA ("Array2.copy/overlap-down", [[0, 1, 2, 3], [0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]],
                fn () => within (0, 0, SOME 3, NONE, 1, 0))
  val () = eqA ("Array2.copy/overlap-up", [[10, 11, 12, 13], [20, 21, 22, 23], [30, 31, 32, 33], [30, 31, 32, 33]],
                fn () => within (1, 0, NONE, NONE, 0, 0))
  val () = eqA ("Array2.copy/overlap-onto-itself", [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23], [30, 31, 32, 33]],
                fn () => within (0, 0, NONE, NONE, 0, 0))
  val () = eqA ("Array2.copy/same-array-apart", [[0, 1, 0, 1], [10, 11, 10, 11], [20, 21, 22, 23], [30, 31, 32, 33]],
                fn () => within (0, 0, SOME 2, SOME 2, 0, 2))
  val () = T.raises ("Array2.copy/overlap-Subscript", T.isSubscript, fn () => within (0, 0, NONE, NONE, 0, 1))

  (* ---- appi, app: "apply the function f to the elements of an array in the
     order specified by tr. The more general appi function applies f to the
     elements of the region reg and supplies both the element and the
     element's coordinates in the base array to the function f. If reg is not
     valid, then the exception Subscript is raised." ---- *)
  fun appi tr reg = let val (f, seen) = trace (fn _ => ()) in A.appi tr f reg; seen () end
  val () = eqT ("Array2.appi/whole-RowMajor", [(0, 0, 1), (0, 1, 2), (0, 2, 3), (1, 0, 4), (1, 1, 5), (1, 2, 6)],
                fn () => appi A.RowMajor (whole (m23 ())))
  val () = eqT ("Array2.appi/whole-ColMajor", [(0, 0, 1), (1, 0, 4), (0, 1, 2), (1, 1, 5), (0, 2, 3), (1, 2, 6)],
                fn () => appi A.ColMajor (whole (m23 ())))
  val () = eqT ("Array2.appi/region-RowMajor", [(1, 1, 11), (1, 2, 12), (2, 1, 21), (2, 2, 22)], fn () => appi A.RowMajor (inner (m34 ())))
  val () = eqT ("Array2.appi/region-ColMajor", [(1, 1, 11), (2, 1, 21), (1, 2, 12), (2, 2, 22)], fn () => appi A.ColMajor (inner (m34 ())))
  val () = eqT ("Array2.appi/NONE-to-the-end-RowMajor", [(1, 2, 12), (1, 3, 13), (2, 2, 22), (2, 3, 23)],
                fn () => appi A.RowMajor (region (m34 (), 1, 2, NONE, NONE)))
  val () = eqT ("Array2.appi/NONE-to-the-end-ColMajor", [(1, 2, 12), (2, 2, 22), (1, 3, 13), (2, 3, 23)],
                fn () => appi A.ColMajor (region (m34 (), 1, 2, NONE, NONE)))
  val () = eqT ("Array2.appi/one-row", [(2, 0, 20), (2, 1, 21), (2, 2, 22)], fn () => appi A.ColMajor (region (m34 (), 2, 0, SOME 1, SOME 3)))
  val () = eqT ("Array2.appi/one-column", [(0, 3, 3), (1, 3, 13), (2, 3, 23)], fn () => appi A.RowMajor (region (m34 (), 0, 3, NONE, SOME 1)))
  val () = eqT ("Array2.appi/last-element", [(2, 3, 23)], fn () => appi A.RowMajor (region (m34 (), 2, 3, NONE, NONE)))
  val () = List.app (fn (name, reg) =>
             T.raises ("Array2.appi/Subscript-" ^ name, T.isSubscript, fn () => A.appi A.RowMajor (fn _ => ()) (reg (m34 ())))) invalid
  val () = T.raises ("Array2.appi/Subscript-ColMajor-too-many-rows", T.isSubscript,
                     fn () => A.appi A.ColMajor (fn _ => ()) (region (m34 (), 2, 0, SOME 2, NONE)))
  val () = T.raises ("Array2.appi/Subscript-ColMajor-too-many-cols", T.isSubscript,
                     fn () => A.appi A.ColMajor (fn _ => ()) (region (m34 (), 0, 3, NONE, SOME 2)))
  val () = eqL ("Array2.app/RowMajor", [0, 1, 2, 3, 10, 11, 12, 13, 20, 21, 22, 23],
                fn () => let val (f, seen) = trace (fn _ => ()) in A.app A.RowMajor f (m34 ()); seen () end)
  val () = eqL ("Array2.app/ColMajor", [0, 10, 20, 1, 11, 21, 2, 12, 22, 3, 13, 23],
                fn () => let val (f, seen) = trace (fn _ => ()) in A.app A.ColMajor f (m34 ()); seen () end)
  val () = eqL ("Array2.app/no-rows", [], fn () => let val (f, seen) = trace (fn _ => ()) in A.app A.RowMajor f (zeros (0, 3)); seen () end)
  val () = eqL ("Array2.app/no-columns", [], fn () => let val (f, seen) = trace (fn _ => ()) in A.app A.ColMajor f (zeros (3, 0)); seen () end)
  val () = eqA ("Array2.app/array-unchanged", l34, fn () => let val a = m34 () in A.app A.RowMajor (fn _ => ()) a; a end)

  (* ---- foldi, fold: "fold the function f over the elements of an array arr,
     traversing the elements in tr order, and using the value init as the
     initial value. The more general foldi function applies f to the elements
     of the region reg and supplies both the element and the element's
     coordinates in the base array to the function f. If reg is not valid,
     then the exception Subscript is raised."
     With f (a, b) = a - 2 * b over the region 11 12 / 21 22:
       RowMajor: 11-0 = 11, 12-22 = ~10, 21+20 = 41, 22-82 = ~60;
       ColMajor: 11-0 = 11, 21-22 = ~1, 12+2 = 14, 22-28 = ~6.
     Over the array 1 2 / 3 4:
       RowMajor: 1-0 = 1, 2-2 = 0, 3-0 = 3, 4-6 = ~2;
       ColMajor: 1-0 = 1, 3-2 = 1, 2-2 = 0, 4-0 = 4. ---- *)
  val cons = fn (i, j, a, l) => (i, j, a) :: l
  val () = eqT ("Array2.foldi/whole-RowMajor-conses-reversed", [(1, 2, 6), (1, 1, 5), (1, 0, 4), (0, 2, 3), (0, 1, 2), (0, 0, 1)],
                fn () => A.foldi A.RowMajor cons [] (whole (m23 ())))
  val () = eqT ("Array2.foldi/whole-ColMajor-conses-reversed", [(1, 2, 6), (0, 2, 3), (1, 1, 5), (0, 1, 2), (1, 0, 4), (0, 0, 1)],
                fn () => A.foldi A.ColMajor cons [] (whole (m23 ())))
  val () = eqT ("Array2.foldi/region-RowMajor", [(2, 2, 22), (2, 1, 21), (1, 2, 12), (1, 1, 11)],
                fn () => A.foldi A.RowMajor cons [] (inner (m34 ())))
  val () = eqT ("Array2.foldi/region-ColMajor", [(2, 2, 22), (1, 2, 12), (2, 1, 21), (1, 1, 11)],
                fn () => A.foldi A.ColMajor cons [] (inner (m34 ())))
  val () = eqI ("Array2.foldi/nonassociative-RowMajor", ~60, fn () => A.foldi A.RowMajor (fn (_, _, a, b) => a - 2 * b) 0 (inner (m34 ())))
  val () = eqI ("Array2.foldi/nonassociative-ColMajor", ~6, fn () => A.foldi A.ColMajor (fn (_, _, a, b) => a - 2 * b) 0 (inner (m34 ())))
  val () = eqT ("Array2.foldi/NONE-to-the-end", [(2, 3, 23), (2, 2, 22), (1, 3, 13), (1, 2, 12)],
                fn () => A.foldi A.RowMajor cons [] (region (m34 (), 1, 2, NONE, NONE)))
  val () = List.app (fn (name, reg) =>
             T.raises ("Array2.foldi/Subscript-" ^ name, T.isSubscript,
                       fn () => A.foldi A.RowMajor (fn (_, _, _, b) => b) 0 (reg (m34 ())))) invalid
  val () = T.raises ("Array2.foldi/Subscript-ColMajor-too-many-rows", T.isSubscript,
                     fn () => A.foldi A.ColMajor (fn (_, _, _, b) => b) 0 (region (m34 (), 2, 0, SOME 2, NONE)))
  val () = T.raises ("Array2.foldi/Subscript-ColMajor-too-many-cols", T.isSubscript,
                     fn () => A.foldi A.ColMajor (fn (_, _, _, b) => b) 0 (region (m34 (), 0, 3, NONE, SOME 2)))
  val () = eqL ("Array2.fold/RowMajor-conses-reversed", [6, 5, 4, 3, 2, 1], fn () => A.fold A.RowMajor (op ::) [] (m23 ()))
  val () = eqL ("Array2.fold/ColMajor-conses-reversed", [6, 3, 5, 2, 4, 1], fn () => A.fold A.ColMajor (op ::) [] (m23 ()))
  val () = eqI ("Array2.fold/nonassociative-RowMajor", ~2, fn () => A.fold A.RowMajor (fn (a, b) => a - 2 * b) 0 (A.fromList [[1, 2], [3, 4]]))
  val () = eqI ("Array2.fold/nonassociative-ColMajor", 4, fn () => A.fold A.ColMajor (fn (a, b) => a - 2 * b) 0 (A.fromList [[1, 2], [3, 4]]))
  val () = eqI ("Array2.fold/no-rows", 42, fn () => A.fold A.RowMajor (op +) 42 (zeros (0, 3)))
  val () = eqI ("Array2.fold/no-columns", 42, fn () => A.fold A.ColMajor (op +) 42 (zeros (3, 0)))

  (* ---- modifyi, modify: "apply the function f to the elements of an array in
     the order specified by tr, and replace each element with the result of f.
     The more general modifyi function applies f to the elements of the region
     reg and supplies both the element and the element's coordinates in the
     base array to the function f. If reg is not valid, then the exception
     Subscript is raised." ---- *)
  val () = eqA ("Array2.modifyi/region", [[0, 1, 2, 3], [10, 1111, 1212, 13], [20, 2121, 2222, 23]],
                fn () => let val a = m34 () in A.modifyi A.RowMajor (fn (i, j, x) => 1000 * i + 100 * j + x) (inner a); a end)
  val () = eqA ("Array2.modifyi/region-ColMajor", [[0, 1, 2, 3], [10, 1111, 1212, 13], [20, 2121, 2222, 23]],
                fn () => let val a = m34 () in A.modifyi A.ColMajor (fn (i, j, x) => 1000 * i + 100 * j + x) (inner a); a end)
  val () = eqA ("Array2.modifyi/whole", [[101, 202, 303], [1104, 1205, 1306]],
                fn () => let val a = m23 () in A.modifyi A.RowMajor (fn (i, j, x) => 1000 * i + 100 * (j + 1) + x) (whole a); a end)
  val () = eqA ("Array2.modifyi/NONE-to-the-end", [[0, 1, 2, 3], [10, 11, ~12, ~13], [20, 21, ~22, ~23]],
                fn () => let val a = m34 () in A.modifyi A.RowMajor (fn (_, _, x) => ~x) (region (a, 1, 2, NONE, NONE)); a end)
  val () = eqT ("Array2.modifyi/order-RowMajor", [(1, 1, 11), (1, 2, 12), (2, 1, 21), (2, 2, 22)],
                fn () => let val (f, seen) = trace (fn (_, _, x) => x + 1) in A.modifyi A.RowMajor f (inner (m34 ())); seen () end)
  val () = eqT ("Array2.modifyi/order-ColMajor", [(1, 1, 11), (2, 1, 21), (1, 2, 12), (2, 2, 22)],
                fn () => let val (f, seen) = trace (fn (_, _, x) => x + 1) in A.modifyi A.ColMajor f (inner (m34 ())); seen () end)
  val () = eqA ("Array2.modifyi/RowMajor-counter", [[0, 1, 2], [3, 4, 5]],
                fn () => let val a = m23 () in A.modifyi A.RowMajor (counter ()) (whole a); a end)
  val () = eqA ("Array2.modifyi/ColMajor-counter", [[0, 2, 4], [1, 3, 5]],
                fn () => let val a = m23 () in A.modifyi A.ColMajor (counter ()) (whole a); a end)
  val () = List.app (fn (name, reg) =>
             T.raises ("Array2.modifyi/Subscript-" ^ name, T.isSubscript, fn () => A.modifyi A.RowMajor (fn _ => 99) (reg (m34 ())))) invalid
  val () = T.raises ("Array2.modifyi/Subscript-ColMajor-too-many-rows", T.isSubscript,
                     fn () => A.modifyi A.ColMajor (fn _ => 99) (region (m34 (), 2, 0, SOME 2, NONE)))
  val () = T.raises ("Array2.modifyi/Subscript-ColMajor-too-many-cols", T.isSubscript,
                     fn () => A.modifyi A.ColMajor (fn _ => 99) (region (m34 (), 0, 3, NONE, SOME 2)))
  val () = eqA ("Array2.modify/RowMajor", [[2, 4, 6], [8, 10, 12]], fn () => let val a = m23 () in A.modify A.RowMajor (fn x => 2 * x) a; a end)
  val () = eqA ("Array2.modify/ColMajor", [[2, 4, 6], [8, 10, 12]], fn () => let val a = m23 () in A.modify A.ColMajor (fn x => 2 * x) a; a end)
  val () = eqL ("Array2.modify/order-RowMajor", [1, 2, 3, 4, 5, 6],
                fn () => let val (f, seen) = trace (fn x => x + 1) in A.modify A.RowMajor f (m23 ()); seen () end)
  val () = eqL ("Array2.modify/order-ColMajor", [1, 4, 2, 5, 3, 6],
                fn () => let val (f, seen) = trace (fn x => x + 1) in A.modify A.ColMajor f (m23 ()); seen () end)
  val () = eqA ("Array2.modify/ColMajor-counter", [[0, 2, 4], [1, 3, 5]], fn () => let val a = m23 () in A.modify A.ColMajor (counter ()) a; a end)
  val () = eqD ("Array2.modify/no-rows", (0, 3), fn () => let val a = zeros (0, 3) in A.modify A.RowMajor (fn x => x + 1) a; A.dimensions a end)
  val () = eqA ("Array2.modify/twice", [[4, 8, 12], [16, 20, 24]],
                fn () => let val a = m23 () in A.modify A.RowMajor (fn x => 2 * x) a; A.modify A.ColMajor (fn x => 2 * x) a; a end)

  (* The page does not say whether f is applied to some elements before
     Subscript is raised for a region that is not valid; the test takes it that
     it is not, as the condition is on the region alone. *)
  val () = eqT ("Array2.appi/Subscript-before-f", [],
                fn () => let val (f, seen) = trace (fn _ => ())
                         in A.appi A.RowMajor f (region (m34 (), 2, 0, SOME 2, NONE)) handle Subscript => ();
                            A.appi A.ColMajor f (region (m34 (), 0, 3, NONE, SOME 2)) handle Subscript => ();
                            seen ()
                         end)
  val () = eqT ("Array2.foldi/Subscript-before-f", [],
                fn () => let val (f, seen) = trace (fn _ => ())
                         in A.foldi A.RowMajor (fn (i, j, a, ()) => f (i, j, a)) () (region (m34 (), 2, 0, SOME 2, NONE)) handle Subscript => ();
                            A.foldi A.ColMajor (fn (i, j, a, ()) => f (i, j, a)) () (region (m34 (), 0, 3, NONE, SOME 2)) handle Subscript => ();
                            seen ()
                         end)
  val () = eqA ("Array2.modifyi/Subscript-changes-nothing", l34,
                fn () => let val a = m34 ()
                         in A.modifyi A.RowMajor (fn _ => 99) (region (a, 2, 0, SOME 2, NONE)) handle Subscript => ();
                            A.modifyi A.ColMajor (fn _ => 99) (region (a, 0, 3, NONE, SOME 2)) handle Subscript => ();
                            a
                         end)

  (* ---- array: "two arrays are equal if they are the same array, i.e.,
     created by the same call to a primitive array constructor such as array,
     fromList, etc.; otherwise they are not equal. This also holds for arrays
     of zero length. Thus, the type ty array admits equality even if ty does
     not." ---- *)
  val () = eqB ("Array2.array/same-array-is-equal", true, fn () => let val a = m23 () in a = a end)
  val () = eqB ("Array2.array/alias-is-equal", true, fn () => let val a = m23 () val b = a in a = b end)
  val () = eqB ("Array2.array/equal-after-update", true, fn () => let val a = m23 () val b = a in A.update (a, 0, 0, 9); a = b end)
  val () = eqB ("Array2.array/same-elements-not-equal", false, fn () => A.array (2, 3, 7) = A.array (2, 3, 7))
  val () = eqB ("Array2.fromList/same-elements-not-equal", false, fn () => m23 () = m23 ())
  val () = eqB ("Array2.tabulate/same-elements-not-equal", false,
                fn () => A.tabulate A.RowMajor (2, 2, fn _ => 0) = A.tabulate A.RowMajor (2, 2, fn _ => 0))
  val () = eqB ("Array2.array/zero-length-same", true, fn () => let val a = zeros (0, 0) in a = a end)
  val () = eqB ("Array2.array/zero-length-not-equal", false, fn () => zeros (0, 0) = zeros (0, 0))
  val () = eqB ("Array2.fromList/zero-length-not-equal", false,
                fn () => A.fromList ([] : int list list) = A.fromList ([] : int list list))
  (* "the type ty array admits equality even if ty does not" cannot hold of a
     sealed structure (ARRAY2/sealed-and-equal-at-any-element); an array of a
     type that admits equality has one, and the elements are not looked at *)
  val () = eqB ("Array2.array/same-array-equal", true, fn () => let val a = zeros (2, 2) in a = a end)
  val () = eqB ("Array2.array/updated-still-equal", true,
                fn () => let val a = zeros (2, 2) in A.update (a, 0, 0, 1); a = a end)

  (* ---- laws, on pseudo-random arrays and regions, against lists of rows ---- *)
  fun el (m : int list list) (i, j) = List.nth (List.nth (m, i), j)
  fun randomRows (r, c) = List.tabulate (r, fn _ => List.tabulate (c, fn _ => T.range (~50, 50)))
  (* an array of r rows and c columns of the elements m (fromList cannot say c when r = 0) *)
  fun make (r, c, m) = A.tabulate A.RowMajor (r, c, el m)
  (* span (n, start, size): the first index and the number of indices of the
     rows, or columns, of a region in an array of n of them; NONE when the
     region is not valid. (The numbers are small: start + k exists.) *)
  fun span (n, start, NONE) = if 0 <= start andalso start <= n then SOME (start, n - start) else NONE
    | span (n, start, SOME k) = if 0 <= start andalso 0 <= k andalso start + k <= n then SOME (start, k) else NONE
  (* the coordinates of a region in traversal order *)
  fun cells A.RowMajor ((r0, nr), (c0, nc)) = List.concat (List.tabulate (nr, fn i => List.tabulate (nc, fn j => (r0 + i, c0 + j))))
    | cells A.ColMajor ((r0, nr), (c0, nc)) = List.concat (List.tabulate (nc, fn j => List.tabulate (nr, fn i => (r0 + i, c0 + j))))
  fun inSpan (start, k) i = start <= i andalso i < start + k
  fun randomSize n = if T.range (0, 2) = 0 then NONE else SOME (T.range (if T.range (0, 9) = 0 then ~1 else 0, n + 1))
  val eqMO = T.eq (T.option (T.list (T.list T.int)))
  val eqTO = T.eq (T.option (T.list (T.triple (T.int, T.int, T.int))))
  (* laws noElements: the checks of the samples whose array, valid region or
     destination has elements, or (noElements) those of the other samples. SML/NJ 110.79
     traverses a row, or a column, of a region that has none, even beyond the
     end of the array: the section no-elements-writes below keeps the writes
     of modify, modifyi and copy that follow from that away from the other
     checks. *)
  fun laws (noElements : bool) = (T.seed 10; T.repeat (50, fn k =>
    let
      val tag = (if noElements then "model-empty-" else "model-") ^ Int.toString k
      val r = T.range (0, 5)
      val c = T.range (0, 5)
      val m = randomRows (r, c)
      fun a () = make (r, c, m)
      val tr = if k mod 2 = 0 then A.RowMajor else A.ColMajor
      val all = cells tr ((0, r), (0, c))
      (* coordinates that are valid, or just not *)
      val i = T.range (~1, r)
      val j = T.range (~1, c)
      val ok = 0 <= i andalso i < r andalso 0 <= j andalso j < c
      val x = T.range (~50, 50)
      (* a region that is valid more often than not *)
      val r0 = T.range (if T.range (0, 9) = 0 then ~1 else 0, r + (if T.range (0, 9) = 0 then 1 else 0))
      val c0 = T.range (if T.range (0, 9) = 0 then ~1 else 0, c + (if T.range (0, 9) = 0 then 1 else 0))
      val nr = randomSize (r - r0)
      val nc = randomSize (c - c0)
      fun reg b = region (b, r0, c0, nr, nc)
      val spans = case (span (r, r0, nr), span (c, c0, nc)) of (SOME rs, SOME cs) => SOME (rs, cs) | _ => NONE
      val fi = fn (i, j, e) => 7 * i - 3 * j + e
      val gi = fn (i, j, e, b) => i * e + j - 2 * b
      val g = fn (e, b) => e - 2 * b
      (* a destination and a position in it, and a position in the array itself *)
      val r2 = T.range (0, 6)
      val c2 = T.range (0, 6)
      val d = randomRows (r2, c2)
      val there = (T.range (0, r2), T.range (0, c2))
      val here = (T.range (0, r), T.range (0, c))
      (* copied (dst, dims, (dr, dc)): the rows of dst after the copy of the
         region of m to (dr, dc), or NONE for Subscript: the region, or "the
         derived destination region (the source region src translated to
         (dst_row,dst_col))", is not valid *)
      fun copied (dst, (rows2, cols2), (dr, dc)) =
        case spans of
          NONE => NONE
        | SOME ((sr, nr'), (sc, nc')) =>
            (case (span (rows2, dr, SOME nr'), span (cols2, dc, SOME nc')) of
               (SOME rs, SOME cs) =>
                 SOME (List.tabulate (rows2, fn i => List.tabulate (cols2, fn j =>
                         if inSpan rs i andalso inSpan cs j then el m (sr + i - dr, sc + j - dc) else el dst (i, j))))
             | _ => NONE)
      val emptyArray = r = 0 orelse c = 0
      val emptyRegion = emptyArray orelse (case spans of SOME ((_, 0), _) => true | SOME (_, (_, 0)) => true | _ => false)
      val emptyCopy = emptyRegion orelse r2 = 0 orelse c2 = 0
    in
      if emptyArray <> noElements then () else (
      eqD ("Array2.dimensions/" ^ tag, (r, c), fn () => A.dimensions (a ()));
      eqI ("Array2.nRows/" ^ tag, r, fn () => A.nRows (a ()));
      eqI ("Array2.nCols/" ^ tag, c, fn () => A.nCols (a ()));
      eqA ("Array2.tabulate/" ^ tag, m, fn () => A.tabulate tr (r, c, el m));
      eqA ("Array2.fromList/" ^ tag, m, fn () => A.fromList m);
      eqA ("Array2.array/" ^ tag, List.tabulate (r, fn _ => List.tabulate (c, fn _ => x)), fn () => A.array (r, c, x));
      (if ok
       then (eqI ("Array2.sub/" ^ tag, el m (i, j), fn () => A.sub (a (), i, j));
             eqA ("Array2.update/" ^ tag,
                  List.tabulate (r, fn i' => List.tabulate (c, fn j' => if i' = i andalso j' = j then x else el m (i', j'))),
                  fn () => let val b = a () in A.update (b, i, j, x); b end))
       else (T.raises ("Array2.sub/" ^ tag, T.isSubscript, fn () => A.sub (a (), i, j));
             T.raises ("Array2.update/" ^ tag, T.isSubscript, fn () => A.update (a (), i, j, x))));
      (if 0 <= i andalso i < r
       then eqL ("Array2.row/" ^ tag, List.nth (m, i), fn () => vectorToList (A.row (a (), i)))
       else T.raises ("Array2.row/" ^ tag, T.isSubscript, fn () => A.row (a (), i)));
      (if 0 <= j andalso j < c
       then eqL ("Array2.column/" ^ tag, List.map (fn row => List.nth (row, j)) m, fn () => vectorToList (A.column (a (), j)))
       else T.raises ("Array2.column/" ^ tag, T.isSubscript, fn () => A.column (a (), j)));
      eqL ("Array2.app/" ^ tag, List.map (el m) all,
           fn () => let val (f, seen) = trace (fn _ => ()) in A.app tr f (a ()); seen () end);
      eqI ("Array2.fold/" ^ tag, List.foldl g 1 (List.map (el m) all), fn () => A.fold tr g 1 (a ()));
      eqA ("Array2.modify/" ^ tag, List.map (List.map (fn e => e * e)) m,
           fn () => let val b = a () in A.modify tr (fn e => e * e) b; b end));
      if emptyRegion <> noElements then () else (
      eqTO ("Array2.appi/" ^ tag, Option.map (fn s => List.map (fn (i, j) => (i, j, el m (i, j))) (cells tr s)) spans,
            fn () => SOME (appi tr (reg (a ()))) handle Subscript => NONE);
      T.eq (T.option T.int) ("Array2.foldi/" ^ tag,
                             Option.map (fn s => List.foldl (fn ((i, j), b) => gi (i, j, el m (i, j), b)) 1 (cells tr s)) spans,
                             fn () => SOME (A.foldi tr gi 1 (reg (a ()))) handle Subscript => NONE);
      eqMO ("Array2.modifyi/" ^ tag,
            Option.map (fn (rs, cs) => List.tabulate (r, fn i => List.tabulate (c, fn j =>
                          if inSpan rs i andalso inSpan cs j then fi (i, j, el m (i, j)) else el m (i, j)))) spans,
            fn () => let val b = a () in A.modifyi tr fi (reg b); SOME (rows b) end handle Subscript => NONE));
      if emptyCopy <> noElements then () else (
      eqMO ("Array2.copy/" ^ tag, copied (d, (r2, c2), there),
            fn () => let val b = make (r2, c2, d)
                     in A.copy {src = reg (a ()), dst = b, dst_row = #1 there, dst_col = #2 there}; SOME (rows b) end
                     handle Subscript => NONE);
      eqMO ("Array2.copy/within-" ^ tag, copied (m, (r, c), here),
            fn () => let val b = a ()
                     in A.copy {src = reg b, dst = b, dst_row = #1 here, dst_col = #2 here}; SOME (rows b) end
                     handle Subscript => NONE))
    end))
  val () = laws false

  (*<< no-elements *)
  (* ---- arrays and valid regions without elements: nothing is traversed,
     nothing is copied. The regions are for an array of 3 rows and 4 columns;
     "0 <= #row reg <= nRows (#base reg)" allows a region to start at the end
     of the array. ---- *)
  val nothing : (string * (int A.array -> int A.region)) list =
    [("rows-at-the-end", fn a => region (a, 3, 0, NONE, NONE)),
     ("cols-at-the-end", fn a => region (a, 0, 4, NONE, NONE)),
     ("zero-nrows", fn a => region (a, 1, 1, SOME 0, SOME 2)),
     ("zero-ncols", fn a => region (a, 1, 1, SOME 2, SOME 0)),
     ("zero-nrows-ncols-at-the-end", fn a => region (a, 3, 4, SOME 0, SOME 0))]
  val () = List.app (fn (name, reg) =>
             (eqT ("Array2.appi/nothing-RowMajor-" ^ name, [], fn () => appi A.RowMajor (reg (m34 ())));
              eqT ("Array2.appi/nothing-ColMajor-" ^ name, [], fn () => appi A.ColMajor (reg (m34 ())));
              eqI ("Array2.foldi/nothing-RowMajor-" ^ name, 42, fn () => A.foldi A.RowMajor (fn (i, j, a, b) => i + j + a + b) 42 (reg (m34 ())));
              eqI ("Array2.foldi/nothing-ColMajor-" ^ name, 42, fn () => A.foldi A.ColMajor (fn (i, j, a, b) => i + j + a + b) 42 (reg (m34 ())))))
             nothing
  (*>> no-elements *)

  (*<< no-elements-writes *)
  (* the same for modifyi and copy, and the laws for the samples without elements *)
  val nothing : (string * (int A.array -> int A.region)) list =
    [("rows-at-the-end", fn a => region (a, 3, 0, NONE, NONE)),
     ("cols-at-the-end", fn a => region (a, 0, 4, NONE, NONE)),
     ("zero-nrows", fn a => region (a, 1, 1, SOME 0, SOME 2)),
     ("zero-ncols", fn a => region (a, 1, 1, SOME 2, SOME 0)),
     ("zero-nrows-ncols-at-the-end", fn a => region (a, 3, 4, SOME 0, SOME 0))]
  val () = List.app (fn (name, reg) =>
             (eqA ("Array2.modifyi/nothing-RowMajor-" ^ name, l34, fn () => let val a = m34 () in A.modifyi A.RowMajor (fn _ => 99) (reg a); a end);
              eqA ("Array2.modifyi/nothing-ColMajor-" ^ name, l34, fn () => let val a = m34 () in A.modifyi A.ColMajor (fn _ => 99) (reg a); a end);
              eqA ("Array2.copy/nothing-" ^ name, [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]],
                   fn () => copyTo (reg (m34 ()), (4, 5), 1, 0))))
             nothing
  val () = eqA ("Array2.copy/nothing-to-the-end-of-dst", [[0, 0], [0, 0]],
                fn () => copyTo (region (m34 (), 1, 1, SOME 0, SOME 0), (2, 2), 2, 2))
  (* the derived destination region of a source region without elements can be invalid too *)
  val () = T.raises ("Array2.copy/Subscript-dst-nothing-row-beyond", T.isSubscript,
                     fn () => copyTo (region (m34 (), 1, 1, SOME 0, SOME 0), (2, 2), 3, 0))
  val () = T.raises ("Array2.copy/Subscript-dst-nothing-cols-too-far", T.isSubscript,
                     fn () => copyTo (region (m34 (), 1, 1, SOME 0, SOME 2), (2, 2), 0, 1))
  val () = laws true
  (*>> no-elements-writes *)

  (*<< overflow *)
  (* ---- Subscript, not Overflow: the conditions of the page hold for the
     numbers below, although the position in a representation by one sequence,
     or the end of the region, does not exist as an int. ---- *)
  (* The numbers are read from refs: the compiler of Poly/ML 5.7.1 stops with
     "Overflow unexpectedly raised while compiling" when they are constants. *)
  val extremes = ref (case Int.maxInt of SOME m => m | NONE => 1073741823, case Int.minInt of SOME m => m | NONE => ~1073741824)
  fun most () = #1 (!extremes)
  fun least () = #2 (!extremes)
  val () = T.raises ("Array2.sub/Subscript-not-Overflow-row", T.isSubscript, fn () => A.sub (m34 (), most (), 1))
  val () = T.raises ("Array2.sub/Subscript-not-Overflow-column", T.isSubscript, fn () => A.sub (m34 (), 1, most ()))
  val () = T.raises ("Array2.sub/Subscript-not-Overflow-both", T.isSubscript, fn () => A.sub (m34 (), most (), most ()))
  val () = T.raises ("Array2.sub/Subscript-not-Overflow-least", T.isSubscript, fn () => A.sub (m34 (), least (), least ()))
  val () = T.raises ("Array2.update/Subscript-not-Overflow-row", T.isSubscript, fn () => A.update (m34 (), most (), 1, 9))
  val () = T.raises ("Array2.update/Subscript-not-Overflow-column", T.isSubscript, fn () => A.update (m34 (), 1, most (), 9))
  val () = T.raises ("Array2.update/Subscript-not-Overflow-least", T.isSubscript, fn () => A.update (m34 (), least (), least (), 9))
  val () = T.raises ("Array2.row/Subscript-not-Overflow", T.isSubscript, fn () => A.row (m34 (), most ()))
  val () = T.raises ("Array2.column/Subscript-not-Overflow", T.isSubscript, fn () => A.column (m34 (), most ()))
  val extreme : (string * (int A.array -> int A.region)) list =
    [("sum-nrows", fn a => region (a, 1, 0, SOME (most ()), NONE)),
     ("sum-ncols", fn a => region (a, 0, 1, NONE, SOME (most ()))),
     ("sum-row", fn a => region (a, most (), 0, SOME 1, NONE)),
     ("sum-col", fn a => region (a, 0, most (), NONE, SOME 1)),
     ("row", fn a => region (a, most (), 0, NONE, NONE)),
     ("col", fn a => region (a, 0, most (), NONE, NONE)),
     ("least-row", fn a => region (a, least (), 0, SOME (most ()), NONE)),
     ("least-ncols", fn a => region (a, 0, 1, NONE, SOME (least ())))]
  val () = List.app (fn (name, reg) =>
             (T.raises ("Array2.appi/Subscript-not-Overflow-" ^ name, T.isSubscript, fn () => A.appi A.RowMajor (fn _ => ()) (reg (m34 ())));
              T.raises ("Array2.foldi/Subscript-not-Overflow-" ^ name, T.isSubscript,
                        fn () => A.foldi A.ColMajor (fn (_, _, _, b) => b) 0 (reg (m34 ())));
              T.raises ("Array2.modifyi/Subscript-not-Overflow-" ^ name, T.isSubscript, fn () => A.modifyi A.RowMajor (fn _ => 99) (reg (m34 ())));
              T.raises ("Array2.copy/Subscript-not-Overflow-src-" ^ name, T.isSubscript, fn () => copyTo (reg (m34 ()), (8, 8), 0, 0))))
             extreme
  val () = T.raises ("Array2.copy/Subscript-not-Overflow-dst-sum-row", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), most (), 0))
  val () = T.raises ("Array2.copy/Subscript-not-Overflow-dst-sum-col", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, most ()))
  val () = T.raises ("Array2.copy/Subscript-not-Overflow-dst-least", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), least (), least ()))
  (*>> overflow *)

  (*<< too-large *)
  (* ---- Size: "If r < 0, c < 0 or the resulting array would be too large, the
     Size exception is raised." An array of Int.maxInt rows and as many, or 2,
     columns is too large everywhere: the number of its elements is not an
     int. The function that is tabulated gives up after 1000 applications. ---- *)
  val huge = case Int.maxInt of SOME m => m | NONE => 1073741823
  fun giveUp () = let val n = ref 0 in fn _ => (n := !n + 1; if !n > 1000 then raise Fail "f applied before Size" else 0) end
  val () = T.raises ("Array2.array/Size-too-large", T.isSize, fn () => A.array (huge, huge, 0))
  val () = T.raises ("Array2.array/Size-too-large-rows", T.isSize, fn () => A.array (huge, 2, 0))
  val () = T.raises ("Array2.array/Size-too-large-columns", T.isSize, fn () => A.array (2, huge, 0))
  val () = T.raises ("Array2.tabulate/Size-too-large-RowMajor", T.isSize, fn () => A.tabulate A.RowMajor (huge, huge, giveUp ()))
  val () = T.raises ("Array2.tabulate/Size-too-large-ColMajor", T.isSize, fn () => A.tabulate A.ColMajor (2, huge, giveUp ()))
  (*>> too-large *)
end
