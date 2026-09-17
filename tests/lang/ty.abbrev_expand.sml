type 'a pred = 'a -> bool
type intpair = int * int
type ('k, 'v) table = ('k * 'v) list
fun apply (p : 'a pred) x = p x
val evens : int pred = fn n => n mod 2 = 0
val ip : intpair = (1, 2)
val tbl : (string, int) table = [("one", 1)]
val () = print (Bool.toString (apply evens 4) ^ Int.toString (#1 ip + #2 ip) ^ Int.toString (#2 (hd tbl)) ^ "\n")
