(* The i32chk wrapper of target64-inline.sml, which fix.diff puts around
   Int32.abs, copied into a standalone program: InLine.cast is Unsafe.cast and
   InLine.int_lt is Int.< here. On a 64-bit build the wrapped abs raises
   Overflow for minInt and agrees with Int32.abs everywhere else (minInt + 1,
   maxInt, 0, +-1 and 100,000 other values). Run: sml fix-check.sml *)
val castToInt : Int32.int -> int = Unsafe.cast
fun i32chk oper args = let
      val res = oper args
      in
        if Int.<(castToInt res, ~2147483648)
        orelse Int.<(2147483647, castToInt res)
          then raise Overflow
          else res
      end
val abs = i32chk Int32.abs
val r = ref (valOf Int32.minInt)
val () = print ("wrapped abs minInt = " ^ (Int32.toString (abs (!r)) handle Overflow => "Overflow") ^ "\n")
val rng = Random.rand (1, 2)
val xs = valOf Int32.minInt + 1 :: valOf Int32.maxInt :: 0 :: 1 :: ~1
         :: List.tabulate (100000, fn _ => Int32.fromInt (Random.randRange (~1073741824, 1073741823) rng) * 2)
val differ = List.filter (fn x => abs x <> Int32.abs x) xs
val () = print (Int.toString (length differ) ^ " of " ^ Int.toString (length xs) ^ " other values differ from Int32.abs\n")
val () = OS.Process.exit OS.Process.success
