signature A = sig val a : int end
signature B = sig val b : int end
signature AB = sig include A B val c : int end
signature ABD = sig include AB type t val d : t -> int end
structure S : ABD = struct val a = 1 val b = 2 val c = 3 type t = string val d = String.size end
val () = print (Int.toString (S.a + S.b + S.c + S.d "four") ^ "\n")
(* include of an inline signature *)
structure T : sig include sig type u val u : u end val f : u -> int end =
  struct type u = int val u = 40 fun f x = x + 2 end
val () = print (Int.toString (T.f T.u) ^ "\n")
