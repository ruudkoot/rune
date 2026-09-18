(* Array2: two-dimensional arrays, stored row by row in one array. *)
structure Array2 =
struct
  (* equality is that of the data array: identity *)
  type 'a array = {data : 'a Array.array, rows : int, cols : int}
  type 'a region = {base : 'a array, row : int, col : int, nrows : int option, ncols : int option}
  datatype traversal = RowMajor | ColMajor

  fun checkSize (r, c) =
    if r < 0 orelse c < 0 orelse (c > 0 andalso r > Array.maxLen div c) then raise Size else ()

  fun array (r, c, init) : 'a array =
    (checkSize (r, c); {data = Array.array (r * c, init), rows = r, cols = c})

  fun dimensions ({rows, cols, ...} : 'a array) = (rows, cols)
  fun nRows ({rows, ...} : 'a array) = rows
  fun nCols ({cols, ...} : 'a array) = cols

  fun sub ({data, rows, cols} : 'a array, i, j) =
    if i < 0 orelse j < 0 orelse i >= rows orelse j >= cols then raise Subscript
    else Array.sub (data, i * cols + j)
  fun update ({data, rows, cols} : 'a array, i, j, x) =
    if i < 0 orelse j < 0 orelse i >= rows orelse j >= cols then raise Subscript
    else Array.update (data, i * cols + j, x)

  (* rows of equal length, in row major form *)
  fun fromList (l : 'a list list) : 'a array =
    let
      val r = List.length l
      val c = case l of [] => 0 | first :: _ => List.length first
      val () = if List.all (fn row => List.length row = c) l then () else raise Size
      val () = checkSize (r, c)
    in {data = Array.fromList (List.concat l), rows = r, cols = c} end

  (* count (n, f): f 0, ..., f (n - 1) in that order *)
  fun count (n, f) = let fun go k = if k >= n then () else (f k; go (k + 1)) in go 0 end

  (* f at every position of nr rows and nc columns from (r0, c0), in the order of the traversal *)
  fun traverse RowMajor (r0, c0, nr, nc) f = count (nr, fn i => count (nc, fn j => f (r0 + i, c0 + j)))
    | traverse ColMajor (r0, c0, nr, nc) f = count (nc, fn j => count (nr, fn i => f (r0 + i, c0 + j)))

  (* "The elements are initialized in the traversal order": f (0, 0) is the
     first in both orders and gives the array its initial element. *)
  fun tabulate trv (r, c, f) : 'a array =
    (checkSize (r, c);
     if r = 0 orelse c = 0 then {data = Array.fromList [], rows = r, cols = c}
     else
       let
         val arr = array (r, c, f (0, 0))
       in
         traverse trv (0, 0, r, c) (fn (i, j) => if i = 0 andalso j = 0 then () else update (arr, i, j, f (i, j)));
         arr
       end)

  fun row (arr : 'a array, i) =
    if i < 0 orelse i >= nRows arr then raise Subscript
    else Vector.tabulate (nCols arr, fn j => sub (arr, i, j))
  fun column (arr : 'a array, j) =
    if j < 0 orelse j >= nCols arr then raise Subscript
    else Vector.tabulate (nRows arr, fn i => sub (arr, i, j))

  (* The rectangle of a valid region, (first row, first column, rows, columns);
     Subscript otherwise. No sum here can overflow. *)
  fun rectangle ({base, row, col, nrows, ncols} : 'a region) =
    let
      fun extent (start, count, limit) =
        if start < 0 orelse start > limit then raise Subscript
        else
          case count of
            NONE => limit - start
          | SOME n => if n < 0 orelse n > limit - start then raise Subscript else n
      val nr = extent (row, nrows, nRows base)
      val nc = extent (col, ncols, nCols base)
    in (row, col, nr, nc) end

  fun whole (arr : 'a array) : 'a region = {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}

  fun appi trv f (reg : 'a region) =
    let val base = #base reg
    in traverse trv (rectangle reg) (fn (i, j) => f (i, j, sub (base, i, j))) end
  fun app trv f arr = appi trv (fn (_, _, x) => f x) (whole arr)

  fun foldi trv f init (reg : 'a region) =
    let
      val base = #base reg
      val acc = ref init
    in
      traverse trv (rectangle reg) (fn (i, j) => acc := f (i, j, sub (base, i, j), !acc));
      !acc
    end
  fun fold trv f init arr = foldi trv (fn (_, _, x, acc) => f (x, acc)) init (whole arr)

  fun modifyi trv f (reg : 'a region) =
    let val base = #base reg
    in traverse trv (rectangle reg) (fn (i, j) => update (base, i, j, f (i, j, sub (base, i, j)))) end
  fun modify trv f arr = modifyi trv (fn (_, _, x) => f x) (whole arr)

  (* Rows are copied towards the side they move from, and so are the elements
     of a row, so that an element is read before it is overwritten when dst is
     the base of src and the regions overlap. *)
  fun copy {src : 'a region, dst : 'a array, dst_row, dst_col} =
    let
      val base = #base src
      val (r0, c0, nr, nc) = rectangle src
      val () = if dst_row < 0 orelse dst_col < 0 orelse dst_row > nRows dst - nr orelse dst_col > nCols dst - nc
               then raise Subscript else ()
      fun order (n, forwards) f = count (n, fn k => f (if forwards then k else n - 1 - k))
    in
      order (nr, dst_row <= r0) (fn i =>
        order (nc, dst_col <= c0) (fn j =>
          update (dst, dst_row + i, dst_col + j, sub (base, r0 + i, c0 + j))))
    end
end
