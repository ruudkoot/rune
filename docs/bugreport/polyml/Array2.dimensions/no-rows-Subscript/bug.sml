(* Poly/ML 5.9.2: two-dimensional arrays with no rows.
   Each line shows what the Basis Library gives, and what the specification
   asks for where that differs. *)
fun check (what : string) (expected : string) (f : unit -> string) =
  let val got = f () handle e => "raised " ^ exnName e
  in print (what ^ ": " ^ got
            ^ (if got = expected then "" else "    <- WRONG, should be " ^ expected)
            ^ "\n")
  end
fun pair (r, c) = "(" ^ Int.toString r ^ ", " ^ Int.toString c ^ ")"

val empty : int Array2.array = Array2.fromList []
val noRows : int Array2.array = Array2.array (0, 5, 0)    (* 0 rows of 5 columns *)

val () = check "Array2.nRows (fromList [])" "0"
  (fn () => Int.toString (Array2.nRows empty))
val () = check "Array2.nCols (fromList [])" "0"
  (fn () => Int.toString (Array2.nCols empty))
val () = check "Array2.dimensions (fromList [])" "(0, 0)"
  (fn () => pair (Array2.dimensions empty))
val () = check "Array2.dimensions (array (0, 5, 0))" "(0, 5)"
  (fn () => pair (Array2.dimensions noRows))
val () = check "Array2.dimensions (tabulate RowMajor (0, 5, f))" "(0, 5)"
  (fn () => pair (Array2.dimensions (Array2.tabulate Array2.RowMajor (0, 5, fn _ => 0))))
val () = check "Array2.fold RowMajor op+ 0 (fromList [])" "0"
  (fn () => Int.toString (Array2.fold Array2.RowMajor op+ 0 empty))
val () = check "Array2.app RowMajor ignore (array (0, 5, 0))" "()"
  (fn () => (Array2.app Array2.RowMajor ignore noRows; "()"))
val () = check "Array2.modify ColMajor ~ (fromList [])" "()"
  (fn () => (Array2.modify Array2.ColMajor ~ empty; "()"))
val () = check "Array2.copy all of fromList [] into a 2 x 2 array" "()"
  (fn () => (Array2.copy {src = {base = empty, row = 0, col = 0, nrows = NONE, ncols = NONE},
                          dst = Array2.array (2, 2, 0), dst_row = 0, dst_col = 0};
             "()"))
val () = check "Array2.column (array (0, 5, 0), 5)" "raised Subscript"
  (fn () => Int.toString (Vector.length (Array2.column (noRows, 5))) ^ " elements")
val () = check "Array2.array (0, ~1, 0)" "raised Size"
  (fn () => (ignore (Array2.array (0, ~1, 0)); "()"))
val () = check "fromList [] = fromList []" "false"
  (fn () => Bool.toString (empty = Array2.fromList []))
val () = check "array (0, 5, 0) = array (0, 5, 0)" "false"
  (fn () => Bool.toString (noRows = Array2.array (0, 5, 0)))
(* for contrast: no columns *)
val () = check "Array2.dimensions (array (5, 0, 0))" "(5, 0)"
  (fn () => pair (Array2.dimensions (Array2.array (5, 0, 0))))

(* The MONO_ARRAY2 structures *)
val () = check "IntArray2.dimensions (IntArray2.fromList [])" "(0, 0)"
  (fn () => pair (IntArray2.dimensions (IntArray2.fromList [])))
val () = check "RealArray2.dimensions (RealArray2.fromList [])" "(0, 0)"
  (fn () => pair (RealArray2.dimensions (RealArray2.fromList [])))
val () = check "BoolArray2.dimensions (BoolArray2.fromList [])" "(0, 0)"
  (fn () => pair (BoolArray2.dimensions (BoolArray2.fromList [])))
val () = check "CharArray2.dimensions (CharArray2.fromList [])" "(0, 0)"
  (fn () => pair (CharArray2.dimensions (CharArray2.fromList [])))
val () = check "Word8Array2.dimensions (Word8Array2.fromList [])" "(0, 0)"
  (fn () => pair (Word8Array2.dimensions (Word8Array2.fromList [])))
val () = check "IntArray2.row (IntArray2.array (3, 0, 0), 7)" "raised Subscript"
  (fn () => Int.toString (IntVector.length (IntArray2.row (IntArray2.array (3, 0, 0), 7)))
            ^ " elements")
