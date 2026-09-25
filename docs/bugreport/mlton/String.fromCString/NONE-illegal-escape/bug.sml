fun showFromString label s =
  print (label ^ " " ^ String.toString s ^ " = " ^
         (case String.fromString s of
            NONE => "NONE"
          | SOME r => "SOME \"" ^ String.toString r ^ "\"") ^ "\n")

fun showChar label s =
  print (label ^ " " ^ String.toString s ^ " = " ^
         (case Char.fromCString s of
            NONE => "NONE"
          | SOME c => "SOME #\"" ^ Char.toString c ^ "\"") ^ "\n")

fun show label s =
  print (label ^ " " ^ String.toString s ^ " = " ^
         (case String.fromCString s of
            NONE => "NONE"
          | SOME r => "SOME \"" ^ String.toString r ^ "\"") ^ "\n")

val () = showFromString "String.fromString " "\\q"
val () = showChar        "Char.fromCString  " "\\q"
val () = show            "String.fromCString" "\\q"
val () = show            "String.fromCString" "\\"
val () = show            "String.fromCString" "\n"
val () = show            "String.fromCString" "abc\\qdef"
