(* Becoming another program.

   `Runtime.restore` does from inside a running program what
   `runevm --restore` does to a VM that has just started. The image carries
   its own bytecode, so the program that runs afterwards need not be this
   one: what you have is a whole world, not a heap dropped into this one.

   Run examples/runtime/checkpoint.sml first to write checkpoint.img, then
   run this: it becomes that program, and its own code is never reached
   again. Nothing this world held -- its stack, its open files -- survives.

   An image it cannot read is the one way it comes back, and it raises, so a
   program can try one and carry on. *)

val () = print "this is become.sml\n"

val () =
  print ("an image that is not there: "
         ^ (Runtime.restore "no-such-world.img" handle OS.SysErr _ => "raised, still running")
         ^ "\n")

val () = print "becoming the world in checkpoint.img\n"
val () = Runtime.restore "checkpoint.img"
val () = print "this line is never reached\n"
