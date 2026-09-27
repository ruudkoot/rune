(* MLKit: Array2.copy into an array whose dimensions differ from those of
   the source region's base array *)
fun try (what : string) (f : unit -> string) =
  print (what ^ ":\n    " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")
fun show (a : int Array2.array) : string =
  "[" ^ String.concatWith " / "
    (List.tabulate (Array2.nRows a, fn i =>
       String.concatWith " " (List.tabulate (Array2.nCols a, fn j => Int.toString (Array2.sub (a, i, j)))))) ^ "]"

(* 3 rows and 4 columns; the source region is its rows 1-2 and columns 1-2,
   11 12 / 21 22 *)
fun src () = Array2.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
fun inner () : int Array2.region = {base = src (), row = 1, col = 1, nrows = SOME 2, ncols = SOME 2}
fun whole () : int Array2.region = {base = src (), row = 0, col = 0, nrows = NONE, ncols = NONE}
(* copyTo (region, (rows, cols), dst_row, dst_col): a zero array of rows x
   cols after the copy of region to (dst_row, dst_col) *)
fun copyTo (reg, (r, c), dr, dc) =
  let val d = Array2.array (r, c, 0)
  in Array2.copy {src = reg, dst = d, dst_row = dr, dst_col = dc}; "no exception, dst = " ^ show d end

val () = try "inner to (1, 2) of 4 x 5, expected [0 0 0 0 0 / 0 0 11 12 0 / 0 0 21 22 0 / 0 0 0 0 0]"
             (fn () => copyTo (inner (), (4, 5), 1, 2))
val () = try "inner to (2, 3) of 4 x 5, expected [0 0 0 0 0 / 0 0 0 0 0 / 0 0 0 11 12 / 0 0 0 21 22]"
             (fn () => copyTo (inner (), (4, 5), 2, 3))
val () = try "whole 3 x 4 to (1, 1) of 4 x 5, expected [0 0 0 0 0 / 0 0 1 2 3 / 0 10 11 12 13 / 0 20 21 22 23]"
             (fn () => copyTo (whole (), (4, 5), 1, 1))
val () = try "whole 3 x 4 to (0, 0) of 3 x 3, expected Subscript"
             (fn () => copyTo (whole (), (3, 3), 0, 0))
val () = try "inner to (0, 0) of 0 x 5, expected Subscript"
             (fn () => copyTo (inner (), (0, 5), 0, 0))
val () = try "inner to (maxInt, 0) of 4 x 5, expected Subscript"
             (fn () => copyTo (inner (), (4, 5), valOf Int.maxInt, 0))

(* The writes of a copy that should have raised Subscript land outside dst:
   here in another array, e. *)
val s = src ()
val d = Array2.array (1, 1, 0)
val e = Array2.array (2, 2, 7)
val () = print ("e before a copy into d: " ^ show e ^ "\n")
val () = try "copy of a 2 x 3 region into the 1 x 1 array d, expected Subscript"
             (fn () => (Array2.copy {src = {base = s, row = 0, col = 0, nrows = SOME 2, ncols = SOME 3},
                                     dst = d, dst_row = 0, dst_col = 0};
                        "no exception"))
val () = print ("e after the copy into d: " ^ show e ^ "\n")
