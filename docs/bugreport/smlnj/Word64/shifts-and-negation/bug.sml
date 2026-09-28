(* Word64 shifts and negation on SML/NJ for 32 bits. Every operand is read
   from a string at run time, so that nothing is folded; the expected values
   are those of the 64-bit build, MLton and Poly/ML. Run: sml bug.sml *)
fun w s = valOf (StringCvt.scanString (Word64.scan StringCvt.HEX) s)
fun show (name, f, expected) =
      let val got = (Word64.fmt StringCvt.HEX (f ())) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val n = Word.fromInt o valOf o Int.fromString
val () = show ("0wx1 << 0w0", fn () => Word64.<< (w "1", n "0"), "1")
val () = show ("0wx100000000 >> 0w0", fn () => Word64.>> (w "100000000", n "0"), "100000000")
val () = show ("0wx100000000 ~>> 0w0", fn () => Word64.~>> (w "100000000", n "0"), "100000000")
val () = show ("0wx80000000 ~>> 0w1", fn () => Word64.~>> (w "80000000", n "1"), "40000000")
val () = show ("0wx8000000000000000 ~>> 0w33", fn () => Word64.~>> (w "8000000000000000", n "33"), "FFFFFFFFC0000000")
val () = show ("0wx80000000 ~>> 0w64", fn () => Word64.~>> (w "80000000", n "64"), "0")
val () = show ("0wx8000000000000000 ~>> 0w64", fn () => Word64.~>> (w "8000000000000000", n "64"), "FFFFFFFFFFFFFFFF")
val () = show ("Word64.~ 0wx8000000000000000", fn () => Word64.~ (w "8000000000000000"), "8000000000000000")
val () = OS.Process.exit OS.Process.success
