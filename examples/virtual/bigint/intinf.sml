(* The first implementation of BigInt: the Basis Library's IntInf. *)
_export structure BigInt : BIGINT =
struct
  type int = IntInf.int
  val fromInt = IntInf.fromInt
  val op + = IntInf.+
  val op * = IntInf.*
  val compare = IntInf.compare
  val toString = IntInf.toString
end
