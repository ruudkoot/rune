(* Structures and functors: what they are ascribed and what they are bound to. *)
signature S = sig type t val x : t end

structure Plain = struct type t = int val x = 0 end
structure Transparent : S = struct type t = int val x = 1 end
structure Opaque :> S where type t = int = struct type t = int val x = 2 end
structure Alias = Plain
structure Nested =
struct
  structure Inner : S = Transparent
  structure Deeper = struct structure Innermost = Plain end
  val y = Inner.x
end

functor Id (X : S) : S = X
functor Make (type elem val zero : elem) :> S where type t = elem =
struct type t = elem val x = zero end

structure Applied = Id (Plain)
structure Made = Make (type elem = int val zero = 0)
structure A = Plain and B = Alias
