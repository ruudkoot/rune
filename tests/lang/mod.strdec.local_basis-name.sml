(* A structure of the Basis Library is still there where a file uses it before
   it declares one of the same name, and after a `local` that hid it. *)
val n = List.length [1, 2]
structure List = struct val mine = 3 end
local structure Char = struct val mine = 4 end in val m = Char.mine end
val c = Char.ord #"a"
val () = print (Int.toString (n + List.mine + m + c) ^ "\n")
