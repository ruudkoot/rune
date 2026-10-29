(* A probe of Terminal for tests/terminal: the terminal raw, its size,
   then what is typed, as hex, a line for each burst (bytes that come with
   less than 150 ms between them, so that a key split over two reads is
   still one line), and a line when the window changes its size. Some
   keys end it, each in another way, for the scripts that check the
   terminal is cooked again afterwards: q returns, x raises an exception
   no one handles, f recurses until the stack is too deep (a fatal error),
   t and h send the process SIGTERM and SIGHUP. *)
fun hex s =
  String.concatWith " " (map (fn c => StringCvt.padLeft #"0" 2 (String.map Char.toLower (Int.fmt StringCvt.HEX (ord c))))
                             (explode s))
fun say s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut)
fun sizeText () =
  case Terminal.size () of
    SOME {columns, rows} => Int.toString columns ^ "x" ^ Int.toString rows
  | NONE => "none"
fun deep n = 1 + deep (n + 1)
fun signal s = Posix.Process.kill (Posix.Process.K_PROC (Posix.ProcEnv.getpid ()), s)

fun burst (got, seen) =
  case Terminal.read (SOME (Time.fromMilliseconds 150)) of
    NONE => (got, seen, true)
  | SOME "" =>
      let val r = Terminal.resizes ()
      in
        if r <> seen then (say ("resized " ^ sizeText ()); burst (got, r))
        else (got, seen, false)
      end
  | SOME s => burst (got ^ s, seen)

fun loop seen =
  case burst ("", seen) of
    (_, _, true) => say "end"
  | ("", seen, false) => loop seen
  | (s, seen, false) =>
      (say ("keys " ^ hex s);
       case s of
         "q" => ()
       | "x" => raise Fail "no one handles this"
       | "f" => ignore (deep 0)
       | "t" => signal Posix.Signal.term
       | "h" => signal Posix.Signal.hup
       | _ => loop seen)

val () = Terminal.enter {undo = ""}
(* the first resizes installs SIGWINCH. A resize before that is ignored,
   so the count is taken before the size is said: the script resizes as
   soon as it sees the size. *)
val seen = Terminal.resizes ()
val () = say ("size " ^ sizeText ())
val () = loop seen
val () = Terminal.leave ()
val () = say "bye"
