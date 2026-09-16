datatype 'a box = Box of 'a
val x = Box (fn x => x)
val _ = x = x
