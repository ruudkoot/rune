(* A long vector of characters or bytes is made in place: CharVector's and
   Word8Vector's tabulate, and so CharArraySlice's and Word8ArraySlice's
   vector, made it of a list, which List.tabulate makes by recursion as deep
   as it is long, and stopped with "stack overflow" on a long one (a
   fingerprint of 10 MB through CharArraySlice.vector, functors-units M4).
   Run under a 1 MB stack (.vmargs); f is applied from 0 up. *)
val n = 300000
val s = CharVector.tabulate (n, fn i => Char.chr (97 + i mod 26))
val () = print (Int.toString (size s) ^ " " ^ String.substring (s, n - 10, 10) ^ "\n")
val order = ref 0
val ok = ref true
val _ = CharVector.tabulate (n, fn i => (if i = !order then order := i + 1 else ok := false; #"x"))
val () = print (Bool.toString (!ok andalso !order = n) ^ "\n")
val w = Word8Vector.tabulate (n, fn i => Word8.fromInt (i mod 251))
val () = print (Int.toString (Word8Vector.length w) ^ " " ^ Word8.toString (Word8Vector.sub (w, n - 1)) ^ "\n")
val a = CharArray.tabulate (n, fn i => Char.chr (65 + i mod 26))
val v = CharArraySlice.vector (CharArraySlice.slice (a, 10, NONE))
val () = print (Int.toString (size v) ^ " " ^ String.substring (v, 0, 5) ^ "\n")
val b = Word8Array.tabulate (n, fn i => Word8.fromInt (i mod 256))
val u = Word8ArraySlice.vector (Word8ArraySlice.slice (b, 1, SOME (n - 2)))
val () = print (Int.toString (Word8Vector.length u) ^ " " ^ Word8.toString (Word8Vector.sub (u, 0)) ^ "\n")
val () = print ((ignore (CharVector.tabulate (~1, fn _ => #"x")); "no Size\n") handle Size => "Size\n")
