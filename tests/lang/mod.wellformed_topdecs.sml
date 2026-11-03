(* A file's top level holds any declaration of Standard ML, whether or not
   the file is a well-formed unit (docs/units.md, Well-formed units): a
   program means what it says either way *)
infix 5 <+>
fun a <+> b = a + b
val x = 1 <+> 2
exception Stop of int
datatype shape = Circle of int | Square of int
datatype copy = datatype shape
structure S = struct val inside = 10 end
open S
local val hidden = 100 in val shown = hidden + inside end
val _ = print "effect\n"
val () = print (Int.toString (x + shown) ^ "\n")
val area = case Square 3 of Circle r => r * r * 3 | Square s => s * s
val () = print (Int.toString area ^ "\n")
val () = (raise Stop 7) handle Stop n => print (Int.toString n ^ "\n")
