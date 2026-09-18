signature CONTAINER = sig type 'a t type elem val make : elem -> elem t val get : elem t -> elem end
signature INT_LIST_CONTAINER = CONTAINER where type 'a t = 'a list and type elem = int
structure C : INT_LIST_CONTAINER = struct type 'a t = 'a list type elem = int fun make x = [x] fun get (x :: _) = x | get [] = 0 end
val () = print (Int.toString (C.get (C.make 5) + List.length (C.make 1)) ^ "\n")
(* where type on a nested structure's type *)
signature P = sig structure Inner : sig type t val x : t end val show : Inner.t -> string end
structure PI : P where type Inner.t = int =
  struct structure Inner = struct type t = int val x = 8 end val show = Int.toString end
val () = print (PI.show (PI.Inner.x + 1) ^ "\n")
