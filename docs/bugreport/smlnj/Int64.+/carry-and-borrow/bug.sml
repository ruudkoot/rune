(* Int64 + and - on SML/NJ for 32 bits, on numbers the compiler cannot see:
   they are read from strings at run time. Run: sml bug.sml *)
fun i s = valOf (Int64.fromString s)
fun show (name, f, a, b, expected) =
      let val got = (Int64.toString (f (i a, i b))) handle Overflow => "Overflow"
      in print (concat [a, " ", name, " ", b, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val () = show ("+", Int64.+, "~2", "~3", "~5")
val () = show ("+", Int64.+, "~1", "1", "0")
val () = show ("+", Int64.+, "4294967295", "1", "4294967296")
val () = show ("+", Int64.+, "9223372036854775807", "1", "Overflow")
val () = show ("-", Int64.-, "5", "~3", "8")
val () = show ("-", Int64.-, "0", "4294967296", "~4294967296")
val () = show ("-", Int64.-, "~9223372036854775808", "1", "Overflow")
val () = OS.Process.exit OS.Process.success
