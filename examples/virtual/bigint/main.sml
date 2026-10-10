(* The program, compiled against BIGINT alone: another implementation of
   BigInt compiles none of it again. *)
fun fact n = if n = 0 then BigInt.fromInt 1 else BigInt.* (BigInt.fromInt n, fact (n - 1))
fun sum (a, b) = if a > b then BigInt.fromInt 0 else BigInt.+ (fact a, sum (a + 1, b))
val () = print (BigInt.toString (fact 30) ^ "\n")
val () = print (BigInt.toString (BigInt.+ (BigInt.fromInt ~5, BigInt.fromInt 3)) ^ "\n")
val () = print (BigInt.toString (sum (20, 25)) ^ "\n")
val () = print (case BigInt.compare (fact 21, BigInt.* (fact 20, BigInt.fromInt 21)) of EQUAL => "equal\n" | _ => "differ\n")
