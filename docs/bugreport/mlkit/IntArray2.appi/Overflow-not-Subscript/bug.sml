(* MLKit: IntArray2.appi, foldi and modifyi (and those of every MONO_ARRAY2
   structure, all made by the functor WordArray2) on a region whose end
   row + nrows or col + ncols is beyond Int.maxInt. Every region below is
   invalid, so each call must raise Subscript. *)
fun try (what : string) (f : unit -> unit) =
  print (what ^ ": " ^ ((f (); "no exception") handle e => "raised " ^ exnName e) ^ "\n")
val maxInt = valOf Int.maxInt

(* 3 rows and 4 columns *)
val a = IntArray2.fromList [[0, 1, 2, 3], [10, 11, 12, 13], [20, 21, 22, 23]]
fun reg (row, col, nrows, ncols) : IntArray2.region =
  {base = a, row = row, col = col, nrows = nrows, ncols = ncols}

val () = try "IntArray2.appi    row 1, nrows SOME maxInt"
             (fn () => IntArray2.appi IntArray2.RowMajor (fn _ => ()) (reg (1, 0, SOME maxInt, NONE)))
val () = try "IntArray2.foldi   col 1, ncols SOME maxInt"
             (fn () => ignore (IntArray2.foldi IntArray2.ColMajor (fn (_, _, _, n) => n + 1) 0 (reg (0, 1, NONE, SOME maxInt))))
val () = try "IntArray2.modifyi row 1, nrows SOME maxInt"
             (fn () => IntArray2.modifyi IntArray2.RowMajor (fn (_, _, x) => x) (reg (1, 0, SOME maxInt, NONE)))
val () = try "RealArray2.appi   row 1, nrows SOME maxInt"
             (fn () => RealArray2.appi RealArray2.RowMajor (fn _ => ())
                         {base = RealArray2.array (3, 4, 0.0), row = 1, col = 0, nrows = SOME maxInt, ncols = NONE})
val () = try "WordArray2.foldi  col 1, ncols SOME maxInt"
             (fn () => ignore (WordArray2.foldi WordArray2.RowMajor (fn (_, _, _, n) => n + 1) 0
                         {base = WordArray2.array (3, 4, 0w0), row = 0, col = 1, nrows = NONE, ncols = SOME maxInt}))
(* for contrast: row = maxInt, too large by itself *)
val () = try "IntArray2.appi    row maxInt, nrows SOME 1 (for contrast)"
             (fn () => IntArray2.appi IntArray2.RowMajor (fn _ => ()) (reg (maxInt, 0, SOME 1, NONE)))
