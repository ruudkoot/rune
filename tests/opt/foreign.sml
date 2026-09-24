(* Runtime.restore of an image of another program, in a program runeopt
   made: its code is the translation of its own program alone, so it refuses,
   and goes on (docs/native.md, Images). Under runevm it would become
   the other world. tests/opt runs it natively only. *)
val () = (Runtime.restore "tests/out/rt.save_first.img"; print "restored\n")
         handle OS.SysErr (_, SOME e) => print ("refused: " ^ OS.errorName e ^ "\n")
