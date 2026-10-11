(* Scanning after a vertical tab, a form feed or a carriage return, which
   Char.isSpace counts as white space. StringCvt.skipWS "strips whitespace
   characters ... A whitespace character is one that satisfies the predicate
   Char.isSpace", and the scanners skip "initial whitespace". Each line reads
   "<c>1" (or "<c>true") for c = \v, \f and \r. Run: sml bug.sml *)
fun line (name, ok) =
      let val r = map (fn c => ok (String.str c) handle _ => false) [#"\v", #"\f", #"\r"]
      in print (concat [name, ": ", String.concatWith " " (map (fn true => "ok" | false => "WRONG") r), "\n"])
      end
fun scanned scan s = (case scan Substring.getc (Substring.full s)
       of SOME (_, rest) => Substring.isEmpty rest
        | NONE => false)
val () = print "-- through StringCvt.skipWS (smlnj/smlnj#447, fixed after 110.99.9 and 2026.2)\n"
val () = line ("StringCvt.skipWS", fn c => Substring.string (StringCvt.skipWS Substring.getc (Substring.full (c ^ "1"))) = "1")
val () = line ("Real.scan", fn c => scanned Real.scan (c ^ "1"))
val () = line ("Bool.scan", fn c => scanned Bool.scan (c ^ "true"))
val () = line ("IntInf.scan", fn c => scanned (IntInf.scan StringCvt.DEC) (c ^ "1"))
val () = print "-- through ScanUtil (not fixed)\n"
val () = line ("Int.scan", fn c => scanned (Int.scan StringCvt.DEC) (c ^ "1"))
val () = line ("Int32.scan", fn c => scanned (Int32.scan StringCvt.DEC) (c ^ "1"))
val () = line ("Int64.scan", fn c => scanned (Int64.scan StringCvt.DEC) (c ^ "1"))
val () = line ("Word.scan", fn c => scanned (Word.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Word8.scan", fn c => scanned (Word8.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Word32.scan", fn c => scanned (Word32.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Word64.scan", fn c => scanned (Word64.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Int64.fromString", fn c => Int64.fromString (c ^ "1") = SOME 1)
val () = line ("Word.fromString", fn c => Word.fromString (c ^ "1") = SOME 0w1)
val () = OS.Process.exit OS.Process.success
