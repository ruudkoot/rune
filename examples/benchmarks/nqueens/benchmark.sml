(* Sandmark's sequential depth-first counter, distinct from nofib's level
   generator. The mutable sibling counter and board suffixes are preserved. *)
structure Benchmark =
struct
  val name = "nqueens"
  fun ok _ _ _ [] = true
    | ok i j k (h::t) = h <> i andalso h <> j andalso h <> k andalso ok i (j+1) (k-1) t
  fun queens n j xs =
    if n = j then 1
    else let val count = ref 0
             fun loop i =
               if i = n then ()
               else (if ok i (i+1) (i-1) xs then count := !count + queens n (j+1) (i::xs) else ();
                     loop (i+1))
             val _ = loop 0
         in !count end
  fun run [size] =
    let val n = BenchInput.between (1,14) (BenchInput.integer size)
    in Int.toString (queens n 0 []) end
    | run _ = raise Fail "nqueens expects board size"
end
