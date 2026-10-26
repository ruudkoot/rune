(* dump: --passes=shake,simplify --dump-after=simplify *)
(* The simplifier folds a constant divided by a constant (functors-units
   M1), by the floor for ints: 17 div 5 is 3, ~17 div 5 is ~4, 17 mod ~5
   is ~3, ~17 mod ~5 is ~2, 0w17 div 0w5 is 0w3 and 0w17 mod 0w5 is 0w2.
   What would raise is left to: a division by 0 (Div), and the least int
   divided by ~1 (Overflow), whose mod by ~1 is 0. *)
val a = 17 div 5
val b = ~17 div 5
val c = 17 mod ~5
val d = ~17 mod ~5
val e = 0w17 div 0w5
val f = 0w17 mod 0w5
val g = 1 div 0 handle Div => 1
val h = 0w1 mod 0w0 handle Div => 0w1
val i = ~4611686018427387904 div ~1 handle Overflow => 2
val j = ~4611686018427387904 mod ~1
