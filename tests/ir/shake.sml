(* dump: --passes=shake --dump-after=shake *)
(* Tree shaking: what nothing done for its effect reaches goes -- a
   function nothing calls, a pure value nothing reads, and a function of a
   group whose other member is reached; kept are a value that may raise
   (div), and what the effect uses: the reference and the function set
   into it, and the value that function is given. *)
fun unused x = x + 1
fun keepMe n = n + 1
and dropMe n = keepMe n * 2
val dead = (1, 2)
val used = 3
val kept = 10 div used
val r = ref 0
val _ = r := keepMe used
