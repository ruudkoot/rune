(* Arguments in registers (docs/plans/native-frames.md, M6): calls whose
   arguments are the caller's parameters in another order, so that putting
   them into the callee's homes is a parallel move with cycles; a parameter
   the callee never reads; and tail calls that permute their arguments. *)
fun rot (0, a, b, c, d) = a * 1000 + b * 100 + c * 10 + d
  | rot (n, a, b, c, d) = rot (n - 1, b, c, d, a)   (* a tail call: a cycle of four *)
fun swap (0, a, b, _) = a - b
  | swap (n, a, b, unused) = 1 + swap (n - 1, b, a, unused) + swap (n - 1, a + 1, b, a)
fun mix (0, x, y, z) = x + 2 * y + 3 * z
  | mix (n, x, y, z) = mix (n - 1, z, x, y) + mix (n - 1, y, z, x)
val () = print (Int.toString (rot (7, 1, 2, 3, 4)) ^ " " ^ Int.toString (swap (12, 5, 3, 0)) ^ " "
                ^ Int.toString (mix (10, 1, 2, 3)) ^ "\n")
