(* MLKit: IntArray2.copy (and the copy of every MONO_ARRAY2 structure, all
   made by the functor WordArray2) into an array whose dimensions differ from
   those of the source region's base array, and from invalid source regions *)
structure A = IntArray2
fun try (what : string) (f : unit -> string) =
  print (what ^ ":\n    " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")
fun show (a : A.array) : string =
  "[" ^ String.concatWith " / "
    (List.tabulate (A.nRows a, fn i =>
       String.concatWith " " (List.tabulate (A.nCols a, fn j => Int.toString (A.sub (a, i, j)))))) ^ "]"

(* 3 rows and 4 columns; the region inner is its rows 1-2 and columns 1-2,
   11 12 / 21 22 *)
fun src () = A.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
fun reg (row, col, nrows, ncols) : A.region = {base = src (), row = row, col = col, nrows = nrows, ncols = ncols}
fun inner () = reg (1, 1, SOME 2, SOME 2)
fun whole () = reg (0, 0, NONE, NONE)
fun copyTo (r, (m, n), dr, dc) =
  let val d = A.array (m, n, 0)
  in A.copy {src = r, dst = d, dst_row = dr, dst_col = dc}; "no exception, dst = " ^ show d end
val maxInt = valOf Int.maxInt

(* the destination region is valid in dst *)
val () = try "inner to (2, 3) of 4 x 5, expected [0 0 0 0 0 / 0 0 0 0 0 / 0 0 0 11 12 / 0 0 0 21 22]"
             (fn () => copyTo (inner (), (4, 5), 2, 3))
val () = try "whole 3 x 4 to (1, 1) of 4 x 5, expected [0 0 0 0 0 / 0 0 1 2 3 / 0 10 11 12 13 / 0 20 21 22 23]"
             (fn () => copyTo (whole (), (4, 5), 1, 1))
(* the destination region is not valid in dst *)
val () = try "whole 3 x 4 to (0, 0) of 3 x 3, expected Subscript"
             (fn () => copyTo (whole (), (3, 3), 0, 0))
val () = try "inner to (0, 0) of 0 x 5, expected Subscript"
             (fn () => copyTo (inner (), (0, 5), 0, 0))
val () = try "inner to (maxInt, 0) of 4 x 5, expected Subscript"
             (fn () => copyTo (inner (), (4, 5), maxInt, 0))
(* the source region is not valid *)
val () = try "source row 4, nrows NONE (row > nRows), expected Subscript"
             (fn () => copyTo (reg (4, 0, NONE, NONE), (8, 8), 0, 0))
val () = try "source row 1, nrows SOME ~1, expected Subscript"
             (fn () => copyTo (reg (1, 0, SOME ~1, NONE), (8, 8), 0, 0))
val () = try "source row 1, nrows SOME maxInt, expected Subscript"
             (fn () => copyTo (reg (1, 0, SOME maxInt, NONE), (8, 8), 0, 0))
(* the same in RealArray2 *)
val () = try "RealArray2: 1 x 1 to (1, 1) of 2 x 2, expected [0.0 0.0 / 0.0 1.0]"
             (fn () => let val d = RealArray2.array (2, 2, 0.0)
                       in RealArray2.copy {src = {base = RealArray2.array (1, 1, 1.0), row = 0, col = 0, nrows = NONE, ncols = NONE},
                                           dst = d, dst_row = 1, dst_col = 1};
                          "no exception, dst = [" ^ String.concatWith " / "
                            (List.tabulate (2, fn i => String.concatWith " "
                              (List.tabulate (2, fn j => Real.toString (RealArray2.sub (d, i, j)))))) ^ "]"
                       end)

(* The writes of a copy that should have raised Subscript land outside dst:
   here in another array, e. *)
val s = src ()
val d = A.array (1, 1, 0)
val e = A.array (2, 2, 7)
val () = print ("e before a copy into d: " ^ show e ^ "\n")
val () = try "copy of the whole 3 x 4 array into the 1 x 1 array d, expected Subscript"
             (fn () => (A.copy {src = {base = s, row = 0, col = 0, nrows = NONE, ncols = NONE},
                                dst = d, dst_row = 0, dst_col = 0};
                        "no exception"))
val () = print ("e after the copy into d: " ^ show e ^ "\n")
