(* Posix.Process.sleep t sleeps t and returns the time that is left: none,
   when no signal came. *)
fun try t =
  let val start = Time.now ()
      fun took () = Time.toString (Time.- (Time.now (), start))
  in print ("sleep " ^ Time.toString t ^ ": returned " ^ Time.toString (Posix.Process.sleep t)
            ^ " after " ^ took () ^ " s\n")
     handle e => print ("sleep " ^ Time.toString t ^ ": raised " ^ exnName e ^ " after " ^ took () ^ " s\n")
  end
val () = List.app try [Time.fromSeconds 1, Time.fromMilliseconds 250, Time.zeroTime]
