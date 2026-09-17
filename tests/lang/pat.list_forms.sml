fun f [] = "empty" | f [x] = "one" | f [x, y] = "two" | f (x :: y :: rest) = "many"
val () = print (f [] ^ f [1] ^ f [1, 2] ^ f [1, 2, 3] ^ "\n")
fun sumPairs [] = 0 | sumPairs ((a, b) :: rest) = a + b + sumPairs rest
val () = print (Int.toString (sumPairs [(1, 2), (3, 4)]) ^ "\n")
fun nested [[x]] = x | nested _ = 0
val () = print (Int.toString (nested [[7]] + nested [[1, 2]]) ^ "\n")
