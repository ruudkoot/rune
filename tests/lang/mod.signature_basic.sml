(* signature declarations, simultaneous bindings, use in ascription *)
signature STACK =
sig
  type 'a t
  val empty : 'a t
  val push : 'a * 'a t -> 'a t
  val pop : 'a t -> ('a * 'a t) option
end
and SHOW = sig val show : int -> string end
structure ListStack : STACK =
struct
  type 'a t = 'a list
  val empty = []
  fun push (x, s) = x :: s
  fun pop [] = NONE | pop (x :: s) = SOME (x, s)
  val unused = "not visible through the signature"
end
structure Show : SHOW = struct val show = Int.toString end
val s = ListStack.push (2, ListStack.push (1, ListStack.empty))
val () = case ListStack.pop s of
           SOME (x, _) => print (Show.show x ^ "\n")
         | NONE => print "empty\n"
(* a signature identifier can be used several times *)
structure S2 : STACK = ListStack
val () = print (Show.show (List.length (S2.push (3, s))) ^ "\n")
