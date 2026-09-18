(* Array and Vector: the sieve of Eratosthenes; the argument is the limit. *)
val n = case CommandLine.arguments () of [a] => valOf (Int.fromString a) | _ => 60000
val sieve = Array.array (n + 1, true)
fun strike (i, p) = if i > n then () else (Array.update (sieve, i, false); strike (i + p, p))
fun run p = if p * p > n then () else (if Array.sub (sieve, p) then strike (p * p, p) else (); run (p + 1))
val () = run 2
val primes = Array.foldli (fn (i, true, acc) => if i >= 2 then i :: acc else acc | (_, false, acc) => acc) [] sieve
val v = Vector.fromList (List.rev primes)
val () = print (Int.toString (Vector.length v) ^ " " ^ Int.toString (Vector.sub (v, Vector.length v - 1)) ^ " "
                ^ Int.toString (Vector.foldl (fn (p, s) => (s + p) mod 1000003) 0 v) ^ "\n")
