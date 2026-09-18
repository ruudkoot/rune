structure Counter :> sig type t val zero : t val next : t -> t val toInt : t -> int end =
struct type t = int val zero = 0 fun next n = n + 1 fun toInt n = n end
val () = print (Int.toString (Counter.toInt (Counter.next (Counter.next Counter.zero))) ^ "\n")
(* datatypes and exceptions keep their constructors under the abstract name *)
structure Q :> sig datatype t = A | B of int exception E val f : t -> int end =
struct datatype t = A | B of int exception E fun f A = 0 | f (B n) = n end
val () = print (Int.toString (Q.f (Q.B 4) + Q.f Q.A) ^ "\n")
val () = (raise Q.E) handle Q.E => print "E\n"
(* eqtype keeps equality *)
structure EQ :> sig eqtype t val mk : int -> t end = struct type t = int fun mk n = n end
val () = print (Bool.toString (EQ.mk 1 = EQ.mk 1) ^ "\n")
