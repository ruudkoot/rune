signature ORD = sig type t val compare : t * t -> order end
functor MaxFn (Ord : ORD) =
struct
  fun max (a, b) = case Ord.compare (a, b) of LESS => b | _ => a
  datatype t = datatype Ord.t
  exception Empty
  fun maxList [] = raise Empty | maxList (x :: xs) = List.foldl max x xs
end
structure IntMax = MaxFn (type t = int val compare = Int.compare)
structure StrMax = MaxFn (struct type t = string val compare = String.compare end)
val () = print (Int.toString (IntMax.maxList [3, 9, 2]) ^ " " ^ StrMax.maxList ["b", "c", "a"] ^ "\n")
val () = (ignore (IntMax.maxList [])) handle IntMax.Empty => print "empty\n"
(* the spec form of the parameter is opened in the body *)
functor Twice (type t val f : t -> t) = struct fun g x = f (f x) end
structure T = Twice (type t = int fun f x = x * 2)
val () = print (Int.toString (T.g 5) ^ "\n")
(* open of the parameter *)
functor Open (X : sig val a : int val b : int end) = struct open X val c = a + b end
structure O = Open (val a = 1 val b = 2)
val () = print (Int.toString O.c ^ "\n")
