(* SML/NJ: Array2 without rows or columns. An array of no elements loses
   its dimensions, row accepts the index nrows, and a traversal of a region
   without rows (RowMajor) or columns (ColMajor) visits one row or column.
   Run: sml bug.sml *)
fun dims (r, c) = "(" ^ Int.toString r ^ ", " ^ Int.toString c ^ ")"
fun show (name, got, expected) =
  print (concat [name, " = ", got, ", expected ", expected, ": ",
                 if got = expected then "ok" else "WRONG", "\n"])

val () = show ("dimensions (array (0, 5, 0))", dims (Array2.dimensions (Array2.array (0, 5, 0))), "(0, 5)")
val () = show ("dimensions (array (4, 0, 0))", dims (Array2.dimensions (Array2.array (4, 0, 0))), "(4, 0)")

val a = Array2.tabulate Array2.RowMajor (3, 3, fn (i, j) => 10 * i + j)
val () = show ("row (array (0, 3, 0), 0)",
               (Int.toString (Vector.length (Array2.row (Array2.array (0, 3, 0), 0))) handle Subscript => "Subscript"),
               "Subscript")

(* a region of a 3 x 3 array that starts at row 1 and has no rows; and one
   that starts at column 1 and has no columns *)
val noRows : int Array2.region = {base = a, row = 1, col = 0, nrows = SOME 0, ncols = NONE}
val noCols : int Array2.region = {base = a, row = 0, col = 1, nrows = NONE, ncols = SOME 0}
fun count order region = Array2.foldi order (fn (_, _, _, n) => n + 1) 0 region
val () = show ("elements foldi RowMajor visits in a region without rows",
               Int.toString (count Array2.RowMajor noRows), "0")
val () = show ("elements foldi ColMajor visits in a region without columns",
               Int.toString (count Array2.ColMajor noCols), "0")
val () = Array2.modifyi Array2.RowMajor (fn (_, _, x) => x + 100) noRows
val () = show ("sub (a, 1, 0) after modifyi of a region without rows",
               Int.toString (Array2.sub (a, 1, 0)), "10")

(* The same at the end of the array: the region of a 3 x 3 array that
   starts at row 3 is valid and has no rows, and a RowMajor traversal of it
   visits row 3, past the end of the array (it reads with unsafeSub, and
   modifyi writes with unsafeUpdate there). *)
val atEnd : int Array2.region = {base = a, row = 3, col = 0, nrows = NONE, ncols = NONE}
val () = show ("elements foldi RowMajor visits in the empty region at the end",
               Int.toString (count Array2.RowMajor atEnd), "0")

(* An array with rows and no columns that keeps its dimensions (tabulate
   keeps them): the traversals of the whole array in ColMajor order go
   through its rows anyway, reading -- and modify writing -- past the end
   of the empty array. *)
val e = Array2.tabulate Array2.RowMajor (3, 0, fn _ => 0)
val visits = ref 0
fun visit x = (visits := !visits + 1; x)
val () = (visits := 0; Array2.app Array2.ColMajor (ignore o visit) e)
val () = show ("elements app ColMajor visits in tabulate (3, 0, f)", Int.toString (!visits), "0")
val () = show ("elements fold ColMajor visits in tabulate (3, 0, f)",
               Int.toString (Array2.fold Array2.ColMajor (fn (_, n) => n + 1) 0 e), "0")
val () = (visits := 0; Array2.modify Array2.ColMajor visit e)
val () = show ("elements modify ColMajor visits in tabulate (3, 0, f)", Int.toString (!visits), "0")
