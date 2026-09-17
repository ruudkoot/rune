fun counter () = let val n = ref 0 in fn () => (n := !n + 1; !n) end
val c1 = counter ()
val c2 = counter ()
val () = print (Int.toString (c1 ()) ^ Int.toString (c1 ()) ^ Int.toString (c2 ()) ^ Int.toString (c1 ()) ^ "\n")
fun adders () = List.tabulate (3, fn i => fn x => x + i)
val () = print (String.concatWith "," (map (fn f => Int.toString (f 10)) (adders ())) ^ "\n")
(* mutual recursion between local closures capturing free variables *)
fun outer k =
  let
    fun ev 0 = true | ev n = od (n - 1)
    and od 0 = false | od n = ev (n - 1)
    val base = k * 2
    fun addBase x = x + base
  in
    (ev k, addBase 1, addBase)
  end
val (e, b, f) = outer 5
val () = print (Bool.toString e ^ Int.toString b ^ Int.toString (f 100) ^ "\n")
(* closures stored in data structures and returned through several levels *)
fun compose3 f g h = fn x => f (g (h x))
val () = print (Int.toString (compose3 (fn x => x + 1) (fn x => x * 2) (fn x => x - 3) 10) ^ "\n")
