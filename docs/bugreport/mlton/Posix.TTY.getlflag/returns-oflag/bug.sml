(* Each getter of Posix.TTY should give its own field of a termios. *)
structure T = Posix.TTY
val t = T.termios {iflag = T.I.icrnl, oflag = T.O.opost, cflag = T.C.cs8,
                   lflag = T.L.echo, cc = T.V.cc [], ispeed = T.b0, ospeed = T.b0}
fun show (name, got, expected) =
    print (name ^ " = 0wx" ^ SysWord.toString got
           ^ "   (expected 0wx" ^ SysWord.toString expected ^ ")\n")
val () = show ("getiflag t", T.I.toWord (T.getiflag t), T.I.toWord T.I.icrnl)
val () = show ("getoflag t", T.O.toWord (T.getoflag t), T.O.toWord T.O.opost)
val () = show ("getcflag t", T.C.toWord (T.getcflag t), T.C.toWord T.C.cs8)
val () = show ("getlflag t", T.L.toWord (T.getlflag t), T.L.toWord T.L.echo)
val () = show ("#lflag (fieldsOf t)", T.L.toWord (#lflag (T.fieldsOf t)), T.L.toWord T.L.echo)
