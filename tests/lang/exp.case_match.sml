fun describe l =
  case l of
    [] => "empty"
  | [x] => "one:" ^ Int.toString x
  | [x, y] => "two:" ^ Int.toString (x + y)
  | x :: _ => "many starting " ^ Int.toString x
val () = print (describe [] ^ " " ^ describe [1] ^ " " ^ describe [1, 2] ^ " " ^ describe [1, 2, 3] ^ "\n")
val () = print (case (1, "a") of (1, "b") => "wrong" | (2, _) => "wrong" | (_, s) => s ^ "\n")
val () = print (case SOME 3 of NONE => "none" | SOME n => Int.toString n ^ "\n")
val () = print (case "str" of "str" => "matched\n" | _ => "no\n")
val () = print (case #"c" of #"a" => "a" | #"c" => "c\n" | _ => "?")
val () = print (case 0w5 of 0w5 => "w5\n" | _ => "?")
