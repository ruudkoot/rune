(* Traces of code the optimiser inlined (docs/plans/middle-end.md, D7):
   the same frames as the calls would have left. A function inlined where
   it was called in tail position leaves no frame, as the tail call would
   not have; a call in tail position of one inlined elsewhere shows as made
   from where that one was called, as its frame would have been replaced;
   and a call in tail position of a handler's region is no tail call. *)
fun show ({function, file, line, ...} : Runtime.frame) =
  print (function ^ " " ^ file ^ ":" ^ Int.toString line ^ "\n")
fun trace () = (List.app show (Runtime.trace ()); print "--\n")

fun leaf x = (trace (); x + 1)
fun viaTail x = leaf x                          (* a tail call: no frame *)
fun notTail x = leaf x * 2                      (* a frame *)
fun inRegion x = leaf x handle Div => 0         (* no tail call: a frame *)
fun twice x = notTail (viaTail x)
val _ = twice 1
val _ = inRegion 2

fun step x = if x > 100 then leaf x else x
fun outer x = step x + step (x + 200)
val _ = outer 3

(* a local function called once *)
fun once x =
  let fun go y = trace () before ignore (y + 1)
  in go x; 0 end
val _ = once 4

fun add (a, b) = a + b
fun scale x = add (x, 1) * 2
val () = print (Int.toString (scale (valOf Int.maxInt)) ^ "\n")
