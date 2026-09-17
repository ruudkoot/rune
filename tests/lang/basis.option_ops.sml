val () = print (Int.toString (Option.getOpt (NONE, 5)) ^ Bool.toString (Option.isSome (SOME 1)) ^ Int.toString (Option.valOf (SOME 2)) ^ "\n")
val () = print (Bool.toString (isSome (Option.filter (fn x => x > 0) 1)) ^ Bool.toString (isSome (Option.filter (fn x => x > 0) ~1)) ^ Int.toString (valOf (Option.join (SOME (SOME 3)))) ^ Bool.toString (isSome (Option.join (SOME NONE))) ^ "\n")
val () = Option.app print (SOME "app\n")
val () = Option.app print NONE
val () = print (Int.toString (valOf (Option.map (fn x => x + 1) (SOME 1))) ^ Bool.toString (isSome (Option.map (fn x => x + 1) NONE)) ^ Int.toString (valOf (Option.mapPartial (fn x => if x > 0 then SOME x else NONE) (SOME 7))) ^ "\n")
val f = Option.compose (fn x => x * 2, fn s => Int.fromString s)
val g = Option.composePartial (fn x => if x > 5 then SOME x else NONE, fn s => Int.fromString s)
val () = print (Int.toString (valOf (f "21")) ^ Bool.toString (isSome (f "x")) ^ Int.toString (valOf (g "9")) ^ Bool.toString (isSome (g "1")) ^ "\n")
val () = print ((Int.toString (Option.valOf NONE)) handle Option.Option => "Option\n")
