(* In the HEX format of WORD.scan, (0wx | 0wX | 0x | 0X)?[0-9a-fA-F]+, "0w"
   alone is no prefix: "0w12" is the number 0 followed by "w12".  MLKit reads
   it as 0wx12. *)
fun rest (s, i) = String.extract (s, i, NONE)
fun reader s i = if i < String.size s then SOME (String.sub (s, i), i + 1) else NONE
fun scanned toString scan s =
  case scan StringCvt.HEX (reader s) 0 of
    NONE => "NONE"
  | SOME (w, i) => "SOME (0wx" ^ toString w ^ ", \"" ^ rest (s, i) ^ "\")"
fun opt toString NONE = "NONE"
  | opt toString (SOME w) = "SOME 0wx" ^ toString w
val s = "0w12"
val () = print ("Word.scan HEX \"0w12\"      = " ^ scanned Word.toString Word.scan s ^ "\n")
val () = print ("Word8.scan HEX \"0w12\"     = " ^ scanned Word8.toString Word8.scan s ^ "\n")
val () = print ("Word16.scan HEX \"0w12\"    = " ^ scanned Word16.toString Word16.scan s ^ "\n")
val () = print ("Word32.scan HEX \"0w12\"    = " ^ scanned Word32.toString Word32.scan s ^ "\n")
val () = print ("Word64.scan HEX \"0w12\"    = " ^ scanned Word64.toString Word64.scan s ^ "\n")
val () = print ("Word.fromString \"0w12\"    = " ^ opt Word.toString (Word.fromString s) ^ "\n")
val () = print ("Word8.fromString \"0w12\"   = " ^ opt Word8.toString (Word8.fromString s) ^ "\n")
val () = print ("Word32.fromString \"0w12\"  = " ^ opt Word32.toString (Word32.fromString s) ^ "\n")
val () = print ("Word64.fromString \"0w12\"  = " ^ opt Word64.toString (Word64.fromString s) ^ "\n")
(* for contrast: the valid prefixes, and 0wx without a digit after it *)
val () = print ("Word.scan HEX \"0wx12\"     = " ^ scanned Word.toString Word.scan "0wx12" ^ "\n")
val () = print ("Word.scan HEX \"0x12\"      = " ^ scanned Word.toString Word.scan "0x12" ^ "\n")
val () = print ("Word.fromString \"0wxg\"    = " ^ opt Word.toString (Word.fromString "0wxg") ^ "\n")
