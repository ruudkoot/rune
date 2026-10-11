(* Int32.abs of Int32.minInt. The specification of INTEGER: abs i raises
   Overflow "when the result is not representable", and Int32.~
   of minInt does raise it. Every line should be Overflow. Run: sml bug.sml *)
fun show (name, f) =
      let val got = (f ()) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ": ", if got = "Overflow" then "ok" else "WRONG", "\n"])
      end
val r = ref (valOf Int32.minInt)        (* so that nothing is folded at compile time *)
val () = show ("Int32.~ minInt", fn () => Int32.toString (Int32.~ (!r)))
val () = show ("Int32.abs minInt", fn () => Int32.toString (Int32.abs (!r)))
val () = show ("Int32.abs minInt > 0", fn () => Bool.toString (Int32.abs (!r) > 0))
val () = show ("Int32.toLarge (Int32.abs minInt)", fn () => LargeInt.toString (Int32.toLarge (Int32.abs (!r))))
val () = show ("Int32.abs minInt + 0", fn () => Int32.toString (Int32.abs (!r) + 0))
val () = OS.Process.exit OS.Process.success
