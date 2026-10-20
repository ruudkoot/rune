(* A loop whose ref parameter becomes its value in a copy (the pass refs,
   performance M8), where the call of itself gives another ref, made
   anew, and where the loop sets or reads its ref in tail position (MLton's
   regression deep-flatten). *)
fun count (r : int ref, n) = if n = 0 then !r else count (ref (!r + 1), n - 1)
val a = count (ref 10, 3)
fun last (r : int ref, n) = if n = 0 then r := 7 else (r := !r + n; last (r, n - 1))
fun run n = let val () = last (ref 0, n) in n end
fun get (r : (int * int) ref, n) = if n = 0 then !r else get (r, n - 1)
val b = get (ref (1, 2), 3)
fun f r =
   case #1 (!r) of
      3 => r := (5, 6)
    | _ => f (ref (3, 8))
val r = ref (1, 2)
val () = f r
val () = f (ref (7, 8))
val () = print (concat [Int.toString a, " ", Int.toString (run 3), " ", Int.toString (#1 b), " ",
                        Int.toString (#1 (!r)), " ", Int.toString (#2 (!r)), "\n"])
