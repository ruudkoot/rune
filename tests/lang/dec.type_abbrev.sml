type point = int * int
type 'a pair = 'a * 'a
type ('a, 'b) assoc = ('a * 'b) list
fun addp ((a, b) : point) = a + b
val pr : string pair = ("x", "y")
val al : (string, int) assoc = [("a", 1), ("b", 2)]
val () = print (Int.toString (addp (3, 4)) ^ #1 pr ^ #2 pr ^ Int.toString (length al) ^ "\n")
