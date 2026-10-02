(* A record used once, by a closure two deep, through another record that
   holds it: the closure reads it from its environment. Lower once read its
   fields from the variables of the function that made it, which in the
   closure were others: at -O0, real_add was given an int. *)
fun fold n init f =
  let fun loop (i, acc) = if i < n then loop (i + 1, f (i, acc)) else acc
  in loop (0, init) end

fun sum n =
  let
    val p = {x = 3.0, y = 4.0, z = 5.0}
  in
    fold n 0.0 (fn (_, a) =>
      fold n a (fn (_, b) =>
        let val ray = {org = p, dir = {x = 0.0, y = 1.0, z = 0.0}}
        in b + #x (#org ray) end))
  end

val () = List.app (fn n => print (Int.toString n ^ " " ^ Real.toString (sum n) ^ "\n")) [1, 2, 8]
