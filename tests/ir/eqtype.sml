(* dump: --passes=shake,simplify --dump-after=simplify *)
(* `=` by type (performance M5, D7 B): of refs, ptr_eq, their addresses; of
   a datatype where one side is a nullary constructor, ptr_eq too, since
   the constructor is an immediate and no value in the heap equals it; of
   strings, string_eq; of ints and of a datatype of nullary constructors
   alone, imm_eq; of a tuple, poly_eq, which walks it; of two constant
   strings, and of a ref with itself, the answer. *)
datatype t = A | B of int
datatype u = X | Y
fun r (x : int ref, y) = x = y
fun n (x : t) = x = A
fun l (x : int list) = x = nil
fun s (x : string, y) = x = y
fun i (x : int, y) = x = y
fun e (x : u, y) = x = y
fun p (x : int * int, y) = x = y
val z = ref 0
val q = (r (z, ref 0), n (B 1), l [1], s ("a", "b"), i (1, 2), e (X, Y), p ((1, 2), (1, 2)),
         "ab" = "ab", "ab" = "abc", z = z)
