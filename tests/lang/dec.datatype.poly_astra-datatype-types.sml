datatype ('a, 'b) choice = Left of 'a | Right of 'b
datatype 'a box = Box of 'a
datatype expr = Number of int | Apply of (int -> int) * expr
fun eval e = case e of Number n => n | Apply (f,x) => f (eval x)
val Box id = Box (fn x => x)
val _ = print (Int.toString (id (eval (Apply (fn x => x+2, Number 40)))) ^ "\n")
val _ = print (if id true then "true\n" else "false\n")
datatype holder = Holder of (int, bool) choice box
val Holder (Box x) = Holder (Box (Right true))
val _ = print (case x of Left n => Int.toString n | Right b => if b then "yes\n" else "no\n")
