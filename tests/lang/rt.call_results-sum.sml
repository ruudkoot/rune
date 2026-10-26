(* A function that returns a constructor of its datatype, only called and
   taken apart, returns the tag and leaves the argument in globals (Lower,
   results in globals, from -O1): one global holds the first field of each
   constructor -- here a string of Event and an int of Begin -- and is of
   any representation where it is read, whichever constructor's field the
   first use takes (LowLint refused it). step calls itself, so that it is
   not inlined. *)
datatype step = Event of string * int | Wait | Begin of int
fun step (s : string, i : int) : step =
  if i >= size s then Wait
  else if String.sub (s, i) = #" " then step (s, i + 1)
  else if String.sub (s, i) = #"[" then Begin (i + 2)
  else Event (String.str (String.sub (s, i)), 1)
fun go (s, i, acc) =
  case step (s, i) of
    Event (e, n) => go (s, i + n, e :: acc)
  | Begin n => go (s, n, "<" ^ Int.toString n ^ ">" :: acc)
  | Wait => String.concat (rev acc)
val () = print (go ("ab[cd [ef", 0, []) ^ "\n")
