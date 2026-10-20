(* dump: --passes=shake,workers,simplify,specialise,inline --dump-after=simplify *)
(* A function of the top level that passes its function on to itself,
   given a local function that captures a variable (performance M8): a
   copy of it calls the local function's code, made a function of the top
   level of what it captured and its parameter, and is given what the
   local function captured, so that no closure is made; the copy then
   puts that code in place, small as it is. *)
fun map (f : int -> int, l : int list) =
  case l of [] => [] | x :: r => f x :: map (f, r)
fun add (k : int, l) = map (fn x => x + k, l)
val r = add (3, [1, 2])
