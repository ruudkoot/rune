(* dump: --passes=shake,lift,workers,simplify,refs --dump-after=refs *)
(* Local refs as values (performance M8): `loop` only reads and sets its
   ref `i` and gives it on to its own call in tail position, and `count`
   gives it a ref made for it alone: a copy of `loop` takes the value, a
   set is the value from there on, and `count` calls the copy with 0, the
   ref not made. `total`'s ref is given on to another function, so `loop`
   is called with it as it is. *)
fun loop (i : int ref, n : int, acc : int ref) =
  if !i >= n then () else (acc := !acc + !i; i := !i + 1; loop (i, n, acc))
fun count (n, acc) = loop (ref 0, n, acc)
fun total n = let val acc = ref 0 in count (n, acc); !acc end
val r = total 10
