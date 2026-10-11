(* OS.Path.splitBaseExt and joinBaseExt of paths with an empty arc before
   the last one. The specification: the base "is everything to the left of
   the extension except the final "."", and "joinBaseExt o splitBaseExt is
   the identity". Run: sml bug.sml *)
fun q s = "\"" ^ s ^ "\""
fun showBE {base, ext} =
      "{base = " ^ q base ^ ", ext = " ^ (case ext of NONE => "NONE" | SOME e => "SOME " ^ q e) ^ "}"
fun split (p, expected) =
      let val r = OS.Path.splitBaseExt p
      in print (concat ["splitBaseExt ", q p, " = ", showBE r, ", expected ", showBE expected, ": ",
                        if r = expected then "ok" else "WRONG", "\n"])
      end
fun join (be, expected) =
      let val r = OS.Path.joinBaseExt be
      in print (concat ["joinBaseExt ", showBE be, " = ", q r, ", expected ", q expected, ": ",
                        if r = expected then "ok" else "WRONG", "\n"])
      end
val () = split ("//", {base = "//", ext = NONE})
val () = split ("a//b", {base = "a//b", ext = NONE})
val () = split ("a//c.d", {base = "a//c", ext = SOME "d"})
val () = split ("//c.d", {base = "//c", ext = SOME "d"})
val () = split ("a/b.c", {base = "a/b", ext = SOME "c"})
val () = join ({base = "a//c", ext = SOME "d"}, "a//c.d")
val () = join ({base = "a//", ext = SOME "d"}, "a//.d")
val () = join ({base = "a/b", ext = SOME "c"}, "a/b.c")
val () = OS.Process.exit OS.Process.success
