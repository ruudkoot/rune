(* Character and string constants at the wide types: a constant is read from
   its text where it is evaluated (RuneWideCharLit, RuneWideStringLit), and one
   without a constraint is still a char or a string. A code point above 255
   needs the escape \uXXXX or \UXXXXXXXX, which only a wide type can hold. *)
val c : WideChar.char = #"\u00e9"
val d : WideChar.char = #"\U0001F600"
val s : WideString.string = "h\u00e9\U0001F600"
val () = print (WideChar.toString c ^ " " ^ WideChar.toString d ^ " " ^ WideString.toString s ^ "\n")
val () = print (Int.toString (WideString.size s) ^ " " ^ Bool.toString (WideChar.< (c, d)) ^ "\n")
(* the escapes of the 8-bit constants keep their meaning at the wide type *)
val () = print (WideString.toString ("a\t\\\"\u0041" : WideString.string) ^ "\n")
(* constants in patterns *)
fun name (#"a" : WideChar.char) = "a"
  | name #"\u00e9" = "e-acute"
  | name #"\U0001F600" = "face"
  | name _ = "other"
val () = print (name c ^ " " ^ name d ^ " " ^ name (WideChar.chr 97) ^ " " ^ name (WideChar.chr 98) ^ "\n")
fun kind ("" : WideString.string) = "empty"
  | kind "\u00e9" = "one wide character"
  | kind _ = "other"
val () = print (kind (WideString.implode []) ^ ", " ^ kind (WideString.str c) ^ ", " ^ kind s ^ "\n")
(* a constant without a constraint is a char and a string as before *)
val plain = "abc"
val letter = #"a"
val () = print (plain ^ " " ^ Int.toString (size plain) ^ " " ^ Char.toString letter ^ "\n")
val wide : WideString.string = WideString.concat ["a", "\u0100"]
val () = print (WideString.toString wide ^ "\n")
