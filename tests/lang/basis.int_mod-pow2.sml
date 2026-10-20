(* Int.mod and Int.div by a divisor known only at run time, powers of two
   among them: compiled code takes an and for a positive power of two
   (native-frames.md, M2), which must give the floor's remainder, of a
   negative dividend too, and leave every other divisor to the division *)
fun show (x, d) =
  print (Int.toString x ^ " mod " ^ Int.toString d ^ " = " ^ Int.toString (x mod d)
         ^ ", div = " ^ Int.toString (x div d) ^ "\n")
val divisors = [1, 2, 4, 8, 1024, 65536, 2305843009213693952, 3, 6, 12, ~1 + 2, ~2, ~4, ~8, ~3]
val dividends = [0, 1, 7, 8, 9, ~1, ~7, ~8, ~9, 1000003, ~1000003, valOf Int.maxInt, valOf Int.minInt]
fun each f [] = () | each f (x :: xs) = (f x; each f xs)
val () = each (fn d => each (fn x => show (x, d)) dividends) divisors
(* a table's slot, as a hash table takes it: k mod the size *)
fun slot (k, size) = k mod size
fun sum (0, acc) = acc | sum (k, acc) = sum (k - 1, acc + slot (k * 7919, 64) + slot (~k, 16))
val () = print (Int.toString (sum (100000, 0)) ^ "\n")
