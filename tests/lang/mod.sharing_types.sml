signature TWO =
sig
  structure A : sig type t val a : t end
  structure B : sig type t val f : t -> int end
  sharing type A.t = B.t
end
structure Impl : TWO =
struct
  structure A = struct type t = int val a = 20 end
  structure B = struct type t = int fun f x = x + 1 end
end
val () = print (Int.toString (Impl.B.f Impl.A.a) ^ "\n")
