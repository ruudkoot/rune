(* Runtime: what the VM counts for the program it is running. The counters
   themselves depend on the library and on everything done before them, so
   what is printed is what the documentation promises of them: the cost of a
   shape whose size is known, and how the numbers stand to one another. *)
val keep : int list ref = ref []
(* called through a ref, which no optimisation sees through: had stats been
   inlined in one measurement and not in another, its record would be made
   in one and not in the other *)
val stats = ref Runtime.stats
fun allocated f =
  let
    val a = !stats ()
    val () = f ()
    val b = !stats ()
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
(* kept, where an unused one would be no allocation at all once optimised *)
val cell = ref (ref 0)
val () = show ("a ref", less (allocated (fn () => cell := ref 7), nothing ()))
val s = Runtime.stats ()
val () = print ("instructions grow: "
                ^ Bool.toString (#instructions s < #instructions (Runtime.stats ())) ^ "\n")
val () = print ("live within the semispace: " ^ Bool.toString (#live s <= #heapSize s) ^ "\n")
val () = print ("allocated covers what is in use: " ^ Bool.toString (#bytes s >= #live s) ^ "\n")
val () = print ("kept: " ^ Int.toString (List.length (!keep)) ^ "\n")
val was = #collections (Runtime.stats ())
val () = Runtime.collect ()
val () = print ("collect makes one collection: "
                ^ Bool.toString (#collections (Runtime.stats ()) - was = 1) ^ "\n")
val r = ref 0
val held = r
val () = Runtime.collect ()
val () = print ("a ref is itself across a collection: " ^ Bool.toString (Runtime.same (r, held)) ^ "\n")
val () = print ("two equal refs are two: " ^ Bool.toString (not (Runtime.same (ref 0, ref 0))) ^ "\n")
val (answer, cost) = Runtime.profile (fn () => keep := 1 :: !keep)
val (_, nothing') = Runtime.profile (fn () => ())
val () = print ("profile sees the cell and nothing else: "
                ^ Bool.toString (#bytes cost - #bytes nothing' = 64
                                 andalso #objects cost - #objects nothing' = 2) ^ "\n")
val () = print ("profile returns the value: " ^ Bool.toString (answer = ()) ^ "\n")
val () = print ("version is three numbers: "
                ^ Bool.toString (List.length (String.fields (fn c => c = #".") Runtime.version) = 3) ^ "\n")
