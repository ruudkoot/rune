(* every kind of specification *)
signature KINDS =
sig
  val v : int
  type t
  eqtype e
  type 'a pair = 'a * 'a
  datatype color = Red | Green of int
  datatype opt = datatype option
  exception Bad of string
  exception Worse
  structure Sub : sig val inner : string end
end
structure K : KINDS =
struct
  val v = 7
  type t = real
  type e = string
  type 'a pair = 'a * 'a
  datatype color = Green of int | Red
  datatype opt = datatype option
  exception Bad of string
  exception Worse
  structure Sub = struct val inner = "in" val extra = 0 end
end
val p : int K.pair = (K.v, K.v + 1)
val () = print (Int.toString (#1 p + #2 p) ^ "\n")
val () = case K.Green 3 of K.Green n => print (Int.toString n ^ "\n") | K.Red => print "red\n"
val () = case K.SOME 1 of K.SOME n => print (Int.toString n ^ "\n") | K.NONE => print "none\n"
val () = (raise K.Bad "oops") handle K.Bad s => print (s ^ "\n") | K.Worse => print "worse\n"
val () = print (K.Sub.inner ^ "\n")
val e : K.e = "eq"
val () = print (Bool.toString (e = "eq") ^ "\n")
