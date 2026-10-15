(* Alternate signed and unsigned widths, then revisit them. Cached limits
   must be keyed by width and signedness, while every literal is checked. *)
val w8 : Word8.word = 0w255
val lo8 : Int8.int = ~128
val hi8 : Int8.int = 127
val w16 : Word16.word = 0w65535
val lo16 : Int16.int = ~32768
val hi16 : Int16.int = 32767
val w32 : Word32.word = 0wxFFFFFFFF
val lo32 : Int32.int = ~2147483648
val hi32 : Int32.int = 2147483647
val w64 : Word64.word = 0wxFFFFFFFFFFFFFFFF
val lo64 : Int64.int = ~9223372036854775808
val hi64 : Int64.int = 9223372036854775807
val () = print (Int8.toString lo8 ^ " " ^ Int8.toString hi8 ^ " " ^ Word8.toString w8 ^ "\n")
val () = print (Int16.toString lo16 ^ " " ^ Int16.toString hi16 ^ " " ^ Word16.toString w16 ^ "\n")
val () = print (Int32.toString lo32 ^ " " ^ Int32.toString hi32 ^ " " ^ Word32.toString w32 ^ "\n")
val () = print (Int64.toString lo64 ^ " " ^ Int64.toString hi64 ^ " " ^ Word64.toString w64 ^ "\n")
val () = print (Int8.toString (~128 : Int8.int) ^ " " ^ Word8.toString (0w255 : Word8.word) ^ "\n")
val c : char = #"\255"
val wide : WideChar.char = #"\U0010FFFF"
val empty : WideString.string = ""
val () = print (Int.toString (Char.ord c) ^ " " ^ Int.toString (WideChar.ord wide) ^ " " ^ Int.toString (WideString.size empty) ^ "\n")
val huge : IntInf.int = 340282366920938463463374607431768211456
val () = print (IntInf.toString huge ^ "\n")
