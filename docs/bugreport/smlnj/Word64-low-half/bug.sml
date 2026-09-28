(* 64-bit literals on SML/NJ for 32 bits: bits 30 and 31 of the low half.
   Each line prints a Word64 or Int64 value written as a literal (or folded
   into one by the compiler) beside the same number made at run time from a
   string, and whether they are equal. Run: sml bug.sml *)
fun w64 s = valOf (StringCvt.scanString (Word64.scan StringCvt.HEX) s)
fun i64 s = valOf (Int64.fromString s)
fun showW (name, lit, s) =
      print (concat [name, " = ", Word64.fmt StringCvt.HEX lit, ", expected ",
                     Word64.fmt StringCvt.HEX (w64 s), ": ",
                     if lit = w64 s then "ok" else "WRONG", "\n"])
fun showI (name, lit, s) =
      print (concat [name, " = ", Int64.toString lit, ", expected ",
                     Int64.toString (i64 s), ": ",
                     if lit = i64 s then "ok" else "WRONG", "\n"])
val () = showW ("0wx40000000 : Word64.word", 0wx40000000, "40000000")
val () = showW ("0wx80000000 : Word64.word", 0wx80000000, "80000000")
val () = showW ("0wxFFFFFFFFFFFFFFFF : Word64.word", 0wxFFFFFFFFFFFFFFFF, "FFFFFFFFFFFFFFFF")
val () = showW ("Word64.fromInt 1073741823 + 0w1", Word64.fromInt 1073741823 + 0w1, "40000000")
val () = showI ("~5 : Int64.int", ~5, "~5")
val () = showI ("1073741824 : Int64.int", 1073741824, "1073741824")
val () = showI ("Int64.+ (~2, ~3)", Int64.+ (~2, ~3), "~5")
val () = OS.Process.exit OS.Process.success
