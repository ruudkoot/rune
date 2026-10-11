(* General.exnMessage of the Basis's own exceptions. The specification: the
   message "will at least contain the string exnName ex", with the example
   exnMessage Div = "Div". Run: sml bug.sml *)
fun show ex =
      let val name = exnName ex
          val msg = exnMessage ex
      in print (concat ["exnMessage ", name, " = \"", String.toString msg, "\": ",
                        if String.isSubstring name msg then "ok" else "WRONG (no \"" ^ name ^ "\")", "\n"])
      end
val () = List.app show [Bind, Match, Div, Domain, Overflow, Size, Subscript,
                        Chr, Empty, Option, Span, Fail "why", OS.SysErr ("No such file", NONE)]
val () = OS.Process.exit OS.Process.success
