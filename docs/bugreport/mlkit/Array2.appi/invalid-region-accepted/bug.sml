(* MLKit: Array2.appi, foldi, modifyi and copy on regions that are not valid.
   Every region below is invalid, so each call must raise Subscript. *)
fun try (what : string) (f : unit -> string) =
  print (what ^ ": " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")

(* 3 rows and 4 columns *)
val a = Array2.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
val maxInt = valOf Int.maxInt
fun reg (row, col, nrows, ncols) : int Array2.region =
  {base = a, row = row, col = col, nrows = nrows, ncols = ncols}

fun appi r = (Array2.appi Array2.RowMajor (fn _ => ()) r; "no exception")
fun foldi r =
  Int.toString (Array2.foldi Array2.RowMajor (fn (_, _, _, n) => n + 1) 0 r)
  ^ " elements, no exception"
fun modifyi r = (Array2.modifyi Array2.ColMajor (fn (_, _, x) => x) r; "no exception")
fun copy r =
  (Array2.copy {src = r, dst = Array2.array (8, 8, 0), dst_row = 0, dst_col = 0};
   "no exception")

val () = try "appi    row 4, nrows NONE       (row > nRows)" (fn () => appi (reg (4, 0, NONE, NONE)))
val () = try "foldi   col 5, ncols NONE       (col > nCols)" (fn () => foldi (reg (0, 5, NONE, NONE)))
val () = try "modifyi row maxInt, nrows NONE" (fn () => modifyi (reg (maxInt, 0, NONE, NONE)))
val () = try "appi    row 1, nrows SOME ~1" (fn () => appi (reg (1, 0, SOME ~1, NONE)))
val () = try "foldi   col 1, ncols SOME ~1" (fn () => foldi (reg (0, 1, NONE, SOME ~1)))
val () = try "foldi   col 1, ncols SOME minInt" (fn () => foldi (reg (0, 1, NONE, SOME (valOf Int.minInt))))
val () = try "appi    row 1, nrows SOME maxInt" (fn () => appi (reg (1, 0, SOME maxInt, NONE)))
val () = try "modifyi row maxInt, nrows SOME 1" (fn () => modifyi (reg (maxInt, 0, SOME 1, NONE)))
val () = try "copy    row 4, nrows NONE" (fn () => copy (reg (4, 0, NONE, NONE)))
val () = try "copy    row 1, nrows SOME ~1" (fn () => copy (reg (1, 0, SOME ~1, NONE)))
val () = try "copy    row 1, nrows SOME maxInt" (fn () => copy (reg (1, 0, SOME maxInt, NONE)))
(* for contrast: a region that runs one row past the end *)
val () = try "appi    row 2, nrows SOME 2     (for contrast)" (fn () => appi (reg (2, 0, SOME 2, NONE)))
