(* Conversions between int, Int32, Int64, word, Word8, Word32 and Word64 as
   the Basis gives them. Each source value is read from a string at run time,
   each conversion is a function of its own (so that the compiler fuses the
   conversions in it but cannot fold them), each result goes through a ref,
   and the expected result is computed with IntInf. Prints the wrong ones and
   a count. Run: sml convs.sml *)
val ok = ref 0 and bad = ref 0
fun bits "INT" = valOf Int.precision | bits "WORD" = Word.wordSize | bits s = valOf (Int.fromString s)
fun pow2 n = IntInf.pow (2, n)
fun unsigned (n, v) = IntInf.mod (v, pow2 n)
fun signed (n, v) = let val u = unsigned (n, v) in if u >= pow2 (n - 1) then u - pow2 n else u end
fun intResult (n, v) = if ~ (pow2 (n - 1)) <= v andalso v < pow2 (n - 1) then IntInf.toString v else "Overflow"
fun wordResult (n, v) = IntInf.fmt StringCvt.HEX (unsigned (n, v))
fun check (name, v, got, expected) =
      if got = expected then ok := !ok + 1
      else (bad := !bad + 1;
            print (concat [name, " with x = ", IntInf.toString v, ": ", got, ", expected ", expected, "\n"]))
fun result f = f () handle Overflow => "Overflow"
val values = map (valOf o IntInf.fromString)
  ["0", "1", "~1", "5", "~5", "127", "128", "255", "256", "1073741823", "1073741824", "~1073741824",
   "~1073741825", "2147483647", "2147483648", "~2147483648", "~2147483649", "4294967295", "4294967296",
   "4294967297", "8589934597", "~4294967296", "4611686018427387903", "4611686018427387904",
   "~4611686018427387904", "~4611686018427387905", "9223372036854775807", "9223372036854775808",
   "~9223372036854775808", "~9223372036854775809", "18446744073709551615"]

