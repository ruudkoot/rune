(* Found by the generated functor programs (docs/testing.md, Generated
   functor programs), and not functors': at -O1 and above, --lint after
   lower says a constructor's int payload, matched (`C0 p1 => 1 + p1`), is
   a pointer where int_add wants an int. It prints right; -O0 is clean. *)
val count = ref 0
datatype t = C0 of int | C1 of string * int
fun mk_t (d, n) = if d <= 0 then C0 n else (case n mod 2 of 0 => C0 n | _ => C1 (Int.toString (n + 0), (n + 1) * 2))
fun obs v = (case v of C0 p1 => 1 + p1 | C1 (p2, p3) => size p2 + p3)
fun mk n = (count := !count + 1; mk_t (1, n))
val () = print (Int.toString (obs (mk 0)) ^ " " ^ Int.toString (obs (mk 1)) ^ "\n")
