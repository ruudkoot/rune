(* Not functors': at -O1 and above, --lint after lower said a constructor's
   int payload, matched (`C0 p1 => 1 + p1`), was a pointer where int_add
   wants an int, with the flag or without: a global Lower's results shared
   between constructors took one constructor's representation (fixed by
   28d93a928; tests/lang/dec.datatype_int-payload-lint.sml). The generated
   programs met it in a functor's body. *)
(* unit u0.sml *)
val count = ref 0
datatype t = C0 of int | C1 of string * int
fun mk_t (d, n) = if d <= 0 then C0 n else (case n mod 2 of 0 => C0 n | _ => C1 (Int.toString (n + 0), (n + 1) * 2))
fun obs v = (case v of C0 p1 => 1 + p1 | C1 (p2, p3) => size p2 + p3)
fun mk n = (count := !count + 1; mk_t (1, n))
val () = print (Int.toString (obs (mk 0)) ^ " " ^ Int.toString (obs (mk 1)) ^ "\n")
(* options --inline-functor= --functor-budget=0 *)
