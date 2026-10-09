(* SML/NJ: the checks of Array2's indices and regions compute with
   checked int arithmetic before they compare, so an index or a length
   near Int.maxInt or Int.minInt raises Overflow, where the specification
   says Subscript. Run: sml bug.sml *)
fun check name f =
  (ignore (f ()); print (name ^ ": no exception (WRONG: expected Subscript)\n"))
  handle Subscript => print (name ^ ": Subscript (expected)\n")
       | e => print (name ^ ": " ^ exnName e ^ " (WRONG: expected Subscript)\n")

val big = valOf Int.maxInt
val least = valOf Int.minInt
val a = Array2.array (3, 4, 0)
fun count (region : int Array2.region) = Array2.foldi Array2.RowMajor (fn (_, _, _, n) => n + 1) 0 region
val () = check "row (a, maxInt)" (fn () => Array2.row (a, big))
val () = check "foldi of {row = 1, nrows = SOME maxInt}"
           (fn () => count {base = a, row = 1, col = 0, nrows = SOME big, ncols = NONE})
val () = check "appi of {col = 1, ncols = SOME maxInt}"
           (fn () => Array2.appi Array2.RowMajor ignore {base = a, row = 0, col = 1, nrows = NONE, ncols = SOME big})
val () = check "modifyi of {row = maxInt, nrows = SOME maxInt}"
           (fn () => Array2.modifyi Array2.ColMajor #3 {base = a, row = big, col = 0, nrows = SOME big, ncols = NONE})
val src : int Array2.region = {base = a, row = 1, col = 1, nrows = SOME 2, ncols = SOME 2}
val () = check "copy of a 2 x 2 region to dst_row = maxInt"
           (fn () => Array2.copy {src = src, dst = Array2.array (4, 5, 0), dst_row = big, dst_col = 0})
val () = check "copy of a 2 x 2 region to dst_row = dst_col = minInt"
           (fn () => Array2.copy {src = src, dst = Array2.array (4, 5, 0), dst_row = least, dst_col = least})
