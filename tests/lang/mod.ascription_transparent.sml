(* transparent ascription keeps the type identity; hidden components disappear *)
structure S : sig type t val x : t val show : t -> string end =
struct type t = int val x = 1 val hidden = 2 fun show n = Int.toString (n + 100) end
val y : int = S.x                       (* S.t is known to be int *)
val () = print (S.show y ^ "\n")
(* a structure-level value with a more general type is instantiated *)
structure M : sig val id : int -> int end = struct fun id x = x end
val () = print (Int.toString (M.id 3) ^ "\n")
(* a constructor matched by a value specification becomes an ordinary value *)
structure D : sig type t val K : int -> t val get : t -> int end =
struct datatype t = K of int fun get (K n) = n end
val () = print (Int.toString (D.get (D.K 11)) ^ "\n")
val K = 5
structure E : sig type t val K : t end = struct datatype t = K end
val () = let open E in case 5 of K => print "K is a variable pattern\n" end
