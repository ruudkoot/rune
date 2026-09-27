(* "These scan a 24-character date ... The format of the string must be
   precisely as produced by toString." *)
val s = "Wed Mar 08 19:06:45 19956"
val () = print ("Date.toString of the date scanned is 24 characters: \"Wed Mar 08 19:06:45 1995\"\n")
val () =
    case Date.scan Substring.getc (Substring.full s) of
        NONE => print "Date.scan: NONE\n"
      | SOME (d, rest) =>
          print ("Date.scan \"" ^ s ^ "\" = SOME (year " ^ Int.toString (Date.year d) ^ ", rest \""
                 ^ Substring.string rest ^ "\")   (expected SOME (year 1995, rest \"6\"))\n")
