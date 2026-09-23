(* `profile` runs its argument and says what it cost.

   The cost of measuring is inside the answer -- one `stats` record and the
   instructions of reading the counters twice -- so profiling nothing is that
   cost, and taking it away leaves the work itself. *)

fun sum (0, acc) = acc
  | sum (n, acc) = sum (n - 1, acc + n)

fun rev' ([], acc) = acc
  | rev' (x :: xs, acc) = rev' (xs, x :: acc)

fun report (what, (_, s : Runtime.stats)) =
  print (what ^ ": " ^ Int.toString (#instructions s) ^ " instructions, "
         ^ Int.toString (#bytes s) ^ " bytes, " ^ Int.toString (#objects s) ^ " objects\n")

val (_, nothing) = Runtime.profile (fn () => ())
val () = report ("measuring itself", ((), nothing))

val () = report ("summing to 100,000", Runtime.profile (fn () => sum (100000, 0)))
val () = report ("reversing 10,000 cells",
                 Runtime.profile (fn () => rev' (List.tabulate (10000, fn i => i), [])))

(* Summing looks as though it should allocate nothing -- the loop is
   tail-recursive and an int is not in the heap -- and yet it allocates 40
   bytes an iteration. They are the argument: `sum` takes a pair, and a pair
   of two fields is 8 bytes of header and 16 for each field.

   The same loop written over one argument allocates nothing at all, which is
   the kind of thing these counters are for. *)

fun countdown 0 = 0
  | countdown n = countdown (n - 1)

val (_, pair) = Runtime.profile (fn () => sum (100000, 0))
val (_, single) = Runtime.profile (fn () => countdown 100000)
val () = print ("a pair of arguments, 100,000 times: "
                ^ Int.toString (#bytes pair - #bytes nothing) ^ " bytes\n")
val () = print ("one argument, 100,000 times: "
                ^ Int.toString (#bytes single - #bytes nothing) ^ " bytes\n")
