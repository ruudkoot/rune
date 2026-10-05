(* a literal at Int64.int and Word64.word keeps 64 bits, where int and word are the VM's 63 *)
val () = print (Int64.toString 0 ^ " " ^ Int64.toString 42 ^ " " ^ Int64.toString ~7 ^ " " ^ Int64.toString 0x1F ^ " " ^ Int64.toString ~0xff ^ "\n")
val () = print (Int64.toString 9223372036854775807 ^ " " ^ Int64.toString ~9223372036854775808 ^ "\n")
val () = print (Int64.toString 4611686018427387903 ^ " " ^ Int64.toString 4611686018427387904 ^ " " ^ Int64.toString ~4611686018427387904 ^ " " ^ Int64.toString ~4611686018427387905 ^ "\n")
val () = print (Word64.toString 0w0 ^ " " ^ Word64.toString 0w255 ^ " " ^ Word64.toString 0wxdeadbeef ^ " " ^ Word64.toString 0wxFFFFFFFFFFFFFFFF ^ " " ^ Word64.toString 0wx8000000000000000 ^ " " ^ Word64.toString 0wx7FFFFFFFFFFFFFFF ^ "\n")
(* in a pattern, and as a constant of a function *)
fun name (n : Int64.int) = case n of 0 => "zero" | 9223372036854775807 => "max" | ~9223372036854775808 => "min" | 4611686018427387904 => "2^62" | _ => "other"
val () = print (name 0 ^ " " ^ name 9223372036854775807 ^ " " ^ name ~9223372036854775808 ^ " " ^ name 4611686018427387904 ^ " " ^ name 5 ^ "\n")
fun wname (w : Word64.word) = case w of 0wxFFFFFFFFFFFFFFFF => "ones" | 0w1 => "one" | _ => "other"
val () = print (wname 0wxFFFFFFFFFFFFFFFF ^ " " ^ wname 0w1 ^ " " ^ wname 0wxFFFFFFFFFFFFFFFE ^ "\n")
(* equality is of the number, whether it is in the word or in a box *)
val big : Int64.int = 9223372036854775806
val () = print (Bool.toString (Int64.+ (big, 1) = 9223372036854775807) ^ " " ^ Bool.toString (big = 9223372036854775807) ^ " " ^ Bool.toString ([big, 1] = [9223372036854775806, 1]) ^ "\n")
