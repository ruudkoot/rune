(* rt.save: a world written to a file and taken up again, with an answer that
   depends on the heap, on a string, on a real, on the stack and on arrays
   of bytes and of reals -- so that a
   restore which gets a width, an alignment or the order of the bytes wrong
   cannot agree by accident. Both worlds print the same line, which is what
   `make test-windows` and `make test-portability` compare when one machine
   saves and another restores (tests/run-windows.sh, tests/run-portability.sh). *)
fun count (0, acc) = acc | count (n, acc) = count (n - 1, n :: acc)
val live = count (2000, [])
val text = String.concat (List.map Int.toString (List.take (live, 40)))
val r = 2.718281828459045
(* the arrays whose elements are not values: bytes, and the reals themselves,
   which an image writes in an order of its own *)
val bytes = Word8Array.tabulate (300, fn i => Word8.fromInt (i * 7))
val chars = CharArray.array (5, #"q")
val reals = RealArray.fromList [1.5, ~0.0, 4.9E~324, Real.posInf, r]
fun answer () =
  Int.toString (List.foldl (op +) 0 live) ^ " " ^ Int.toString (String.size text)
  ^ " " ^ Real.fmt (StringCvt.FIX (SOME 9)) r
  ^ " " ^ Int.toString (List.length (Runtime.trace ()))
  ^ " " ^ Int.toString (Word8Array.foldl (fn (b, h) => (h * 31 + Word8.toInt b) mod 1000003) 0 bytes)
  ^ " " ^ CharArray.vector chars
  ^ " " ^ String.concatWith "," (RealArray.foldr (fn (x, l) => Real.toString x :: l) [] reals)
val () =
  case Runtime.save "tests/out/rt.save_restore_cross.img" of
    Runtime.Saved => print (answer () ^ "\n")
  | Runtime.Restored => print (answer () ^ "\n")
