(* rt.restore: a program becomes the world in an image without leaving the
   process. The image brings its own bytecode, so what runs afterwards need
   not be this program at all; here it is an earlier world of it, which is
   what one file can show. A count kept in a file is what tells the restored
   world when to stop, since every restored world is otherwise identical. *)
val img = "tests/out/rt.restore_world.img"
val counter = "tests/out/rt.restore_world.count"

fun writeCount n =
  let val f = TextIO.openOut counter
  in TextIO.output (f, Int.toString n); TextIO.closeOut f end

fun readCount () =
  let val f = TextIO.openIn counter
      val s = TextIO.inputAll f
      val () = TextIO.closeIn f
  in valOf (Int.fromString s) end

(* an image it cannot read leaves this world running, and raises *)
val () = print ("not an image: "
                ^ (Runtime.restore "tests/lang/rt.restore_world.sml"
                   handle OS.SysErr _ => "raised, still here") ^ "\n")

val ballast = List.tabulate (500, fn i => i)

val () =
  case Runtime.save img of
    Runtime.Saved => (writeCount 3; print "saved\n")
  | Runtime.Restored =>
      let val n = readCount ()
      in
        print ("world " ^ Int.toString n ^ ", ballast " ^ Int.toString (List.length ballast) ^ "\n");
        if n <= 1 then print "done\n"
        else (writeCount (n - 1); Runtime.restore img);
        print (if n <= 1 then "the last world runs on\n" else "NEVER REACHED\n")
      end
