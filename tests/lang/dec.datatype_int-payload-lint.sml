(* Found by the generated functor programs, and not functors': from -O1,
   `mk_t` returns its constructor's fields in the datatype's globals
   (Lower's results), one global holding C0's int and C1's string, and the
   variable read from it took the representation of C1's binding, a
   pointer, where `C0 p1 => 1 + p1` adds it as an int: --lint after lower
   refused it, and the register code said so to the JIT. It holds anything
   now (Lower.defAny). *)
val count = ref 0
datatype t = C0 of int | C1 of string * int
fun mk_t (d, n) = if d <= 0 then C0 n else (case n mod 2 of 0 => C0 n | _ => C1 (Int.toString (n + 0), (n + 1) * 2))
fun obs v = (case v of C0 p1 => 1 + p1 | C1 (p2, p3) => size p2 + p3)
fun mk n = (count := !count + 1; mk_t (1, n))
val () = print (Int.toString (obs (mk 0)) ^ " " ^ Int.toString (obs (mk 1)) ^ "\n")
