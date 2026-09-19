(* Checks of a structure with signature MONO_ARRAY2, for any element type.
   Expected values follow https://smlfamily.github.io/Basis/mono-array2.html;
   the checks are those of tests/basis/array2.sml, made generic.

     structure Generic2 = TestMonoArray2Fn (structure A = IntArray2 structure V = IntVector val name = "IntArray2" val elems = ... val show = ... val same = ...)

   needs spec-sigs/MONO_VECTOR.sml and spec-sigs/MONO_ARRAY2.sml, and the
   structure Array2 ("If an implementation provides any structure matching
   MONO_ARRAY2, it must also supply the structure Array2", whose traversal it
   shares). V is the vector structure of the element type, the vectors that
   row and column return. The labels are name ^ ".member/case". `elems` holds
   at least 16 distinct sample elements, `show` prints one and `same` is the
   equality of elements. An element is written below as its index in `elems`,
   its code, and arrays are read back as lists of rows of codes, with A.nRows,
   A.nCols and A.sub. The arrays of a check are made inside its thunk: a check
   never sees the updates of another one.

   "The elements of 2-dimensional arrays are indexed by pair of integers (i,j)
   where i gives the row index, and [j] gives the column index." The
   coordinates that appi, foldi and modifyi pass are "the element's
   coordinates in the base array", not those in the region: "Note that the
   indices passed to argument functions in appi, foldi, and modifyi are with
   respect to the underlying matrix and not based on the region."

   TestMonoArray2LawsFn has the laws on pseudo-random arrays and regions,
   either of the samples with elements (empty = false) or of those without;
   TestMonoArray2EmptyFn the other checks of arrays and regions without
   elements, TestMonoArray2OverflowFn those with numbers near Int.maxInt and
   TestMonoArray2SizeFn those of arrays too large to exist. A test applies the
   last three, and the laws without elements, in sections of their own, as
   tests/basis/array2.sml has them. *)
functor TestMonoArray2Fn (structure A : SPEC_MONO_ARRAY2
                          structure V : SPEC_MONO_VECTOR where type vector = A.vector where type elem = A.elem
                          val name : string
                          val elems : A.elem vector
                          val show : A.elem -> string
                          val same : A.elem * A.elem -> bool) =
