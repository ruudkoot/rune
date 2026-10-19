(* dump: --passes=shake,workers,simplify,specialise,inline --dump-after=simplify *)
(* A loop given a local function that it gives on to a function that does
   not call itself (performance M8, as MLton's peek does): the loop's copy
   is a copy of that function too, which calls the local function's code,
   so no closure is made; and a function that makes a function and returns
   it in a tuple, small as it is, is put where it is called, where the
   function it makes is known. *)
fun make (k : int) = (k, fn (x : int) => x + k)
fun many (f : int -> int, x : int) =
  f (f (f (f (f (f (f (f (f (f (f (f (f x))))))))))))
fun loop (f : int -> int, i : int, acc : int) =
  if i = 0 then acc else loop (f, i - 1, acc + many (f, i))
val r = let val (_, g) = make 3 in loop (g, 10, 0) end
val s = many (fn x => x * 2, 1)
