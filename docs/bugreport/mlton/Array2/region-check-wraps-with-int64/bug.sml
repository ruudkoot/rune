(* MLton, with -default-type int64: the region checks of Array2 add the
   start and the length of a region with +!, which wraps round, so a region
   whose start + length passes Int.maxInt is not rejected.
   Run: mlton -default-type int64 bug.sml && ./bug *)
fun check name f =
  (ignore (f ()); print (name ^ ": no exception (WRONG: expected Subscript)\n"))
  handle Subscript => print (name ^ ": Subscript (expected)\n")
       | e => print (name ^ ": " ^ exnName e ^ " (WRONG: expected Subscript)\n")

val big = valOf Int.maxInt
val () = print ("Int.precision = " ^ Int.toString (valOf Int.precision) ^ "\n")
val a = Array2.array (3, 4, 0)
fun count region = Array2.foldi Array2.RowMajor (fn (_, _, _, n) => n + 1) 0 region
val () = check "foldi of {row = 1, nrows = SOME maxInt}"
           (fn () => count {base = a, row = 1, col = 0, nrows = SOME big, ncols = NONE})
val () = check "foldi of {col = 1, ncols = SOME maxInt}"
           (fn () => count {base = a, row = 0, col = 1, nrows = NONE, ncols = SOME big})
val () = check "appi of {row = 1, nrows = SOME maxInt}"
           (fn () => Array2.appi Array2.RowMajor ignore {base = a, row = 1, col = 0, nrows = SOME big, ncols = NONE})
val () = check "modifyi of {col = 1, ncols = SOME maxInt}"
           (fn () => Array2.modifyi Array2.ColMajor #3 {base = a, row = 0, col = 1, nrows = NONE, ncols = SOME big})
(* copy: its destination region, of the size of the source, at dst_row =
   maxInt - 1 *)
val () = check "copy of a 2 x 2 region to dst_row = maxInt - 1"
           (fn () => Array2.copy {src = {base = a, row = 1, col = 1, nrows = SOME 2, ncols = SOME 2},
                                  dst = Array2.array (4, 5, 0), dst_row = big - 1, dst_col = 0})