fun mkInt v = valOf (Int.fromString (IntInf.toString v))
fun inInt v = ~ (pow2 (bits "INT" - 1)) <= v andalso v < pow2 (bits "INT" - 1)
fun mkInt32 v = valOf (Int32.fromString (IntInf.toString v))
fun inInt32 v = ~ (pow2 (bits "32" - 1)) <= v andalso v < pow2 (bits "32" - 1)
fun mkInt64 v = valOf (Int64.fromString (IntInf.toString v))
fun inInt64 v = ~ (pow2 (bits "64" - 1)) <= v andalso v < pow2 (bits "64" - 1)
fun mkWord v = valOf (StringCvt.scanString (Word.scan StringCvt.HEX) (IntInf.fmt StringCvt.HEX (unsigned (bits "WORD", v))))
fun mkWord8 v = valOf (StringCvt.scanString (Word8.scan StringCvt.HEX) (IntInf.fmt StringCvt.HEX (unsigned (bits "8", v))))
fun mkWord32 v = valOf (StringCvt.scanString (Word32.scan StringCvt.HEX) (IntInf.fmt StringCvt.HEX (unsigned (bits "32", v))))
fun mkWord64 v = valOf (StringCvt.scanString (Word64.scan StringCvt.HEX) (IntInf.fmt StringCvt.HEX (unsigned (bits "64", v))))
fun c_Int_Int (x : Int.int) = Int.fromLarge (Int.toLarge x)
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Int.fromLarge (Int.toLarge x)", v, result (fn () => (r := SOME (c_Int_Int (mkInt v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", v)) end else ()) values
fun c_Int_Int32 (x : Int.int) = Int32.fromLarge (Int.toLarge x)
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Int32.fromLarge (Int.toLarge x)", v, result (fn () => (r := SOME (c_Int_Int32 (mkInt v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", v)) end else ()) values
fun c_Int_Int64 (x : Int.int) = Int64.fromLarge (Int.toLarge x)
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Int64.fromLarge (Int.toLarge x)", v, result (fn () => (r := SOME (c_Int_Int64 (mkInt v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", v)) end else ()) values
fun c_Int_Word (x : Int.int) = Word.fromLargeInt (Int.toLarge x)
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word.fromLargeInt (Int.toLarge x)", v, result (fn () => (r := SOME (c_Int_Word (mkInt v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", v)) end else ()) values
fun c_Int_Word8 (x : Int.int) = Word8.fromLargeInt (Int.toLarge x)
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word8.fromLargeInt (Int.toLarge x)", v, result (fn () => (r := SOME (c_Int_Word8 (mkInt v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", v)) end else ()) values
fun c_Int_Word32 (x : Int.int) = Word32.fromLargeInt (Int.toLarge x)
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word32.fromLargeInt (Int.toLarge x)", v, result (fn () => (r := SOME (c_Int_Word32 (mkInt v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", v)) end else ()) values
fun c_Int_Word64 (x : Int.int) = Word64.fromLargeInt (Int.toLarge x)
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word64.fromLargeInt (Int.toLarge x)", v, result (fn () => (r := SOME (c_Int_Word64 (mkInt v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", v)) end else ()) values
fun t_Int (x : Int.int) = Int.toInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Int.toInt x", v, result (fn () => (r := SOME (t_Int (mkInt v)); Int.toString (valOf (!r)))), intResult (bits "INT", v)) end else ()) values
fun f_Int (x : int) = Int.fromInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Int.fromInt x", v, result (fn () => (r := SOME (f_Int (mkInt v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", v)) end else ()) values
fun c_Int32_Int (x : Int32.int) = Int.fromLarge (Int32.toLarge x)
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Int.fromLarge (Int32.toLarge x)", v, result (fn () => (r := SOME (c_Int32_Int (mkInt32 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", v)) end else ()) values
fun c_Int32_Int32 (x : Int32.int) = Int32.fromLarge (Int32.toLarge x)
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Int32.fromLarge (Int32.toLarge x)", v, result (fn () => (r := SOME (c_Int32_Int32 (mkInt32 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", v)) end else ()) values
fun c_Int32_Int64 (x : Int32.int) = Int64.fromLarge (Int32.toLarge x)
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Int64.fromLarge (Int32.toLarge x)", v, result (fn () => (r := SOME (c_Int32_Int64 (mkInt32 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", v)) end else ()) values
fun c_Int32_Word (x : Int32.int) = Word.fromLargeInt (Int32.toLarge x)
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Word.fromLargeInt (Int32.toLarge x)", v, result (fn () => (r := SOME (c_Int32_Word (mkInt32 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", v)) end else ()) values
fun c_Int32_Word8 (x : Int32.int) = Word8.fromLargeInt (Int32.toLarge x)
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Word8.fromLargeInt (Int32.toLarge x)", v, result (fn () => (r := SOME (c_Int32_Word8 (mkInt32 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", v)) end else ()) values
fun c_Int32_Word32 (x : Int32.int) = Word32.fromLargeInt (Int32.toLarge x)
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Word32.fromLargeInt (Int32.toLarge x)", v, result (fn () => (r := SOME (c_Int32_Word32 (mkInt32 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", v)) end else ()) values
fun c_Int32_Word64 (x : Int32.int) = Word64.fromLargeInt (Int32.toLarge x)
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Word64.fromLargeInt (Int32.toLarge x)", v, result (fn () => (r := SOME (c_Int32_Word64 (mkInt32 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", v)) end else ()) values
fun t_Int32 (x : Int32.int) = Int32.toInt x
val () = app (fn v => if inInt32 v then let val r = ref NONE in check ("Int32.toInt x", v, result (fn () => (r := SOME (t_Int32 (mkInt32 v)); Int.toString (valOf (!r)))), intResult (bits "INT", v)) end else ()) values
fun f_Int32 (x : int) = Int32.fromInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Int32.fromInt x", v, result (fn () => (r := SOME (f_Int32 (mkInt v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", v)) end else ()) values
fun c_Int64_Int (x : Int64.int) = Int.fromLarge (Int64.toLarge x)
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Int.fromLarge (Int64.toLarge x)", v, result (fn () => (r := SOME (c_Int64_Int (mkInt64 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", v)) end else ()) values
fun c_Int64_Int32 (x : Int64.int) = Int32.fromLarge (Int64.toLarge x)
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Int32.fromLarge (Int64.toLarge x)", v, result (fn () => (r := SOME (c_Int64_Int32 (mkInt64 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", v)) end else ()) values
fun c_Int64_Int64 (x : Int64.int) = Int64.fromLarge (Int64.toLarge x)
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Int64.fromLarge (Int64.toLarge x)", v, result (fn () => (r := SOME (c_Int64_Int64 (mkInt64 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", v)) end else ()) values
fun c_Int64_Word (x : Int64.int) = Word.fromLargeInt (Int64.toLarge x)
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Word.fromLargeInt (Int64.toLarge x)", v, result (fn () => (r := SOME (c_Int64_Word (mkInt64 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", v)) end else ()) values
fun c_Int64_Word8 (x : Int64.int) = Word8.fromLargeInt (Int64.toLarge x)
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Word8.fromLargeInt (Int64.toLarge x)", v, result (fn () => (r := SOME (c_Int64_Word8 (mkInt64 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", v)) end else ()) values
fun c_Int64_Word32 (x : Int64.int) = Word32.fromLargeInt (Int64.toLarge x)
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Word32.fromLargeInt (Int64.toLarge x)", v, result (fn () => (r := SOME (c_Int64_Word32 (mkInt64 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", v)) end else ()) values
fun c_Int64_Word64 (x : Int64.int) = Word64.fromLargeInt (Int64.toLarge x)
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Word64.fromLargeInt (Int64.toLarge x)", v, result (fn () => (r := SOME (c_Int64_Word64 (mkInt64 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", v)) end else ()) values
fun t_Int64 (x : Int64.int) = Int64.toInt x
val () = app (fn v => if inInt64 v then let val r = ref NONE in check ("Int64.toInt x", v, result (fn () => (r := SOME (t_Int64 (mkInt64 v)); Int.toString (valOf (!r)))), intResult (bits "INT", v)) end else ()) values
fun f_Int64 (x : int) = Int64.fromInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Int64.fromInt x", v, result (fn () => (r := SOME (f_Int64 (mkInt v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", v)) end else ()) values
fun c_Word_Int (x : Word.word) = Int.fromLarge (Word.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word.toLargeInt x)", v, result (fn () => (r := SOME (c_Word_Int (mkWord v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", unsigned (bits "WORD", v))) end) values
fun cx_Word_Int (x : Word.word) = Int.fromLarge (Word.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word_Int (mkWord v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", signed (bits "WORD", v))) end) values
fun c_Word_Int32 (x : Word.word) = Int32.fromLarge (Word.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word.toLargeInt x)", v, result (fn () => (r := SOME (c_Word_Int32 (mkWord v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", unsigned (bits "WORD", v))) end) values
fun cx_Word_Int32 (x : Word.word) = Int32.fromLarge (Word.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word_Int32 (mkWord v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", signed (bits "WORD", v))) end) values
fun c_Word_Int64 (x : Word.word) = Int64.fromLarge (Word.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word.toLargeInt x)", v, result (fn () => (r := SOME (c_Word_Int64 (mkWord v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", unsigned (bits "WORD", v))) end) values
fun cx_Word_Int64 (x : Word.word) = Int64.fromLarge (Word.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word_Int64 (mkWord v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", signed (bits "WORD", v))) end) values
fun c_Word_Word (x : Word.word) = Word.fromLargeInt (Word.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLargeInt (Word.toLargeInt x)", v, result (fn () => (r := SOME (c_Word_Word (mkWord v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "WORD", v))) end) values
fun l_Word_Word (x : Word.word) = Word.fromLarge (Word.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word.toLarge x)", v, result (fn () => (r := SOME (l_Word_Word (mkWord v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "WORD", v))) end) values
fun lx_Word_Word (x : Word.word) = Word.fromLarge (Word.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word.toLargeX x)", v, result (fn () => (r := SOME (lx_Word_Word (mkWord v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", signed (bits "WORD", v))) end) values
fun c_Word_Word8 (x : Word.word) = Word8.fromLargeInt (Word.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLargeInt (Word.toLargeInt x)", v, result (fn () => (r := SOME (c_Word_Word8 (mkWord v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "WORD", v))) end) values
fun l_Word_Word8 (x : Word.word) = Word8.fromLarge (Word.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word.toLarge x)", v, result (fn () => (r := SOME (l_Word_Word8 (mkWord v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "WORD", v))) end) values
fun lx_Word_Word8 (x : Word.word) = Word8.fromLarge (Word.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word.toLargeX x)", v, result (fn () => (r := SOME (lx_Word_Word8 (mkWord v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", signed (bits "WORD", v))) end) values
fun c_Word_Word32 (x : Word.word) = Word32.fromLargeInt (Word.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLargeInt (Word.toLargeInt x)", v, result (fn () => (r := SOME (c_Word_Word32 (mkWord v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "WORD", v))) end) values
fun l_Word_Word32 (x : Word.word) = Word32.fromLarge (Word.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word.toLarge x)", v, result (fn () => (r := SOME (l_Word_Word32 (mkWord v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "WORD", v))) end) values
fun lx_Word_Word32 (x : Word.word) = Word32.fromLarge (Word.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word.toLargeX x)", v, result (fn () => (r := SOME (lx_Word_Word32 (mkWord v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", signed (bits "WORD", v))) end) values
fun c_Word_Word64 (x : Word.word) = Word64.fromLargeInt (Word.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLargeInt (Word.toLargeInt x)", v, result (fn () => (r := SOME (c_Word_Word64 (mkWord v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "WORD", v))) end) values
fun l_Word_Word64 (x : Word.word) = Word64.fromLarge (Word.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word.toLarge x)", v, result (fn () => (r := SOME (l_Word_Word64 (mkWord v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "WORD", v))) end) values
fun lx_Word_Word64 (x : Word.word) = Word64.fromLarge (Word.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word.toLargeX x)", v, result (fn () => (r := SOME (lx_Word_Word64 (mkWord v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", signed (bits "WORD", v))) end) values
fun t_Word (x : Word.word) = Word.toInt x
val () = app (fn v => let val r = ref NONE in check ("Word.toInt x", v, result (fn () => (r := SOME (t_Word (mkWord v)); Int.toString (valOf (!r)))), intResult (bits "INT", unsigned (bits "WORD", v))) end) values
fun tx_Word (x : Word.word) = Word.toIntX x
val () = app (fn v => let val r = ref NONE in check ("Word.toIntX x", v, result (fn () => (r := SOME (tx_Word (mkWord v)); Int.toString (valOf (!r)))), intResult (bits "INT", signed (bits "WORD", v))) end) values
fun f_Word (x : int) = Word.fromInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word.fromInt x", v, result (fn () => (r := SOME (f_Word (mkInt v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", v)) end else ()) values
fun c_Word8_Int (x : Word8.word) = Int.fromLarge (Word8.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word8.toLargeInt x)", v, result (fn () => (r := SOME (c_Word8_Int (mkWord8 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", unsigned (bits "8", v))) end) values
fun cx_Word8_Int (x : Word8.word) = Int.fromLarge (Word8.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word8.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word8_Int (mkWord8 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", signed (bits "8", v))) end) values
fun c_Word8_Int32 (x : Word8.word) = Int32.fromLarge (Word8.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word8.toLargeInt x)", v, result (fn () => (r := SOME (c_Word8_Int32 (mkWord8 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", unsigned (bits "8", v))) end) values
fun cx_Word8_Int32 (x : Word8.word) = Int32.fromLarge (Word8.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word8.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word8_Int32 (mkWord8 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", signed (bits "8", v))) end) values
fun c_Word8_Int64 (x : Word8.word) = Int64.fromLarge (Word8.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word8.toLargeInt x)", v, result (fn () => (r := SOME (c_Word8_Int64 (mkWord8 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", unsigned (bits "8", v))) end) values
fun cx_Word8_Int64 (x : Word8.word) = Int64.fromLarge (Word8.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word8.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word8_Int64 (mkWord8 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", signed (bits "8", v))) end) values
fun c_Word8_Word (x : Word8.word) = Word.fromLargeInt (Word8.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLargeInt (Word8.toLargeInt x)", v, result (fn () => (r := SOME (c_Word8_Word (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "8", v))) end) values
fun l_Word8_Word (x : Word8.word) = Word.fromLarge (Word8.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word8.toLarge x)", v, result (fn () => (r := SOME (l_Word8_Word (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "8", v))) end) values
fun lx_Word8_Word (x : Word8.word) = Word.fromLarge (Word8.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word8.toLargeX x)", v, result (fn () => (r := SOME (lx_Word8_Word (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", signed (bits "8", v))) end) values
fun c_Word8_Word8 (x : Word8.word) = Word8.fromLargeInt (Word8.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLargeInt (Word8.toLargeInt x)", v, result (fn () => (r := SOME (c_Word8_Word8 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "8", v))) end) values
fun l_Word8_Word8 (x : Word8.word) = Word8.fromLarge (Word8.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word8.toLarge x)", v, result (fn () => (r := SOME (l_Word8_Word8 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "8", v))) end) values
fun lx_Word8_Word8 (x : Word8.word) = Word8.fromLarge (Word8.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word8.toLargeX x)", v, result (fn () => (r := SOME (lx_Word8_Word8 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", signed (bits "8", v))) end) values
fun c_Word8_Word32 (x : Word8.word) = Word32.fromLargeInt (Word8.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLargeInt (Word8.toLargeInt x)", v, result (fn () => (r := SOME (c_Word8_Word32 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "8", v))) end) values
fun l_Word8_Word32 (x : Word8.word) = Word32.fromLarge (Word8.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word8.toLarge x)", v, result (fn () => (r := SOME (l_Word8_Word32 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "8", v))) end) values
fun lx_Word8_Word32 (x : Word8.word) = Word32.fromLarge (Word8.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word8.toLargeX x)", v, result (fn () => (r := SOME (lx_Word8_Word32 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", signed (bits "8", v))) end) values
fun c_Word8_Word64 (x : Word8.word) = Word64.fromLargeInt (Word8.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLargeInt (Word8.toLargeInt x)", v, result (fn () => (r := SOME (c_Word8_Word64 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "8", v))) end) values
fun l_Word8_Word64 (x : Word8.word) = Word64.fromLarge (Word8.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word8.toLarge x)", v, result (fn () => (r := SOME (l_Word8_Word64 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "8", v))) end) values
fun lx_Word8_Word64 (x : Word8.word) = Word64.fromLarge (Word8.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word8.toLargeX x)", v, result (fn () => (r := SOME (lx_Word8_Word64 (mkWord8 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", signed (bits "8", v))) end) values
fun t_Word8 (x : Word8.word) = Word8.toInt x
val () = app (fn v => let val r = ref NONE in check ("Word8.toInt x", v, result (fn () => (r := SOME (t_Word8 (mkWord8 v)); Int.toString (valOf (!r)))), intResult (bits "INT", unsigned (bits "8", v))) end) values
fun tx_Word8 (x : Word8.word) = Word8.toIntX x
val () = app (fn v => let val r = ref NONE in check ("Word8.toIntX x", v, result (fn () => (r := SOME (tx_Word8 (mkWord8 v)); Int.toString (valOf (!r)))), intResult (bits "INT", signed (bits "8", v))) end) values
fun f_Word8 (x : int) = Word8.fromInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word8.fromInt x", v, result (fn () => (r := SOME (f_Word8 (mkInt v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", v)) end else ()) values
fun c_Word32_Int (x : Word32.word) = Int.fromLarge (Word32.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word32.toLargeInt x)", v, result (fn () => (r := SOME (c_Word32_Int (mkWord32 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", unsigned (bits "32", v))) end) values
fun cx_Word32_Int (x : Word32.word) = Int.fromLarge (Word32.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word32.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word32_Int (mkWord32 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", signed (bits "32", v))) end) values
fun c_Word32_Int32 (x : Word32.word) = Int32.fromLarge (Word32.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word32.toLargeInt x)", v, result (fn () => (r := SOME (c_Word32_Int32 (mkWord32 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", unsigned (bits "32", v))) end) values
fun cx_Word32_Int32 (x : Word32.word) = Int32.fromLarge (Word32.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word32.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word32_Int32 (mkWord32 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", signed (bits "32", v))) end) values
fun c_Word32_Int64 (x : Word32.word) = Int64.fromLarge (Word32.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word32.toLargeInt x)", v, result (fn () => (r := SOME (c_Word32_Int64 (mkWord32 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", unsigned (bits "32", v))) end) values
fun cx_Word32_Int64 (x : Word32.word) = Int64.fromLarge (Word32.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word32.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word32_Int64 (mkWord32 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", signed (bits "32", v))) end) values
fun c_Word32_Word (x : Word32.word) = Word.fromLargeInt (Word32.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLargeInt (Word32.toLargeInt x)", v, result (fn () => (r := SOME (c_Word32_Word (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "32", v))) end) values
fun l_Word32_Word (x : Word32.word) = Word.fromLarge (Word32.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word32.toLarge x)", v, result (fn () => (r := SOME (l_Word32_Word (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "32", v))) end) values
fun lx_Word32_Word (x : Word32.word) = Word.fromLarge (Word32.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word32.toLargeX x)", v, result (fn () => (r := SOME (lx_Word32_Word (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", signed (bits "32", v))) end) values
fun c_Word32_Word8 (x : Word32.word) = Word8.fromLargeInt (Word32.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLargeInt (Word32.toLargeInt x)", v, result (fn () => (r := SOME (c_Word32_Word8 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "32", v))) end) values
fun l_Word32_Word8 (x : Word32.word) = Word8.fromLarge (Word32.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word32.toLarge x)", v, result (fn () => (r := SOME (l_Word32_Word8 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "32", v))) end) values
fun lx_Word32_Word8 (x : Word32.word) = Word8.fromLarge (Word32.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word32.toLargeX x)", v, result (fn () => (r := SOME (lx_Word32_Word8 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", signed (bits "32", v))) end) values
fun c_Word32_Word32 (x : Word32.word) = Word32.fromLargeInt (Word32.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLargeInt (Word32.toLargeInt x)", v, result (fn () => (r := SOME (c_Word32_Word32 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "32", v))) end) values
fun l_Word32_Word32 (x : Word32.word) = Word32.fromLarge (Word32.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word32.toLarge x)", v, result (fn () => (r := SOME (l_Word32_Word32 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "32", v))) end) values
fun lx_Word32_Word32 (x : Word32.word) = Word32.fromLarge (Word32.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word32.toLargeX x)", v, result (fn () => (r := SOME (lx_Word32_Word32 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", signed (bits "32", v))) end) values
fun c_Word32_Word64 (x : Word32.word) = Word64.fromLargeInt (Word32.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLargeInt (Word32.toLargeInt x)", v, result (fn () => (r := SOME (c_Word32_Word64 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "32", v))) end) values
fun l_Word32_Word64 (x : Word32.word) = Word64.fromLarge (Word32.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word32.toLarge x)", v, result (fn () => (r := SOME (l_Word32_Word64 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "32", v))) end) values
fun lx_Word32_Word64 (x : Word32.word) = Word64.fromLarge (Word32.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word32.toLargeX x)", v, result (fn () => (r := SOME (lx_Word32_Word64 (mkWord32 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", signed (bits "32", v))) end) values
fun t_Word32 (x : Word32.word) = Word32.toInt x
val () = app (fn v => let val r = ref NONE in check ("Word32.toInt x", v, result (fn () => (r := SOME (t_Word32 (mkWord32 v)); Int.toString (valOf (!r)))), intResult (bits "INT", unsigned (bits "32", v))) end) values
fun tx_Word32 (x : Word32.word) = Word32.toIntX x
val () = app (fn v => let val r = ref NONE in check ("Word32.toIntX x", v, result (fn () => (r := SOME (tx_Word32 (mkWord32 v)); Int.toString (valOf (!r)))), intResult (bits "INT", signed (bits "32", v))) end) values
fun f_Word32 (x : int) = Word32.fromInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word32.fromInt x", v, result (fn () => (r := SOME (f_Word32 (mkInt v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", v)) end else ()) values
fun c_Word64_Int (x : Word64.word) = Int.fromLarge (Word64.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word64.toLargeInt x)", v, result (fn () => (r := SOME (c_Word64_Int (mkWord64 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", unsigned (bits "64", v))) end) values
fun cx_Word64_Int (x : Word64.word) = Int.fromLarge (Word64.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int.fromLarge (Word64.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word64_Int (mkWord64 v)); IntInf.toString (Int.toLarge (valOf (!r))))), intResult (bits "INT", signed (bits "64", v))) end) values
fun c_Word64_Int32 (x : Word64.word) = Int32.fromLarge (Word64.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word64.toLargeInt x)", v, result (fn () => (r := SOME (c_Word64_Int32 (mkWord64 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", unsigned (bits "64", v))) end) values
fun cx_Word64_Int32 (x : Word64.word) = Int32.fromLarge (Word64.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int32.fromLarge (Word64.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word64_Int32 (mkWord64 v)); IntInf.toString (Int32.toLarge (valOf (!r))))), intResult (bits "32", signed (bits "64", v))) end) values
fun c_Word64_Int64 (x : Word64.word) = Int64.fromLarge (Word64.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word64.toLargeInt x)", v, result (fn () => (r := SOME (c_Word64_Int64 (mkWord64 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", unsigned (bits "64", v))) end) values
fun cx_Word64_Int64 (x : Word64.word) = Int64.fromLarge (Word64.toLargeIntX x)
val () = app (fn v => let val r = ref NONE in check ("Int64.fromLarge (Word64.toLargeIntX x)", v, result (fn () => (r := SOME (cx_Word64_Int64 (mkWord64 v)); IntInf.toString (Int64.toLarge (valOf (!r))))), intResult (bits "64", signed (bits "64", v))) end) values
fun c_Word64_Word (x : Word64.word) = Word.fromLargeInt (Word64.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLargeInt (Word64.toLargeInt x)", v, result (fn () => (r := SOME (c_Word64_Word (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "64", v))) end) values
fun l_Word64_Word (x : Word64.word) = Word.fromLarge (Word64.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word64.toLarge x)", v, result (fn () => (r := SOME (l_Word64_Word (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", unsigned (bits "64", v))) end) values
fun lx_Word64_Word (x : Word64.word) = Word.fromLarge (Word64.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word.fromLarge (Word64.toLargeX x)", v, result (fn () => (r := SOME (lx_Word64_Word (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word.toLargeInt (valOf (!r))))), wordResult (bits "WORD", signed (bits "64", v))) end) values
fun c_Word64_Word8 (x : Word64.word) = Word8.fromLargeInt (Word64.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLargeInt (Word64.toLargeInt x)", v, result (fn () => (r := SOME (c_Word64_Word8 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "64", v))) end) values
fun l_Word64_Word8 (x : Word64.word) = Word8.fromLarge (Word64.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word64.toLarge x)", v, result (fn () => (r := SOME (l_Word64_Word8 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", unsigned (bits "64", v))) end) values
fun lx_Word64_Word8 (x : Word64.word) = Word8.fromLarge (Word64.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word8.fromLarge (Word64.toLargeX x)", v, result (fn () => (r := SOME (lx_Word64_Word8 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word8.toLargeInt (valOf (!r))))), wordResult (bits "8", signed (bits "64", v))) end) values
fun c_Word64_Word32 (x : Word64.word) = Word32.fromLargeInt (Word64.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLargeInt (Word64.toLargeInt x)", v, result (fn () => (r := SOME (c_Word64_Word32 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "64", v))) end) values
fun l_Word64_Word32 (x : Word64.word) = Word32.fromLarge (Word64.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word64.toLarge x)", v, result (fn () => (r := SOME (l_Word64_Word32 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", unsigned (bits "64", v))) end) values
fun lx_Word64_Word32 (x : Word64.word) = Word32.fromLarge (Word64.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word32.fromLarge (Word64.toLargeX x)", v, result (fn () => (r := SOME (lx_Word64_Word32 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word32.toLargeInt (valOf (!r))))), wordResult (bits "32", signed (bits "64", v))) end) values
fun c_Word64_Word64 (x : Word64.word) = Word64.fromLargeInt (Word64.toLargeInt x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLargeInt (Word64.toLargeInt x)", v, result (fn () => (r := SOME (c_Word64_Word64 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "64", v))) end) values
fun l_Word64_Word64 (x : Word64.word) = Word64.fromLarge (Word64.toLarge x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word64.toLarge x)", v, result (fn () => (r := SOME (l_Word64_Word64 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", unsigned (bits "64", v))) end) values
fun lx_Word64_Word64 (x : Word64.word) = Word64.fromLarge (Word64.toLargeX x)
val () = app (fn v => let val r = ref NONE in check ("Word64.fromLarge (Word64.toLargeX x)", v, result (fn () => (r := SOME (lx_Word64_Word64 (mkWord64 v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", signed (bits "64", v))) end) values
fun t_Word64 (x : Word64.word) = Word64.toInt x
val () = app (fn v => let val r = ref NONE in check ("Word64.toInt x", v, result (fn () => (r := SOME (t_Word64 (mkWord64 v)); Int.toString (valOf (!r)))), intResult (bits "INT", unsigned (bits "64", v))) end) values
fun tx_Word64 (x : Word64.word) = Word64.toIntX x
val () = app (fn v => let val r = ref NONE in check ("Word64.toIntX x", v, result (fn () => (r := SOME (tx_Word64 (mkWord64 v)); Int.toString (valOf (!r)))), intResult (bits "INT", signed (bits "64", v))) end) values
fun f_Word64 (x : int) = Word64.fromInt x
val () = app (fn v => if inInt v then let val r = ref NONE in check ("Word64.fromInt x", v, result (fn () => (r := SOME (f_Word64 (mkInt v)); IntInf.fmt StringCvt.HEX (Word64.toLargeInt (valOf (!r))))), wordResult (bits "64", v)) end else ()) values
val () = print (Int.toString (!ok) ^ " right, " ^ Int.toString (!bad) ^ " wrong\n")
val () = OS.Process.exit OS.Process.success
