(* --default-type=int64 --default-type=word64 (the .cargs): what the
   declaration leaves open defaults to Int64.int and Word64.word, not to
   int and word *)
fun double x = x + x
val () = print (Int64.toString (double 4611686018427387903) ^ "\n")
val big = 9223372036854775807
val () = print (Int64.toString big ^ " " ^ Int64.toString (big - 9223372036854775806) ^ "\n")
fun shift w = w * 0w2
val () = print (Word64.toString (shift 0wx7FFFFFFFFFFFFFFF) ^ "\n")
val () = print (Word64.toString 0wxFFFFFFFFFFFFFFFF ^ "\n")
(* what the context decides is not defaulted *)
val () = print (Int.toString (Int.max (3, 4)) ^ " " ^ Word.toString (Word.<< (0w1, 0w4)) ^ "\n")
val () = print (Int64.toString (double 3 handle Overflow => 0) ^ "\n")
val () = print ((Int64.toString (double 9223372036854775807)) handle Overflow => "Overflow\n")
