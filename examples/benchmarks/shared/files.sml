(* Byte-exact checks for deterministic generated artifacts. *)
structure BenchFiles =
struct
  fun same (actual, expected) =
    let val a = BinIO.openIn actual
        val b = BinIO.openIn expected
        fun loop (size, hash) =
          let val x = BinIO.inputN (a, 4096)
              val y = BinIO.inputN (b, 4096)
              val n = Word8Vector.length x
              fun check i = i = n orelse
                (Word8Vector.sub (x,i) = Word8Vector.sub (y,i) andalso check (i+1))
              fun fold (i,h) = if i=n then h else fold (i+1,
                Word32.+ (Word32.* (h,0w16777619),Word32.fromInt(Word8.toInt(Word8Vector.sub(x,i)))))
          in if n <> Word8Vector.length y orelse not (check 0) then raise Fail ("artifact differs: " ^ actual)
             else if n=0 then (size,hash) else loop(IntInf.+(size,IntInf.fromInt n),fold(0,hash)) end
        val result = loop (0,0w2166136261) handle e => (BinIO.closeIn a;BinIO.closeIn b;raise e)
        val _ = BinIO.closeIn a
        val _ = BinIO.closeIn b
    in IntInf.toString (#1 result) ^ " " ^ Word32.toString (#2 result) end
end
