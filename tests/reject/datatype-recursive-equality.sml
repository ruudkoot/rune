datatype t = Next of t | Function of int -> int
fun eq (Next x) = x = x
