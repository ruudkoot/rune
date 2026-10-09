(* A word past 63 bits in a home of tier 2 that C keeps, on the machine
   whose ints and words keep 64 bits (bin/runevm-int64, a compiler given
   --int-bits=64; make test-int64). There the home holds the word, a box's
   address, and the primitives that box the products call into C and
   collect: w, the heaviest register, gets rbx or r12, and after the
   first collection of the nursery its home is loaded again from its slot,
   which the collector moved on (runtime/register/jit/masm.c, may_move),
   or it reads the nursery that the next boxes fill. *)
fun loop (w : word, acc : word, n : int) =
  if n = 0 then acc
  else loop (w, (acc * w + w) * w + w, n - 1)
val w = Word.<< (0w1, 0w63) + 0w12345
val () = print (Word.toString (loop (w, 0w0, 1000000)) ^ "\n")
