(* Strict Fibonacci recurrence shared by classic fib and Sandmark rec_seq_fib.
   Original sources and notices are retained in both benchmark directories. *)
structure BenchFib =
struct
  fun fib 0 = 0
    | fib 1 = 1
    | fib n = fib (n - 1) + fib (n - 2)
end
