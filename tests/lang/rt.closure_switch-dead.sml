(* A closure uses k only where x is A, in the else of a test that x is A:
   Lower leaves that branch out of the switch on x's tag, and the closure
   captures nothing for it, as the lint wants of a closure (every value it
   captures, it reads). *)
datatype t = A of int | B of int | C of int | D of int

fun mk (k : int) =
  fn x => case x of
            A n => n
          | B n => n + 1
          | C n => n + 2
          | _ => (case x of A n => n + k | _ => 0)

val fs = List.map mk [100, 200]
val () = List.app (fn f => print (Int.toString (f (A 1) + f (B 1) + f (C 1) + f (D 1)) ^ "\n")) fs
