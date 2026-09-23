(* What a run costs, from the counters the VM keeps anyway.

   Run it with `runevm --count` beside it: the instructions Runtime.stats
   reports are the ones --count prints when the program ends, short of the
   printing that has to come after the reading. *)

fun cells (0, acc) = acc
  | cells (n, acc) = cells (n - 1, n :: acc)

val () = print "building a list of 100,000 cells\n"

val start = Runtime.stats ()
val live = cells (100000, [])
val after = Runtime.stats ()

fun say (name, n) = print ("  " ^ name ^ ": " ^ Int.toString n ^ "\n")

val () = say ("instructions", #instructions after - #instructions start)
val () = say ("bytes", #bytes after - #bytes start)
val () = say ("objects", #objects after - #objects start)
val () = say ("collections", #collections after - #collections start)

(* Three objects a cell, and 104 bytes, where a list cell is two objects and
   64 bytes -- the pair of head and tail, and the `::` around it. The third is
   the argument of the recursive call: `cells` takes a pair, and a pair is an
   object like any other. A loop that allocates nothing takes one argument. *)
val () = say ("bytes a cell", (#bytes after - #bytes start) div 100000)
val () = say ("objects a cell", (#objects after - #objects start) div 100000)

(* Collecting makes `live` exactly the live data rather than an upper bound. *)
val () = Runtime.collect ()
val s = Runtime.stats ()
val () = say ("live after collecting", #live s)
val () = say ("semispace", #heapSize s)
val () = print ("the list is still " ^ Int.toString (List.length live) ^ " long\n")
