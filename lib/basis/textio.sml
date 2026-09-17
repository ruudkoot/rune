(* TextIO: standard streams only. *)
structure TextIO =
struct
  datatype outstream = StdOut | StdErr
  datatype instream = StdIn

  val stdOut = StdOut
  val stdErr = StdErr
  val stdIn = StdIn

  fun output (StdOut, s) = (_prim "print" : string -> unit) s
    | output (StdErr, s) = (_prim "print_err" : string -> unit) s

  fun output1 (out, c) = output (out, String.str c)
  fun outputSubstr (out, s) = output (out, s)

  fun flushOut StdOut = (_prim "flush_out" : unit -> unit) ()
    | flushOut StdErr = ()

  val print = print

  fun inputLine StdIn = (_prim "input_line" : unit -> string option) ()
  fun inputAll StdIn = (_prim "input_all" : unit -> string) ()

  fun closeOut _ = ()
  fun closeIn _ = ()
end