struct
  fun lab s = name ^ "." ^ s

  (* e i: the sample with code i; code x: the code of x, ~1 when it is none. *)
  val samples = Vector.length elems
  fun e i = Vector.sub (elems, i)
  fun code x =
    let fun go i = if i >= samples then ~1 else if same (e i, x) then i else go (i + 1)
    in go 0 end
  fun showCode i = if i >= 0 andalso i < samples then show (e i) else "?"

  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list showCode)
  val eqM = T.eq (T.list (T.list showCode))
  val eqD = T.eq (T.pair (T.int, T.int))
  val eqT = T.eq (T.list (T.triple (T.int, T.int, showCode)))
  val eqP = T.eq (T.list (T.pair (T.int, T.int)))
  val eqInts = T.eq (T.list T.int)

  fun vectorToList v = List.tabulate (V.length v, fn i => code (V.sub (v, i)))
  fun rows (a : A.array) : int list list =
    List.tabulate (A.nRows a, fn i => List.tabulate (A.nCols a, fn j => code (A.sub (a, i, j))))
  (* eqA (label, expected, f): the rows of the array f () are expected. *)
  fun eqA (label, expected : int list list, f : unit -> A.array) : unit =
    eqM (label, expected, fn () => rows (f ()))
  fun mk (l : int list list) = A.fromList (List.map (List.map e) l)

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end
  fun coded (f, seen) = (f, fn () => List.map code (seen ()))
  fun codedT (f, seen) = (f, fn () => List.map (fn (i, j, x) => (i, j, code x)) (seen ()))

  (* counter (): a function that returns the samples 0, 1, 2, ... whatever it
     is given *)
  fun counter () = let val n = ref 0 in fn _ => e (!n) before n := !n + 1 end

  fun region (a, r, c, nr, nc) : A.region = {base = a, row = r, col = c, nrows = nr, ncols = nc}
  fun whole a = region (a, 0, 0, NONE, NONE)

  (* 3 rows and 4 columns; the element (i, j) is the sample 4 * i + j:
       0  1  2  3
       4  5  6  7
       8  9 10 11 *)
  val l34 = [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]]
  fun m34 () = mk l34
  val l23 = [[1, 2, 3], [4, 5, 6]]
  fun m23 () = mk l23
  (* the region of the rows 1 and 2 and the columns 1 and 2 of a:
       5  6
       9 10 *)
  fun inner a = region (a, 1, 1, SOME 2, SOME 2)
  (* 4 rows and 4 columns; the element (i, j) is the sample 4 * i + j *)
  fun m44 () = A.tabulate A.RowMajor (4, 4, fn (i, j) => e (4 * i + j))
  (* the arrays that are copied into hold the sample z, which m34 does not *)
  val z = 15
  fun zeros (r, c) = A.array (r, c, e z)
  (* The negative index of sub, update, row and column is read from a ref: the
     compiler of Poly/ML 5.7.1 stops with "Overflow unexpectedly raised while
     compiling" on Array2.sub (a, ~1, 0) with the constant index ~1. *)
  val minusOne = ref ~1

  val () = T.check (lab "elem/sixteen-distinct-samples",
                    fn () => samples >= 16 andalso List.tabulate (16, fn i => code (e i)) = List.tabulate (16, fn i => i))

  (* ---- RowMajor, ColMajor: "datatype traversal = datatype
     Array2.traversal". "RowMajor indicates that, given a region, the rows are
     traversed from left to right (smallest column index to largest column
     index), starting with the first row in the region, then the second, and
     so on until the last row is traversed. ColMajor reverses the roles of row
     and column, traversing the columns from top down (smallest row index to
     largest row index), starting with the first column, then the second, and
     so on" (array2.html) ---- *)
  val () = eqL (lab "RowMajor/rows-from-left-to-right", [1, 2, 3, 4, 5, 6],
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in A.app A.RowMajor f (m23 ()); seen () end)
  val () = eqL (lab "ColMajor/columns-from-top-down", [1, 4, 2, 5, 3, 6],
                fn () => let val (f, seen) = coded (trace (fn _ => ())) in A.app A.ColMajor f (m23 ()); seen () end)
  val () = eqInts (lab "RowMajor/is-a-constructor", [1, 2],
                   fn () => List.map (fn A.RowMajor => 1 | A.ColMajor => 2) [A.RowMajor, A.ColMajor])
  val () = eqB (lab "ColMajor/is-not-RowMajor", true, fn () => A.RowMajor <> A.ColMajor andalso A.ColMajor = A.ColMajor)
  val () = eqB (lab "RowMajor/is-Array2.RowMajor", true, fn () => A.RowMajor = Array2.RowMajor andalso A.ColMajor = Array2.ColMajor)

  (* ---- array: "creates a new array with r rows and c columns, with each
     element initialized to the value init. If r < 0, c < 0 or the resulting
     array size is too large, the Size exception is raised." ---- *)
  val () = eqA (lab "array/basic", [[7, 7, 7], [7, 7, 7]], fn () => A.array (2, 3, e 7))
  val () = eqA (lab "array/one", [[7]], fn () => A.array (1, 1, e 7))
  val () = eqD (lab "array/dimensions", (2, 3), fn () => A.dimensions (A.array (2, 3, e 7)))
  val () = eqD (lab "array/no-rows", (0, 3), fn () => A.dimensions (A.array (0, 3, e 7)))
  val () = eqD (lab "array/no-columns", (2, 0), fn () => A.dimensions (A.array (2, 0, e 7)))
  val () = eqD (lab "array/no-rows-no-columns", (0, 0), fn () => A.dimensions (A.array (0, 0, e 7)))
  val () = eqA (lab "array/no-columns-rows", [[], []], fn () => A.array (2, 0, e 7))
  val () = T.raises (lab "array/Size-negative-rows", T.isSize, fn () => A.array (~1, 3, e 7))
  val () = T.raises (lab "array/Size-negative-columns", T.isSize, fn () => A.array (3, ~1, e 7))
  val () = T.raises (lab "array/Size-negative-both", T.isSize, fn () => A.array (~1, ~1, e 7))
  val () = T.raises (lab "array/Size-negative-rows-no-columns", T.isSize, fn () => A.array (~1, 0, e 7))
  val () = T.raises (lab "array/Size-negative-columns-no-rows", T.isSize, fn () => A.array (0, ~1, e 7))
  val () = eqA (lab "array/elements-are-separate", [[7, 7, 7], [7, 8, 7]],
                fn () => let val a = A.array (2, 3, e 7) in A.update (a, 1, 1, e 8); a end)

  (* ---- fromList: "The elements should be presented in row major form, i.e.,
     hd l gives the first row, hd (tl l) gives the second row, etc. It raises
     the Size exception if the the resulting array size is too large, or if
     the lists in l do not all have the same length." ---- *)
  val () = eqA (lab "fromList/basic", l23, fn () => mk l23)
  val () = eqD (lab "fromList/dimensions", (2, 3), fn () => A.dimensions (mk l23))
  val () = eqI (lab "fromList/second-row-first-column", 4, fn () => code (A.sub (mk l23, 1, 0)))
  val () = eqI (lab "fromList/first-row-last-column", 3, fn () => code (A.sub (mk l23, 0, 2)))
  val () = eqD (lab "fromList/one-row", (1, 3), fn () => A.dimensions (mk [[1, 2, 3]]))
  val () = eqD (lab "fromList/one-column", (3, 1), fn () => A.dimensions (mk [[1], [2], [3]]))
  val () = eqA (lab "fromList/one-element", [[7]], fn () => mk [[7]])
  val () = eqA (lab "fromList/every-sample", [[0, 1, 2, 3, 4, 5, 6, 7], [8, 9, 10, 11, 12, 13, 14, 15]],
                fn () => A.fromList [List.tabulate (8, e), List.tabulate (8, fn i => e (8 + i))])
  val () = eqD (lab "fromList/no-rows", (0, 0), fn () => A.dimensions (A.fromList []))
  val () = eqD (lab "fromList/empty-rows", (3, 0), fn () => A.dimensions (A.fromList [[], [], []]))
  val () = T.raises (lab "fromList/Size-second-shorter", T.isSize, fn () => mk [[1, 2], [3]])
  val () = T.raises (lab "fromList/Size-second-longer", T.isSize, fn () => mk [[1], [2, 3]])
  val () = T.raises (lab "fromList/Size-last-shorter", T.isSize, fn () => mk [[1, 2], [3, 4], [5]])
  val () = T.raises (lab "fromList/Size-first-empty", T.isSize, fn () => mk [[], [1]])
  val () = T.raises (lab "fromList/Size-second-empty", T.isSize, fn () => mk [[1], []])

  (* ---- tabulate: "creates a new array with r rows and c columns, with the
     (i,j)(th) element initialized to f (i,j). The elements are initialized in
     the traversal order specified by tr. If r < 0, c < 0 or the resulting
     array size is too large, the Size exception is raised." ---- *)
  fun at (i, j) = e (4 * i + j)
  val () = eqA (lab "tabulate/RowMajor", [[0, 1, 2], [4, 5, 6]], fn () => A.tabulate A.RowMajor (2, 3, at))
  val () = eqA (lab "tabulate/ColMajor", [[0, 1, 2], [4, 5, 6]], fn () => A.tabulate A.ColMajor (2, 3, at))
  val () = eqD (lab "tabulate/dimensions", (2, 3), fn () => A.dimensions (A.tabulate A.ColMajor (2, 3, fn _ => e 0)))
  val () = eqP (lab "tabulate/RowMajor-order", [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)],
                fn () => let val (f, seen) = trace (fn _ => e 0) in ignore (A.tabulate A.RowMajor (2, 3, f)); seen () end)
  val () = eqP (lab "tabulate/ColMajor-order", [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2)],
                fn () => let val (f, seen) = trace (fn _ => e 0) in ignore (A.tabulate A.ColMajor (2, 3, f)); seen () end)
  val () = eqA (lab "tabulate/RowMajor-counter", [[0, 1, 2], [3, 4, 5]], fn () => A.tabulate A.RowMajor (2, 3, counter ()))
  val () = eqA (lab "tabulate/ColMajor-counter", [[0, 2, 4], [1, 3, 5]], fn () => A.tabulate A.ColMajor (2, 3, counter ()))
  val () = eqA (lab "tabulate/one", [[5]], fn () => A.tabulate A.RowMajor (1, 1, fn _ => e 5))
  val () = eqD (lab "tabulate/no-rows", (0, 3), fn () => A.dimensions (A.tabulate A.RowMajor (0, 3, fn _ => e 0)))
  val () = eqD (lab "tabulate/no-columns", (2, 0), fn () => A.dimensions (A.tabulate A.ColMajor (2, 0, fn _ => e 0)))
  val () = eqP (lab "tabulate/no-elements-no-f", [],
                fn () => let val (f, seen) = trace (fn _ => e 0)
                         in ignore (A.tabulate A.RowMajor (0, 3, f)); ignore (A.tabulate A.ColMajor (2, 0, f)); seen () end)
  val () = T.raises (lab "tabulate/Size-negative-rows", T.isSize, fn () => A.tabulate A.RowMajor (~1, 3, fn _ => e 0))
  val () = T.raises (lab "tabulate/Size-negative-columns", T.isSize, fn () => A.tabulate A.RowMajor (3, ~1, fn _ => e 0))
  val () = T.raises (lab "tabulate/Size-negative-ColMajor", T.isSize, fn () => A.tabulate A.ColMajor (3, ~1, fn _ => e 0))
  val () = eqP (lab "tabulate/Size-before-f", [],
                fn () => let val (f, seen) = trace (fn _ => e 0)
                         in ignore (A.tabulate A.RowMajor (3, ~1, f)) handle Size => ();
                            ignore (A.tabulate A.ColMajor (~1, 3, f)) handle Size => ();
                            seen ()
                         end)

  (* ---- sub: "returns the (i,j)(th) element of the array arr. If i < 0,
     j < 0, nRows arr <= i or nCols arr <= j, then the Subscript exception is
     raised." ---- *)
  val () = eqI (lab "sub/first", 0, fn () => code (A.sub (m34 (), 0, 0)))
  val () = eqI (lab "sub/end-of-first-row", 3, fn () => code (A.sub (m34 (), 0, 3)))
  val () = eqI (lab "sub/start-of-last-row", 8, fn () => code (A.sub (m34 (), 2, 0)))
  val () = eqI (lab "sub/middle", 6, fn () => code (A.sub (m34 (), 1, 2)))
  val () = eqI (lab "sub/last", 11, fn () => code (A.sub (m34 (), 2, 3)))
  val () = T.raises (lab "sub/Subscript-row-nRows", T.isSubscript, fn () => A.sub (m34 (), 3, 0))
  val () = T.raises (lab "sub/Subscript-column-nCols", T.isSubscript, fn () => A.sub (m34 (), 0, 4))
  val () = T.raises (lab "sub/Subscript-column-nCols-last-row", T.isSubscript, fn () => A.sub (m34 (), 2, 4))
  val () = T.raises (lab "sub/Subscript-negative-row", T.isSubscript, fn () => A.sub (m34 (), !minusOne, 0))
  val () = T.raises (lab "sub/Subscript-negative-column", T.isSubscript, fn () => A.sub (m34 (), 1, !minusOne))
  val () = T.raises (lab "sub/Subscript-negative-row-column-beyond", T.isSubscript, fn () => A.sub (m34 (), !minusOne, 5))
  val () = T.raises (lab "sub/Subscript-column-is-a-row-index", T.isSubscript, fn () => A.sub (mk [[1, 2], [3, 4], [5, 6]], 1, 2))
  val () = T.raises (lab "sub/Subscript-row-is-a-column-index", T.isSubscript, fn () => A.sub (m23 (), 2, 1))
  val () = T.raises (lab "sub/Subscript-no-rows", T.isSubscript, fn () => A.sub (zeros (0, 3), 0, 0))
  val () = T.raises (lab "sub/Subscript-no-columns", T.isSubscript, fn () => A.sub (zeros (3, 0), 0, 0))

  (* ---- update: "sets the (i,j)(th) element of the array arr to a. If i < 0,
     j < 0, nRows arr <= i or nCols arr <= j, then the Subscript exception is
     raised." ---- *)
  fun updated (i, j, x) = let val a = m23 () in A.update (a, i, j, e x); a end
  val () = eqA (lab "update/first", [[9, 2, 3], [4, 5, 6]], fn () => updated (0, 0, 9))
  val () = eqA (lab "update/end-of-first-row", [[1, 2, 9], [4, 5, 6]], fn () => updated (0, 2, 9))
  val () = eqA (lab "update/start-of-last-row", [[1, 2, 3], [9, 5, 6]], fn () => updated (1, 0, 9))
  val () = eqA (lab "update/last", [[1, 2, 3], [4, 5, 9]], fn () => updated (1, 2, 9))
  val () = eqA (lab "update/twice-same-element", [[1, 2, 3], [4, 7, 6]],
                fn () => let val a = m23 () in A.update (a, 1, 1, e 9); A.update (a, 1, 1, e 7); a end)
  val () = eqI (lab "update/seen-through-alias", 9,
                fn () => let val a = m23 () val b = a in A.update (b, 1, 1, e 9); code (A.sub (a, 1, 1)) end)
  val () = eqA (lab "update/every-sample", [[15, 14, 13, 12, 11, 10, 9, 8], [7, 6, 5, 4, 3, 2, 1, 0]],
                fn () => let val a = A.array (2, 8, e 0)
                         in T.repeat (16, fn k => A.update (a, k div 8, k mod 8, e (15 - k))); a end)
  val () = T.raises (lab "update/Subscript-row-nRows", T.isSubscript, fn () => A.update (m23 (), 2, 0, e 9))
  val () = T.raises (lab "update/Subscript-column-nCols", T.isSubscript, fn () => A.update (m23 (), 0, 3, e 9))
  val () = T.raises (lab "update/Subscript-negative-row", T.isSubscript, fn () => A.update (m23 (), !minusOne, 0, e 9))
  val () = T.raises (lab "update/Subscript-negative-column", T.isSubscript, fn () => A.update (m23 (), 1, !minusOne, e 9))
  val () = T.raises (lab "update/Subscript-no-rows", T.isSubscript, fn () => A.update (zeros (0, 3), 0, 0, e 9))
  val () = T.raises (lab "update/Subscript-no-columns", T.isSubscript, fn () => A.update (zeros (3, 0), 0, 0, e 9))
  val () = eqA (lab "update/Subscript-changes-nothing", l23,
                fn () => let val a = m23 ()
                         in A.update (a, 0, 3, e 9) handle Subscript => ();
                            A.update (a, 1, !minusOne, e 9) handle Subscript => ();
                            A.update (a, 2, 0, e 9) handle Subscript => ();
                            a
                         end)

  (* ---- dimensions, nCols, nRows: "nCols returns the number of columns, nRows
     returns the number of rows and dimension returns a pair containing the
     number of rows and columns of the array. The functions nRows and nCols
     are respectively equivalent to #1 o dimensions and #2 o dimensions" ---- *)
  val () = eqD (lab "dimensions/rows-then-columns", (3, 4), fn () => A.dimensions (m34 ()))
  val () = eqD (lab "dimensions/one-row", (1, 3), fn () => A.dimensions (zeros (1, 3)))
  val () = eqI (lab "nRows/basic", 3, fn () => A.nRows (m34 ()))
  val () = eqI (lab "nCols/basic", 4, fn () => A.nCols (m34 ()))
  val () = eqI (lab "nRows/no-rows", 0, fn () => A.nRows (zeros (0, 3)))
  val () = eqI (lab "nCols/no-rows", 3, fn () => A.nCols (zeros (0, 3)))
  val () = eqI (lab "nRows/no-columns", 3, fn () => A.nRows (zeros (3, 0)))
  val () = eqI (lab "nCols/no-columns", 0, fn () => A.nCols (zeros (3, 0)))
  val () = eqB (lab "nRows/is-first-of-dimensions", true, fn () => let val a = m34 () in A.nRows a = #1 (A.dimensions a) end)
  val () = eqB (lab "nCols/is-second-of-dimensions", true, fn () => let val a = m34 () in A.nCols a = #2 (A.dimensions a) end)

  (* ---- row: "returns row i of arr. It raises Subscript if i < 0 or nRows arr
     <= i." The row is a vector of V, "the type of one-dimensional immutable
     vectors of the underlying element type". ---- *)
  val () = eqL (lab "row/first", [0, 1, 2, 3], fn () => vectorToList (A.row (m34 (), 0)))
  val () = eqL (lab "row/middle", [4, 5, 6, 7], fn () => vectorToList (A.row (m34 (), 1)))
  val () = eqL (lab "row/last", [8, 9, 10, 11], fn () => vectorToList (A.row (m34 (), 2)))
  val () = eqL (lab "row/no-columns", [], fn () => vectorToList (A.row (zeros (3, 0), 2)))
  val () = eqL (lab "row/is-a-snapshot", [4, 5, 6, 7],
                fn () => let val a = m34 () val v = A.row (a, 1) in A.update (a, 1, 1, e 14); vectorToList v end)
  val () = eqL (lab "row/every-sample", [8, 9, 10, 11, 12, 13, 14, 15],
                fn () => vectorToList (A.row (A.tabulate A.RowMajor (2, 8, fn (i, j) => e (8 * i + j)), 1)))
  val () = T.raises (lab "row/Subscript-nRows", T.isSubscript, fn () => A.row (m34 (), 3))
  val () = T.raises (lab "row/Subscript-is-a-column-index", T.isSubscript, fn () => A.row (m23 (), 2))
  val () = T.raises (lab "row/Subscript-negative", T.isSubscript, fn () => A.row (m34 (), !minusOne))
  val () = T.raises (lab "row/Subscript-no-rows", T.isSubscript, fn () => A.row (zeros (0, 3), 0))

  (* ---- column: "returns column j of arr. It raises Subscript if j < 0 or
     nCols arr <= j." ---- *)
  val () = eqL (lab "column/first", [0, 4, 8], fn () => vectorToList (A.column (m34 (), 0)))
  val () = eqL (lab "column/middle", [2, 6, 10], fn () => vectorToList (A.column (m34 (), 2)))
  val () = eqL (lab "column/last", [3, 7, 11], fn () => vectorToList (A.column (m34 (), 3)))
  val () = eqL (lab "column/no-rows", [], fn () => vectorToList (A.column (zeros (0, 3), 2)))
  val () = eqL (lab "column/is-a-snapshot", [1, 5, 9],
                fn () => let val a = m34 () val v = A.column (a, 1) in A.update (a, 1, 1, e 14); vectorToList v end)
  val () = eqL (lab "column/every-sample", [8, 9, 10, 11, 12, 13, 14, 15],
                fn () => vectorToList (A.column (A.tabulate A.ColMajor (8, 2, fn (i, j) => e (8 * j + i)), 1)))
  val () = T.raises (lab "column/Subscript-nCols", T.isSubscript, fn () => A.column (m34 (), 4))
  val () = T.raises (lab "column/Subscript-is-a-row-index", T.isSubscript, fn () => A.column (mk [[1, 2], [3, 4], [5, 6]], 2))
  val () = T.raises (lab "column/Subscript-negative", T.isSubscript, fn () => A.column (m34 (), !minusOne))
  val () = T.raises (lab "column/Subscript-no-columns", T.isSubscript, fn () => A.column (zeros (3, 0), 0))

  (* ---- regions: "reg is valid if 0 <= #row reg <= nRows (#base reg) when
     #nrows reg = NONE, or 0 <= #row reg <= (#row reg)+nr <= nRows (#base reg)
     when #nrows reg = SOME(nr), and the analogous conditions hold for
     columns." The regions below are for an array of 3 rows and 4 columns. ---- *)
  val invalid : (string * (A.array -> A.region)) list =
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

  (* ---- copy: "copies the region src into the array dst, with the (#row
     src,#col src)(th) element being copied into the destination array at
     position (dst_row,dst_col). If the source region is not valid, then the
     Subscript exception is raised. Similarly, if the derived destination
     region (the source region src translated to (dst_row,dst_col)) is not
     valid in dst, then the Subscript exception is raised." z (15) is the
     sample of the destination arrays. ---- *)
  fun copyTo (src, dims, r, c) = let val d = zeros dims in A.copy {src = src, dst = d, dst_row = r, dst_col = c}; d end
  val () = eqA (lab "copy/region", [[z, z, z, z, z], [z, z, 5, 6, z], [z, z, 9, 10, z], [z, z, z, z, z]],
                fn () => copyTo (inner (m34 ()), (4, 5), 1, 2))
  val () = eqA (lab "copy/to-the-first-corner", [[5, 6, z, z, z], [9, 10, z, z, z], [z, z, z, z, z], [z, z, z, z, z]],
                fn () => copyTo (inner (m34 ()), (4, 5), 0, 0))
  val () = eqA (lab "copy/to-the-last-corner", [[z, z, z, z, z], [z, z, z, z, z], [z, z, z, 5, 6], [z, z, z, 9, 10]],
                fn () => copyTo (inner (m34 ()), (4, 5), 2, 3))
  val () = eqA (lab "copy/whole-NONE", [[z, z, z, z, z], [z, 0, 1, 2, 3], [z, 4, 5, 6, 7], [z, 8, 9, 10, 11]],
                fn () => copyTo (whole (m34 ()), (4, 5), 1, 1))
  val () = eqA (lab "copy/whole-same-dimensions", l34, fn () => copyTo (whole (m34 ()), (3, 4), 0, 0))
  val () = eqA (lab "copy/NONE-rows-SOME-cols", [[z, z, z], [5, 6, z], [9, 10, z]],
                fn () => copyTo (region (m34 (), 1, 1, NONE, SOME 2), (3, 3), 1, 0))
  val () = eqA (lab "copy/SOME-rows-NONE-cols", [[z, z, z], [6, 7, z]],
                fn () => copyTo (region (m34 (), 1, 2, SOME 1, NONE), (2, 3), 1, 0))
  val () = eqA (lab "copy/field-order", [[z, z, z], [z, 5, 6], [z, 9, 10]],
                fn () => let val d = zeros (3, 3) val a = m34 ()
                         in A.copy {dst_col = 1, dst_row = 1, dst = d, src = {ncols = SOME 2, nrows = SOME 2, col = 1, row = 1, base = a}}; d end)
  val () = eqA (lab "copy/src-unchanged", l34, fn () => let val a = m34 () in ignore (copyTo (inner a, (4, 5), 1, 2)); a end)
  val () = eqA (lab "copy/copies-elements-not-the-array", [[5, 6], [9, 10]],
                fn () => let val a = m34 () val d = copyTo (inner a, (2, 2), 0, 0) in A.update (a, 1, 1, e 14); d end)
  val () = List.app (fn (n, reg) =>
             T.raises (lab ("copy/Subscript-src-" ^ n), T.isSubscript, fn () => copyTo (reg (m34 ()), (8, 8), 0, 0))) invalid
  val () = T.raises (lab "copy/Subscript-dst-negative-row", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), ~1, 0))
  val () = T.raises (lab "copy/Subscript-dst-negative-col", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, ~1))
  val () = T.raises (lab "copy/Subscript-dst-one-row-too-far", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 3, 0))
  val () = T.raises (lab "copy/Subscript-dst-one-col-too-far", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, 4))
  val () = T.raises (lab "copy/Subscript-dst-row-nRows", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 4, 0))
  val () = T.raises (lab "copy/Subscript-dst-col-nCols", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, 5))
  val () = T.raises (lab "copy/Subscript-dst-smaller", T.isSubscript, fn () => copyTo (whole (m34 ()), (3, 3), 0, 0))
  val () = T.raises (lab "copy/Subscript-dst-no-rows", T.isSubscript, fn () => copyTo (inner (m34 ()), (0, 5), 0, 0))
  (* The page does not say what is left in dst when Subscript is raised; the
     test takes it that nothing is copied, as the conditions are on the
     arguments alone. *)
  val () = eqA (lab "copy/Subscript-changes-nothing", [[z, z, z], [z, z, z], [z, z, z]],
                fn () => let val d = zeros (3, 3)
                         in A.copy {src = inner (m34 ()), dst = d, dst_row = 2, dst_col = 0} handle Subscript => ();
                            A.copy {src = inner (m34 ()), dst = d, dst_row = 0, dst_col = 2} handle Subscript => ();
                            d
                         end)
  (* "The copy function must correctly handle the case in which src and dst
     are equal, and the source and destination regions overlap": the elements
     arrive as they were before the copy, whichever way they move. In m44 the
     element (i, j) is 4 * i + j. *)
  fun within (r, c, nr, nc, dr, dc) =
    let val a = m44 () in A.copy {src = region (a, r, c, nr, nc), dst = a, dst_row = dr, dst_col = dc}; a end
  val () = eqA (lab "copy/overlap-down-right", [[0, 1, 2, 3], [4, 0, 1, 2], [8, 4, 5, 6], [12, 8, 9, 10]],
                fn () => within (0, 0, SOME 3, SOME 3, 1, 1))
  val () = eqA (lab "copy/overlap-up-left", [[5, 6, 7, 3], [9, 10, 11, 7], [13, 14, 15, 11], [12, 13, 14, 15]],
                fn () => within (1, 1, NONE, NONE, 0, 0))
  val () = eqA (lab "copy/overlap-down-left", [[0, 1, 2, 3], [1, 2, 3, 7], [5, 6, 7, 11], [9, 10, 11, 15]],
                fn () => within (0, 1, SOME 3, NONE, 1, 0))
  val () = eqA (lab "copy/overlap-up-right", [[0, 4, 5, 6], [4, 8, 9, 10], [8, 12, 13, 14], [12, 13, 14, 15]],
                fn () => within (1, 0, NONE, SOME 3, 0, 1))
  val () = eqA (lab "copy/overlap-right", [[0, 0, 1, 2], [4, 4, 5, 6], [8, 8, 9, 10], [12, 12, 13, 14]],
                fn () => within (0, 0, NONE, SOME 3, 0, 1))
  val () = eqA (lab "copy/overlap-left", [[1, 2, 3, 3], [5, 6, 7, 7], [9, 10, 11, 11], [13, 14, 15, 15]],
                fn () => within (0, 1, NONE, NONE, 0, 0))
  val () = eqA (lab "copy/overlap-down", [[0, 1, 2, 3], [0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]],
                fn () => within (0, 0, SOME 3, NONE, 1, 0))
  val () = eqA (lab "copy/overlap-up", [[4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14, 15], [12, 13, 14, 15]],
                fn () => within (1, 0, NONE, NONE, 0, 0))
  val () = eqA (lab "copy/overlap-onto-itself", [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14, 15]],
                fn () => within (0, 0, NONE, NONE, 0, 0))
  val () = eqA (lab "copy/same-array-apart", [[0, 1, 0, 1], [4, 5, 4, 5], [8, 9, 10, 11], [12, 13, 14, 15]],
                fn () => within (0, 0, SOME 2, SOME 2, 0, 2))
  val () = T.raises (lab "copy/overlap-Subscript", T.isSubscript, fn () => within (0, 0, NONE, NONE, 0, 1))

  (* ---- appi, app: "These apply the function f to the elements of an array
     in the order specified by tr. The more general appi function applies f to
     the elements of the region reg and supplies both the element and the
     element's coordinates in the base array to the function f. If reg is not
     valid, then the exception Subscript is raised." ---- *)
  fun appi tr reg = let val (f, seen) = codedT (trace (fn _ => ())) in A.appi tr f reg; seen () end
  val () = eqT (lab "appi/whole-RowMajor", [(0, 0, 1), (0, 1, 2), (0, 2, 3), (1, 0, 4), (1, 1, 5), (1, 2, 6)],
                fn () => appi A.RowMajor (whole (m23 ())))
  val () = eqT (lab "appi/whole-ColMajor", [(0, 0, 1), (1, 0, 4), (0, 1, 2), (1, 1, 5), (0, 2, 3), (1, 2, 6)],
                fn () => appi A.ColMajor (whole (m23 ())))
  val () = eqT (lab "appi/region-RowMajor", [(1, 1, 5), (1, 2, 6), (2, 1, 9), (2, 2, 10)], fn () => appi A.RowMajor (inner (m34 ())))
  val () = eqT (lab "appi/region-ColMajor", [(1, 1, 5), (2, 1, 9), (1, 2, 6), (2, 2, 10)], fn () => appi A.ColMajor (inner (m34 ())))
  val () = eqT (lab "appi/NONE-to-the-end-RowMajor", [(1, 2, 6), (1, 3, 7), (2, 2, 10), (2, 3, 11)],
                fn () => appi A.RowMajor (region (m34 (), 1, 2, NONE, NONE)))
  val () = eqT (lab "appi/NONE-to-the-end-ColMajor", [(1, 2, 6), (2, 2, 10), (1, 3, 7), (2, 3, 11)],
                fn () => appi A.ColMajor (region (m34 (), 1, 2, NONE, NONE)))
  val () = eqT (lab "appi/one-row", [(2, 0, 8), (2, 1, 9), (2, 2, 10)], fn () => appi A.ColMajor (region (m34 (), 2, 0, SOME 1, SOME 3)))
  val () = eqT (lab "appi/one-column", [(0, 3, 3), (1, 3, 7), (2, 3, 11)], fn () => appi A.RowMajor (region (m34 (), 0, 3, NONE, SOME 1)))
  val () = eqT (lab "appi/last-element", [(2, 3, 11)], fn () => appi A.RowMajor (region (m34 (), 2, 3, NONE, NONE)))
  val () = List.app (fn (n, reg) =>
             T.raises (lab ("appi/Subscript-" ^ n), T.isSubscript, fn () => A.appi A.RowMajor (fn _ => ()) (reg (m34 ())))) invalid
  val () = T.raises (lab "appi/Subscript-ColMajor-too-many-rows", T.isSubscript,
                     fn () => A.appi A.ColMajor (fn _ => ()) (region (m34 (), 2, 0, SOME 2, NONE)))
  val () = T.raises (lab "appi/Subscript-ColMajor-too-many-cols", T.isSubscript,
                     fn () => A.appi A.ColMajor (fn _ => ()) (region (m34 (), 0, 3, NONE, SOME 2)))
  fun app tr a = let val (f, seen) = coded (trace (fn _ => ())) in A.app tr f a; seen () end
  val () = eqL (lab "app/RowMajor", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], fn () => app A.RowMajor (m34 ()))
  val () = eqL (lab "app/ColMajor", [0, 4, 8, 1, 5, 9, 2, 6, 10, 3, 7, 11], fn () => app A.ColMajor (m34 ()))
  val () = eqL (lab "app/no-rows", [], fn () => app A.RowMajor (zeros (0, 3)))
  val () = eqL (lab "app/no-columns", [], fn () => app A.ColMajor (zeros (3, 0)))
  val () = eqA (lab "app/array-unchanged", l34, fn () => let val a = m34 () in A.app A.RowMajor (fn _ => ()) a; a end)

  (* ---- foldi, fold: "These fold the function f over the elements of an
     array arr, traversing the elements in tr order, and using the value init
     as the initial value. The more general foldi function applies f to the
     elements of the region reg and supplies both the element and the
     element's coordinates in the base array to the function f. If reg is not
     valid, then the exception Subscript is raised."
     With f (a, b) = code a - 2 * b over the region 5 6 / 9 10:
       RowMajor: 5-0 = 5, 6-10 = ~4, 9+8 = 17, 10-34 = ~24;
       ColMajor: 5-0 = 5, 9-10 = ~1, 6+2 = 8, 10-16 = ~6.
     Over the array 1 2 / 3 4:
       RowMajor: 1-0 = 1, 2-2 = 0, 3-0 = 3, 4-6 = ~2;
       ColMajor: 1-0 = 1, 3-2 = 1, 2-2 = 0, 4-0 = 4. ---- *)
  val cons = fn (i, j, a, l) => (i, j, code a) :: l
  val () = eqT (lab "foldi/whole-RowMajor-conses-reversed", [(1, 2, 6), (1, 1, 5), (1, 0, 4), (0, 2, 3), (0, 1, 2), (0, 0, 1)],
                fn () => A.foldi A.RowMajor cons [] (whole (m23 ())))
  val () = eqT (lab "foldi/whole-ColMajor-conses-reversed", [(1, 2, 6), (0, 2, 3), (1, 1, 5), (0, 1, 2), (1, 0, 4), (0, 0, 1)],
                fn () => A.foldi A.ColMajor cons [] (whole (m23 ())))
  val () = eqT (lab "foldi/region-RowMajor", [(2, 2, 10), (2, 1, 9), (1, 2, 6), (1, 1, 5)],
                fn () => A.foldi A.RowMajor cons [] (inner (m34 ())))
  val () = eqT (lab "foldi/region-ColMajor", [(2, 2, 10), (1, 2, 6), (2, 1, 9), (1, 1, 5)],
                fn () => A.foldi A.ColMajor cons [] (inner (m34 ())))
  val () = eqI (lab "foldi/nonassociative-RowMajor", ~24, fn () => A.foldi A.RowMajor (fn (_, _, a, b) => code a - 2 * b) 0 (inner (m34 ())))
  val () = eqI (lab "foldi/nonassociative-ColMajor", ~6, fn () => A.foldi A.ColMajor (fn (_, _, a, b) => code a - 2 * b) 0 (inner (m34 ())))
  val () = eqT (lab "foldi/NONE-to-the-end", [(2, 3, 11), (2, 2, 10), (1, 3, 7), (1, 2, 6)],
                fn () => A.foldi A.RowMajor cons [] (region (m34 (), 1, 2, NONE, NONE)))
  val () = List.app (fn (n, reg) =>
             T.raises (lab ("foldi/Subscript-" ^ n), T.isSubscript,
                       fn () => A.foldi A.RowMajor (fn (_, _, _, b) => b) 0 (reg (m34 ())))) invalid
  val () = T.raises (lab "foldi/Subscript-ColMajor-too-many-rows", T.isSubscript,
                     fn () => A.foldi A.ColMajor (fn (_, _, _, b) => b) 0 (region (m34 (), 2, 0, SOME 2, NONE)))
  val () = T.raises (lab "foldi/Subscript-ColMajor-too-many-cols", T.isSubscript,
                     fn () => A.foldi A.ColMajor (fn (_, _, _, b) => b) 0 (region (m34 (), 0, 3, NONE, SOME 2)))
  val () = eqInts (lab "fold/RowMajor-conses-reversed", [6, 5, 4, 3, 2, 1], fn () => A.fold A.RowMajor (fn (a, l) => code a :: l) [] (m23 ()))
  val () = eqInts (lab "fold/ColMajor-conses-reversed", [6, 3, 5, 2, 4, 1], fn () => A.fold A.ColMajor (fn (a, l) => code a :: l) [] (m23 ()))
  val () = eqI (lab "fold/nonassociative-RowMajor", ~2, fn () => A.fold A.RowMajor (fn (a, b) => code a - 2 * b) 0 (mk [[1, 2], [3, 4]]))
  val () = eqI (lab "fold/nonassociative-ColMajor", 4, fn () => A.fold A.ColMajor (fn (a, b) => code a - 2 * b) 0 (mk [[1, 2], [3, 4]]))
  val () = eqI (lab "fold/no-rows", 42, fn () => A.fold A.RowMajor (fn (a, b) => code a + b) 42 (zeros (0, 3)))
  val () = eqI (lab "fold/no-columns", 42, fn () => A.fold A.ColMajor (fn (a, b) => code a + b) 42 (zeros (3, 0)))

  (* ---- modifyi, modify: "These apply the function f to the elements of an
     array in the order specified by tr, and replace each element with the
     result of f. The more general modifyi function applies f to the elements
     of the region reg and supplies both the element and the element's
     coordinates in the base array to the function f. If reg is not valid,
     then the exception Subscript is raised."
     With fi (i, j, a) = the sample (code a + 4 * i + j + 8) mod 16:
       over the region 5 6 / 9 10 of m34: (1, 1, 5) 18 mod 16 = 2,
       (1, 2, 6) 20 mod 16 = 4, (2, 1, 9) 26 mod 16 = 10, (2, 2, 10) 28 mod 16 = 12;
       over the whole of m23: (0, 0, 1) 9, (0, 1, 2) 11, (0, 2, 3) 13,
       (1, 0, 4) 16 mod 16 = 0, (1, 1, 5) 18 mod 16 = 2, (1, 2, 6) 20 mod 16 = 4. ---- *)
  fun fi (i, j, a) = e ((code a + 4 * i + j + 8) mod 16)
  val () = eqA (lab "modifyi/region", [[0, 1, 2, 3], [4, 2, 4, 7], [8, 10, 12, 11]],
                fn () => let val a = m34 () in A.modifyi A.RowMajor fi (inner a); a end)
  val () = eqA (lab "modifyi/region-ColMajor", [[0, 1, 2, 3], [4, 2, 4, 7], [8, 10, 12, 11]],
                fn () => let val a = m34 () in A.modifyi A.ColMajor fi (inner a); a end)
  val () = eqA (lab "modifyi/whole", [[9, 11, 13], [0, 2, 4]],
                fn () => let val a = m23 () in A.modifyi A.RowMajor fi (whole a); a end)
  (* the samples 6 7 / 10 11 become (6 + 8) 14, 15 / (10 + 8) mod 16 = 2, 3 *)
  val () = eqA (lab "modifyi/NONE-to-the-end", [[0, 1, 2, 3], [4, 5, 14, 15], [8, 9, 2, 3]],
                fn () => let val a = m34 () in A.modifyi A.RowMajor (fn (_, _, x) => e ((code x + 8) mod 16)) (region (a, 1, 2, NONE, NONE)); a end)
  val () = eqT (lab "modifyi/order-RowMajor", [(1, 1, 5), (1, 2, 6), (2, 1, 9), (2, 2, 10)],
                fn () => let val (f, seen) = codedT (trace fi) in A.modifyi A.RowMajor f (inner (m34 ())); seen () end)
  val () = eqT (lab "modifyi/order-ColMajor", [(1, 1, 5), (2, 1, 9), (1, 2, 6), (2, 2, 10)],
                fn () => let val (f, seen) = codedT (trace fi) in A.modifyi A.ColMajor f (inner (m34 ())); seen () end)
  val () = eqA (lab "modifyi/RowMajor-counter", [[0, 1, 2], [3, 4, 5]],
                fn () => let val a = m23 () in A.modifyi A.RowMajor (counter ()) (whole a); a end)
  val () = eqA (lab "modifyi/ColMajor-counter", [[0, 2, 4], [1, 3, 5]],
                fn () => let val a = m23 () in A.modifyi A.ColMajor (counter ()) (whole a); a end)
  val () = List.app (fn (n, reg) =>
             T.raises (lab ("modifyi/Subscript-" ^ n), T.isSubscript, fn () => A.modifyi A.RowMajor (fn _ => e 14) (reg (m34 ())))) invalid
  val () = T.raises (lab "modifyi/Subscript-ColMajor-too-many-rows", T.isSubscript,
                     fn () => A.modifyi A.ColMajor (fn _ => e 14) (region (m34 (), 2, 0, SOME 2, NONE)))
  val () = T.raises (lab "modifyi/Subscript-ColMajor-too-many-cols", T.isSubscript,
                     fn () => A.modifyi A.ColMajor (fn _ => e 14) (region (m34 (), 0, 3, NONE, SOME 2)))
  (* double: the sample 2 * code a mod 16 *)
  fun double a = e ((2 * code a) mod 16)
  val () = eqA (lab "modify/RowMajor", [[2, 4, 6], [8, 10, 12]], fn () => let val a = m23 () in A.modify A.RowMajor double a; a end)
  val () = eqA (lab "modify/ColMajor", [[2, 4, 6], [8, 10, 12]], fn () => let val a = m23 () in A.modify A.ColMajor double a; a end)
  val () = eqL (lab "modify/order-RowMajor", [1, 2, 3, 4, 5, 6],
                fn () => let val (f, seen) = coded (trace double) in A.modify A.RowMajor f (m23 ()); seen () end)
  val () = eqL (lab "modify/order-ColMajor", [1, 4, 2, 5, 3, 6],
                fn () => let val (f, seen) = coded (trace double) in A.modify A.ColMajor f (m23 ()); seen () end)
  val () = eqA (lab "modify/ColMajor-counter", [[0, 2, 4], [1, 3, 5]], fn () => let val a = m23 () in A.modify A.ColMajor (counter ()) a; a end)
  val () = eqD (lab "modify/no-rows", (0, 3), fn () => let val a = zeros (0, 3) in A.modify A.RowMajor double a; A.dimensions a end)
  (* 1 2 3 / 4 5 6 doubled twice: 4 8 12 / 16 20 24, modulo 16 *)
  val () = eqA (lab "modify/twice", [[4, 8, 12], [0, 4, 8]],
                fn () => let val a = m23 () in A.modify A.RowMajor double a; A.modify A.ColMajor double a; a end)

  (* The page does not say whether f is applied to some elements before
     Subscript is raised for a region that is not valid; the test takes it that
     it is not, as the condition is on the region alone. *)
  val () = eqT (lab "appi/Subscript-before-f", [],
                fn () => let val (f, seen) = codedT (trace (fn _ => ()))
                         in A.appi A.RowMajor f (region (m34 (), 2, 0, SOME 2, NONE)) handle Subscript => ();
                            A.appi A.ColMajor f (region (m34 (), 0, 3, NONE, SOME 2)) handle Subscript => ();
                            seen ()
                         end)
  val () = eqT (lab "foldi/Subscript-before-f", [],
                fn () => let val (f, seen) = codedT (trace (fn _ => ()))
                         in A.foldi A.RowMajor (fn (i, j, a, ()) => f (i, j, a)) () (region (m34 (), 2, 0, SOME 2, NONE)) handle Subscript => ();
                            A.foldi A.ColMajor (fn (i, j, a, ()) => f (i, j, a)) () (region (m34 (), 0, 3, NONE, SOME 2)) handle Subscript => ();
                            seen ()
                         end)
  val () = eqA (lab "modifyi/Subscript-changes-nothing", l34,
                fn () => let val a = m34 ()
                         in A.modifyi A.RowMajor (fn _ => e 14) (region (a, 2, 0, SOME 2, NONE)) handle Subscript => ();
                            A.modifyi A.ColMajor (fn _ => e 14) (region (a, 0, 3, NONE, SOME 2)) handle Subscript => ();
                            a
                         end)

  (* ---- array: "As usual, arrays have the equality property that two arrays
     are equal only if they are the same array, i.e., created by the same call
     to a primitive array constructor such as array, fromList, etc.; otherwise
     they are not equal. This also holds for arrays of zero length." ---- *)
  val () = eqB (lab "array/same-array-is-equal", true, fn () => let val a = m23 () in a = a end)
  val () = eqB (lab "array/alias-is-equal", true, fn () => let val a = m23 () val b = a in a = b end)
  val () = eqB (lab "array/equal-after-update", true, fn () => let val a = m23 () val b = a in A.update (a, 0, 0, e 9); a = b end)
  val () = eqB (lab "array/same-elements-not-equal", false, fn () => A.array (2, 3, e 7) = A.array (2, 3, e 7))
  val () = eqB (lab "fromList/same-elements-not-equal", false, fn () => m23 () = m23 ())
  val () = eqB (lab "tabulate/same-elements-not-equal", false,
                fn () => A.tabulate A.RowMajor (2, 2, fn _ => e 0) = A.tabulate A.RowMajor (2, 2, fn _ => e 0))
  val () = eqB (lab "array/zero-length-same", true, fn () => let val a = zeros (0, 0) in a = a end)
  val () = eqB (lab "array/zero-length-not-equal", false, fn () => zeros (0, 0) = zeros (0, 0))
  val () = eqB (lab "fromList/zero-length-not-equal", false, fn () => A.fromList [] = A.fromList [])
end

(* The laws of the page on pseudo-random arrays and regions, against lists of
   rows of codes: those of the samples whose array, valid region or
   destination has elements (empty = false), or those of the other samples
   (empty = true). A test applies the second in a section of its own, with
   TestMonoArray2EmptyFn: SML/NJ 110.79 traverses a row, or a column, of an
   Array2 region that has none, even beyond the end of the array. `elems`
   holds at least 16 distinct samples, as for TestMonoArray2Fn. *)
functor TestMonoArray2LawsFn (structure A : SPEC_MONO_ARRAY2
                              structure V : SPEC_MONO_VECTOR where type vector = A.vector where type elem = A.elem
                              val name : string
                              val elems : A.elem vector
                              val show : A.elem -> string
                              val same : A.elem * A.elem -> bool
                              val empty : bool) =
struct
  fun lab s = name ^ "." ^ s

  val samples = Vector.length elems
  fun e i = Vector.sub (elems, i)
  fun code x =
    let fun go i = if i >= samples then ~1 else if same (e i, x) then i else go (i + 1)
    in go 0 end
  fun showCode i = if i >= 0 andalso i < samples then show (e i) else "?"

  val eqI = T.eq T.int
  val eqL = T.eq (T.list showCode)
  val eqD = T.eq (T.pair (T.int, T.int))
  val eqM = T.eq (T.list (T.list showCode))
  val eqMO = T.eq (T.option (T.list (T.list showCode)))
  val eqTO = T.eq (T.option (T.list (T.triple (T.int, T.int, showCode))))

  fun vectorToList v = List.tabulate (V.length v, fn i => code (V.sub (v, i)))
  fun rows (a : A.array) : int list list =
    List.tabulate (A.nRows a, fn i => List.tabulate (A.nCols a, fn j => code (A.sub (a, i, j))))
  fun eqA (label, expected : int list list, f : unit -> A.array) : unit =
    eqM (label, expected, fn () => rows (f ()))
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end
  fun region (a, r, c, nr, nc) : A.region = {base = a, row = r, col = c, nrows = nr, ncols = nc}

  fun el (m : int list list) (i, j) = List.nth (List.nth (m, i), j)
  fun randomRows (r, c) = List.tabulate (r, fn _ => List.tabulate (c, fn _ => T.range (0, 15)))
  (* an array of r rows and c columns of the samples m (fromList cannot say c
     when r = 0) *)
  fun make (r, c, m) = A.tabulate A.RowMajor (r, c, fn p => e (el m p))
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

  (* the same 50 samples for both: each takes those of its kind *)
  val () = T.seed 10
  val () = T.repeat (50, fn k =>
    let
      val tag = (if empty then "model-empty-" else "model-") ^ Int.toString k
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
      val x = T.range (0, 15)
      (* a region that is valid more often than not *)
      val r0 = T.range (if T.range (0, 9) = 0 then ~1 else 0, r + (if T.range (0, 9) = 0 then 1 else 0))
      val c0 = T.range (if T.range (0, 9) = 0 then ~1 else 0, c + (if T.range (0, 9) = 0 then 1 else 0))
      val nr = randomSize (r - r0)
      val nc = randomSize (c - c0)
      fun reg b = region (b, r0, c0, nr, nc)
      val spans = case (span (r, r0, nr), span (c, c0, nc)) of (SOME rs, SOME cs) => SOME (rs, cs) | _ => NONE
      (* fi on codes, gi and g on codes and ints *)
      val fi = fn (i, j, a) => (7 * i + 3 * j + a) mod 16
      val gi = fn (i, j, a, b) => i * a + j - 2 * b
      val g = fn (a, b) => a - 2 * b
      val h = fn a => (5 * a + 3) mod 16
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
      if emptyArray <> empty then () else (
      eqD (lab ("dimensions/" ^ tag), (r, c), fn () => A.dimensions (a ()));
      eqI (lab ("nRows/" ^ tag), r, fn () => A.nRows (a ()));
      eqI (lab ("nCols/" ^ tag), c, fn () => A.nCols (a ()));
      eqA (lab ("tabulate/" ^ tag), m, fn () => A.tabulate tr (r, c, fn p => e (el m p)));
      eqA (lab ("fromList/" ^ tag), m, fn () => A.fromList (List.map (List.map e) m));
      eqA (lab ("array/" ^ tag), List.tabulate (r, fn _ => List.tabulate (c, fn _ => x)), fn () => A.array (r, c, e x));
      (if ok
       then (eqI (lab ("sub/" ^ tag), el m (i, j), fn () => code (A.sub (a (), i, j)));
             eqA (lab ("update/" ^ tag),
                  List.tabulate (r, fn i' => List.tabulate (c, fn j' => if i' = i andalso j' = j then x else el m (i', j'))),
                  fn () => let val b = a () in A.update (b, i, j, e x); b end))
       else (T.raises (lab ("sub/" ^ tag), T.isSubscript, fn () => A.sub (a (), i, j));
             T.raises (lab ("update/" ^ tag), T.isSubscript, fn () => A.update (a (), i, j, e x))));
      (if 0 <= i andalso i < r
       then eqL (lab ("row/" ^ tag), List.nth (m, i), fn () => vectorToList (A.row (a (), i)))
       else T.raises (lab ("row/" ^ tag), T.isSubscript, fn () => A.row (a (), i)));
      (if 0 <= j andalso j < c
       then eqL (lab ("column/" ^ tag), List.map (fn row => List.nth (row, j)) m, fn () => vectorToList (A.column (a (), j)))
       else T.raises (lab ("column/" ^ tag), T.isSubscript, fn () => A.column (a (), j)));
      eqL (lab ("app/" ^ tag), List.map (el m) all,
           fn () => let val (f, seen) = trace (fn _ => ()) in A.app tr f (a ()); List.map code (seen ()) end);
      eqI (lab ("fold/" ^ tag), List.foldl g 1 (List.map (el m) all), fn () => A.fold tr (fn (a, b) => g (code a, b)) 1 (a ()));
      eqA (lab ("modify/" ^ tag), List.map (List.map h) m,
           fn () => let val b = a () in A.modify tr (fn a => e (h (code a))) b; b end));
      if emptyRegion <> empty then () else (
      eqTO (lab ("appi/" ^ tag), Option.map (fn s => List.map (fn (i, j) => (i, j, el m (i, j))) (cells tr s)) spans,
            fn () => let val (f, seen) = trace (fn _ => ())
                     in A.appi tr f (reg (a ())); SOME (List.map (fn (i, j, a) => (i, j, code a)) (seen ())) end
                     handle Subscript => NONE);
      T.eq (T.option T.int) (lab ("foldi/" ^ tag),
                             Option.map (fn s => List.foldl (fn ((i, j), b) => gi (i, j, el m (i, j), b)) 1 (cells tr s)) spans,
                             fn () => SOME (A.foldi tr (fn (i, j, a, b) => gi (i, j, code a, b)) 1 (reg (a ()))) handle Subscript => NONE);
      eqMO (lab ("modifyi/" ^ tag),
            Option.map (fn (rs, cs) => List.tabulate (r, fn i => List.tabulate (c, fn j =>
                          if inSpan rs i andalso inSpan cs j then fi (i, j, el m (i, j)) else el m (i, j)))) spans,
            fn () => let val b = a () in A.modifyi tr (fn (i, j, a) => e (fi (i, j, code a))) (reg b); SOME (rows b) end
                     handle Subscript => NONE));
      if emptyCopy <> empty then () else (
      eqMO (lab ("copy/" ^ tag), copied (d, (r2, c2), there),
            fn () => let val b = make (r2, c2, d)
                     in A.copy {src = reg (a ()), dst = b, dst_row = #1 there, dst_col = #2 there}; SOME (rows b) end
                     handle Subscript => NONE);
      eqMO (lab ("copy/within-" ^ tag), copied (m, (r, c), here),
            fn () => let val b = a ()
                     in A.copy {src = reg b, dst = b, dst_row = #1 here, dst_col = #2 here}; SOME (rows b) end
                     handle Subscript => NONE))
    end)
end

(* Arrays and valid regions without elements: nothing is traversed, nothing
   is copied. The regions are for an array of 3 rows and 4 columns;
   "0 <= #row reg <= nRows (#base reg)" allows a region to start at the end of
   the array. `elems` holds at least 16 distinct samples. *)
functor TestMonoArray2EmptyFn (structure A : SPEC_MONO_ARRAY2
                               val name : string
                               val elems : A.elem vector
                               val show : A.elem -> string
                               val same : A.elem * A.elem -> bool) =
struct
  fun lab s = name ^ "." ^ s

  val samples = Vector.length elems
  fun e i = Vector.sub (elems, i)
  fun code x =
    let fun go i = if i >= samples then ~1 else if same (e i, x) then i else go (i + 1)
    in go 0 end
  fun showCode i = if i >= 0 andalso i < samples then show (e i) else "?"

  val eqI = T.eq T.int
  val eqM = T.eq (T.list (T.list showCode))
  val eqT = T.eq (T.list (T.triple (T.int, T.int, showCode)))
  fun rows (a : A.array) : int list list =
    List.tabulate (A.nRows a, fn i => List.tabulate (A.nCols a, fn j => code (A.sub (a, i, j))))
  fun eqA (label, expected : int list list, f : unit -> A.array) : unit =
    eqM (label, expected, fn () => rows (f ()))
  fun trace (f : 'a -> 'b) : ('a -> 'b) * (unit -> 'a list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end
  fun region (a, r, c, nr, nc) : A.region = {base = a, row = r, col = c, nrows = nr, ncols = nc}

  val l34 = [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]]
  fun m34 () = A.fromList (List.map (List.map e) l34)
  val z = 15
  fun copyTo (src, (r, c), dr, dc) =
    let val d = A.array (r, c, e z) in A.copy {src = src, dst = d, dst_row = dr, dst_col = dc}; d end
  fun appi tr reg =
    let val (f, seen) = trace (fn _ => ())
    in A.appi tr f reg; List.map (fn (i, j, a) => (i, j, code a)) (seen ()) end

  val nothing : (string * (A.array -> A.region)) list =
    [("rows-at-the-end", fn a => region (a, 3, 0, NONE, NONE)),
     ("cols-at-the-end", fn a => region (a, 0, 4, NONE, NONE)),
     ("zero-nrows", fn a => region (a, 1, 1, SOME 0, SOME 2)),
     ("zero-ncols", fn a => region (a, 1, 1, SOME 2, SOME 0)),
     ("zero-nrows-ncols-at-the-end", fn a => region (a, 3, 4, SOME 0, SOME 0))]
  val () = List.app (fn (n, reg) =>
             (eqT (lab ("appi/nothing-RowMajor-" ^ n), [], fn () => appi A.RowMajor (reg (m34 ())));
              eqT (lab ("appi/nothing-ColMajor-" ^ n), [], fn () => appi A.ColMajor (reg (m34 ())));
              eqI (lab ("foldi/nothing-RowMajor-" ^ n), 42,
                   fn () => A.foldi A.RowMajor (fn (i, j, a, b) => i + j + code a + b) 42 (reg (m34 ())));
              eqI (lab ("foldi/nothing-ColMajor-" ^ n), 42,
                   fn () => A.foldi A.ColMajor (fn (i, j, a, b) => i + j + code a + b) 42 (reg (m34 ())));
              eqA (lab ("modifyi/nothing-RowMajor-" ^ n), l34,
                   fn () => let val a = m34 () in A.modifyi A.RowMajor (fn _ => e 14) (reg a); a end);
              eqA (lab ("modifyi/nothing-ColMajor-" ^ n), l34,
                   fn () => let val a = m34 () in A.modifyi A.ColMajor (fn _ => e 14) (reg a); a end);
              eqA (lab ("copy/nothing-" ^ n), [[z, z, z, z, z], [z, z, z, z, z], [z, z, z, z, z], [z, z, z, z, z]],
                   fn () => copyTo (reg (m34 ()), (4, 5), 1, 0))))
             nothing
  val () = eqA (lab "copy/nothing-to-the-end-of-dst", [[z, z], [z, z]],
                fn () => copyTo (region (m34 (), 1, 1, SOME 0, SOME 0), (2, 2), 2, 2))
  (* the derived destination region of a source region without elements can be
     invalid too *)
  val () = T.raises (lab "copy/Subscript-dst-nothing-row-beyond", T.isSubscript,
                     fn () => copyTo (region (m34 (), 1, 1, SOME 0, SOME 0), (2, 2), 3, 0))
  val () = T.raises (lab "copy/Subscript-dst-nothing-cols-too-far", T.isSubscript,
                     fn () => copyTo (region (m34 (), 1, 1, SOME 0, SOME 2), (2, 2), 0, 1))
end

(* Subscript, not Overflow: the conditions of the page hold for the numbers
   below, although the position in a representation by one sequence, or the
   end of the region, does not exist as an int. The numbers are read from
   refs: the compiler of Poly/ML 5.7.1 stops with "Overflow unexpectedly raised
   while compiling" when they are constants. *)
functor TestMonoArray2OverflowFn (structure A : SPEC_MONO_ARRAY2
                                  val name : string
                                  val elem : A.elem) =
struct
  fun lab s = name ^ "." ^ s
  val extremes = ref (case Int.maxInt of SOME m => m | NONE => 1073741823, case Int.minInt of SOME m => m | NONE => ~1073741824)
  fun most () = #1 (!extremes)
  fun least () = #2 (!extremes)
  fun region (a, r, c, nr, nc) : A.region = {base = a, row = r, col = c, nrows = nr, ncols = nc}
  fun m34 () = A.array (3, 4, elem)
  fun inner a = region (a, 1, 1, SOME 2, SOME 2)
  fun copyTo (src, (r, c), dr, dc) =
    let val d = A.array (r, c, elem) in A.copy {src = src, dst = d, dst_row = dr, dst_col = dc}; d end
  val () = T.raises (lab "sub/Subscript-not-Overflow-row", T.isSubscript, fn () => A.sub (m34 (), most (), 1))
  val () = T.raises (lab "sub/Subscript-not-Overflow-column", T.isSubscript, fn () => A.sub (m34 (), 1, most ()))
  val () = T.raises (lab "sub/Subscript-not-Overflow-both", T.isSubscript, fn () => A.sub (m34 (), most (), most ()))
  val () = T.raises (lab "sub/Subscript-not-Overflow-least", T.isSubscript, fn () => A.sub (m34 (), least (), least ()))
  val () = T.raises (lab "update/Subscript-not-Overflow-row", T.isSubscript, fn () => A.update (m34 (), most (), 1, elem))
  val () = T.raises (lab "update/Subscript-not-Overflow-column", T.isSubscript, fn () => A.update (m34 (), 1, most (), elem))
  val () = T.raises (lab "update/Subscript-not-Overflow-least", T.isSubscript, fn () => A.update (m34 (), least (), least (), elem))
  val () = T.raises (lab "row/Subscript-not-Overflow", T.isSubscript, fn () => A.row (m34 (), most ()))
  val () = T.raises (lab "column/Subscript-not-Overflow", T.isSubscript, fn () => A.column (m34 (), most ()))
  val extreme : (string * (A.array -> A.region)) list =
    [("sum-nrows", fn a => region (a, 1, 0, SOME (most ()), NONE)),
     ("sum-ncols", fn a => region (a, 0, 1, NONE, SOME (most ()))),
     ("sum-row", fn a => region (a, most (), 0, SOME 1, NONE)),
     ("sum-col", fn a => region (a, 0, most (), NONE, SOME 1)),
     ("row", fn a => region (a, most (), 0, NONE, NONE)),
     ("col", fn a => region (a, 0, most (), NONE, NONE)),
     ("least-row", fn a => region (a, least (), 0, SOME (most ()), NONE)),
     ("least-ncols", fn a => region (a, 0, 1, NONE, SOME (least ())))]
  val () = List.app (fn (n, reg) =>
             (T.raises (lab ("appi/Subscript-not-Overflow-" ^ n), T.isSubscript, fn () => A.appi A.RowMajor (fn _ => ()) (reg (m34 ())));
              T.raises (lab ("foldi/Subscript-not-Overflow-" ^ n), T.isSubscript,
                        fn () => A.foldi A.ColMajor (fn (_, _, _, b) => b) 0 (reg (m34 ())));
              T.raises (lab ("modifyi/Subscript-not-Overflow-" ^ n), T.isSubscript, fn () => A.modifyi A.RowMajor (fn (_, _, x) => x) (reg (m34 ())));
              T.raises (lab ("copy/Subscript-not-Overflow-src-" ^ n), T.isSubscript, fn () => copyTo (reg (m34 ()), (8, 8), 0, 0))))
             extreme
  val () = T.raises (lab "copy/Subscript-not-Overflow-dst-sum-row", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), most (), 0))
  val () = T.raises (lab "copy/Subscript-not-Overflow-dst-sum-col", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), 0, most ()))
  val () = T.raises (lab "copy/Subscript-not-Overflow-dst-least", T.isSubscript, fn () => copyTo (inner (m34 ()), (4, 5), least (), least ()))
end

(* Size: "If r < 0, c < 0 or the resulting array size is too large, the Size
   exception is raised." An array of Int.maxInt rows and as many, or 2,
   columns is too large everywhere: the number of its elements is not an int.
   The function that is tabulated gives up after 1000 applications. *)
functor TestMonoArray2SizeFn (structure A : SPEC_MONO_ARRAY2
                              val name : string
                              val elem : A.elem) =
struct
  fun lab s = name ^ "." ^ s
  val huge = case Int.maxInt of SOME m => m | NONE => 1073741823
  fun giveUp () = let val n = ref 0 in fn _ => (n := !n + 1; if !n > 1000 then raise Fail "f applied before Size" else elem) end
  val () = T.raises (lab "array/Size-too-large", T.isSize, fn () => A.array (huge, huge, elem))
  val () = T.raises (lab "array/Size-too-large-rows", T.isSize, fn () => A.array (huge, 2, elem))
  val () = T.raises (lab "array/Size-too-large-columns", T.isSize, fn () => A.array (2, huge, elem))
  val () = T.raises (lab "tabulate/Size-too-large-RowMajor", T.isSize, fn () => A.tabulate A.RowMajor (huge, huge, giveUp ()))
  val () = T.raises (lab "tabulate/Size-too-large-ColMajor", T.isSize, fn () => A.tabulate A.ColMajor (2, huge, giveUp ()))
end
