(* Runtime: what the VM counts for the program it is running. The counters
   themselves depend on the library and on everything done before them, so
   what is printed is what the documentation promises of them: the cost of a
   shape whose size is known, and how the numbers stand to one another. *)
val keep : int list ref = ref []
fun allocated f =
  let
    val a = Runtime.stats ()
    val () = f ()
    val b = Runtime.stats ()
  in
    (#bytes b - #bytes a, #objects b - #objects a)
  end
(* measuring costs one `stats` record, the same in every measurement *)
fun nothing () = allocated (fn () => keep := !keep)
fun less ((b, ob), (b0, o0)) = (b - b0, ob - o0)
fun plural (n, w) = Int.toString n ^ " " ^ w ^ (if n = 1 then "" else "s")
fun show (name, (b, ob)) =
  print (name ^ ": " ^ plural (b, "byte") ^ ", " ^ plural (ob, "object") ^ "\n")
val () = show ("a list cell", less (allocated (fn () => keep := 1 :: !keep), nothing ()))
val () = show ("a ref", less (allocated (fn () => ignore (ref 7)), nothing ()))
val s = Runtime.stats ()
val () = print ("instructions grow: "
                ^ Bool.toString (#instructions s < #instructions (Runtime.stats ())) ^ "\n")
val () = print ("live within the semispace: " ^ Bool.toString (#live s <= #heapSize s) ^ "\n")
val () = print ("allocated covers what is in use: " ^ Bool.toString (#bytes s >= #live s) ^ "\n")
val () = print ("kept: " ^ Int.toString (List.length (!keep)) ^ "\n")
