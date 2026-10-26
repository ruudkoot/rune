(* The dynamic module, compiled to a unit of its own (rune --units
   --emit-units DIR shape.sml impl.sml), whose datatype declares its
   constructors in another order than the signature's. *)
_export structure Impl : SHAPE =
struct
  datatype kind = Square of int | Round
  type t = int * kind
  exception Bad of int
  fun make n = if n < 0 then raise Bad n else (n, if n > 5 then Round else Square n)
  fun area (n, _) = n * n
  fun kindOf (_, k) = k
  val name = "impl"
  fun twice x = (x, x)
end
