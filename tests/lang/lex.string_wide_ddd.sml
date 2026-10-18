(* \ddd is the character with that code, three decimal digits up to 999
   (the Definition, Section 2.2): above 255 only a wide character or string
   can hold it, as with \uXXXX, and at char and string it is a compile-time
   error (tests/errors/err.literal_ddd_char, err.literal_ddd_string). *)
val c : WideChar.char = #"\999"
val s : WideString.string = "a\256\999"
val codes = List.map (Int.toString o WideChar.ord) (WideString.explode s)
val () = print (Int.toString (WideChar.ord c) ^ " " ^ String.concatWith " " codes ^ "\n")
(* the same code points as \u writes them *)
val () = print (Bool.toString (c = #"\u03E7" andalso s = "a\u0100\u03E7") ^ "\n")
(* at char and string \ddd stops at 255 *)
val () = print (Int.toString (Char.ord #"\255") ^ " " ^ Int.toString (size "\255\000") ^ "\n")
(* DEL, which a literal cannot hold raw, is written as its escape *)
val () = print (Int.toString (Char.ord #"\127") ^ " " ^ Int.toString (size "a\127b") ^ "\n")
(* in patterns *)
fun name (#"\999" : WideChar.char) = "999"
  | name #"\256" = "256"
  | name _ = "other"
val () = print (name c ^ " " ^ name (WideChar.chr 256) ^ " " ^ name (WideChar.chr 255) ^ "\n")
fun kind ("\256\999" : WideString.string) = "both"
  | kind _ = "other"
val () = print (kind (WideString.implode [WideChar.chr 256, c]) ^ " " ^ kind s ^ "\n")
