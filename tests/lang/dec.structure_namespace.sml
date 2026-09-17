structure Stack =
struct
  type 'a t = 'a list
  val empty = []
  fun push (x, s) = x :: s
  fun pop [] = NONE | pop (x :: s) = SOME (x, s)
  exception EmptyStack
  fun top [] = raise EmptyStack | top (x :: _) = x
  structure Inner = struct val depth = 3 end
end
val s = Stack.push (2, Stack.push (1, Stack.empty))
val () = print (Int.toString (Stack.top s) ^ Int.toString Stack.Inner.depth ^ "\n")
val () = print ((Int.toString (Stack.top [])) handle Stack.EmptyStack => "empty\n")
structure Alias = Stack
val () = print (Int.toString (Alias.top s) ^ "\n")
