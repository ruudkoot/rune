(* dump: --dump-after=translate *)
(* The types Lambda carries (docs/ir.md, Types): a polymorphic function used
   at two instances, and once where nothing says at which (a type variable
   no type was found for, '_a); a signature that makes a function less
   polymorphic than it is, with no coercion but an instance; an opaque type,
   which is what it stands for; an exception's payload. *)
fun id x = x
val a = (id 1, id "one")
fun len [] = 0
  | len (_ :: rest) = 1 + len rest
val n = len []
structure S :> sig type t val f : int -> int val mk : int -> t end =
struct
  type t = int
  fun f x = x
  fun mk x = f x
end
fun g (x : S.t) = x
val b = g (S.mk (S.f 3))
exception E of int * string
val m = (raise E (1, "one")) handle E (k, _) => k
