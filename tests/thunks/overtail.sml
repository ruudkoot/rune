(* An over-applied call in tail position through <apply 1 1> (D15 C),
   made by compiled code entered past the stack's clean part: app is a
   call of two arguments in tail position through g, a closure of one
   parameter (through a ref, so that no pass knows it), which compiled
   code makes by putting g's arguments and g above the frame, claiming the
   room <apply 1 1> needs, and moving them down into the frame's place.
   deep k recurses k frames first; where it leaves for the interpreter at
   every instruction (--deopt-stress, at tier 1 and tier 2), the
   interpreter's frames go past what compiled code claimed, so app's claim
   is a real one, which makes the clean part unit from the frame's
   registers' end, the copies among it: the claim must make the call again
   (the final nightly's hs/jit lib.r.directory.create.err.parent and
   renamefile.nodir, where <apply 1 1> called unit). args: k *)
val f : (int -> int -> int) ref = ref (fn a => (if a < 0 then print "neg\n" else (); fn b => a * 10 + b))
fun app (g : int -> int -> int) x y = g x y
val appr = ref app
fun deep k = if k = 0 then !appr (!f) 4 2 else 1 + deep (k - 1)
val k = case CommandLine.arguments () of a :: _ => getOpt (Int.fromString a, 10) | [] => 10
val () = print (Int.toString (deep k) ^ "\n")
