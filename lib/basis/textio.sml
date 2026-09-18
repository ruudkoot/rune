(* TextIO: standard streams and files. A stream carries its VM file handle
   (0 stdin, 1 stdout, 2 stderr, others from file_open), its name for error
   messages, and whether it has been closed. *)
structure TextIO =
struct
  datatype instream = In of {fd : int, name : string, closed : bool ref}
  datatype outstream = Out of {fd : int, name : string, closed : bool ref}

  val fileOpen = _prim "file_open" : string * int -> int option
  val fileClose = _prim "file_close" : int -> unit
  val fileWrite = _prim "file_write" : int * string -> bool
  val fileFlush = _prim "file_flush" : int -> unit
  val fileReadLine = _prim "file_read_line" : int -> string option
  val fileReadAll = _prim "file_read_all" : int -> string
  val fileError = _prim "file_error" : unit -> string

  fun ioError (name, function, cause) = raise IO.Io {name = name, function = function, cause = cause}
  fun sysError () = OS.SysErr (fileError (), NONE)

  val stdIn = In {fd = 0, name = "<stdin>", closed = ref false}
  val stdOut = Out {fd = 1, name = "<stdout>", closed = ref false}
  val stdErr = Out {fd = 2, name = "<stderr>", closed = ref false}

  fun openIn name =
    case fileOpen (name, 0) of
      SOME fd => In {fd = fd, name = name, closed = ref false}
    | NONE => ioError (name, "openIn", sysError ())

  fun openOutMode (function, mode) name =
    case fileOpen (name, mode) of
      SOME fd => Out {fd = fd, name = name, closed = ref false}
    | NONE => ioError (name, function, sysError ())
  fun openOut name = openOutMode ("openOut", 1) name
  fun openAppend name = openOutMode ("openAppend", 2) name

  fun closeIn (In {fd, closed, ...}) = (fileClose fd; closed := true)
  fun closeOut (Out {fd, closed, ...}) = (fileFlush fd; fileClose fd; closed := true)

  fun output (Out {fd, name, closed}, s) =
    if !closed then ioError (name, "output", IO.ClosedStream)
    else if fileWrite (fd, s) then () else ioError (name, "output", sysError ())
  fun output1 (out, c) = output (out, String.str c)
  fun outputSubstr (out, ss) = output (out, Substring.string ss)
  fun flushOut (Out {fd, ...}) = fileFlush fd
  val print = print

  fun inputLine (In {fd, name, closed}) =
    if !closed then ioError (name, "inputLine", IO.ClosedStream) else fileReadLine fd
  fun inputAll (In {fd, name, closed}) =
    if !closed then ioError (name, "inputAll", IO.ClosedStream) else fileReadAll fd
end
