(* The file handles of the VM behind the readers and writers, and the
   readers and writers themselves. A handle is an int: 0 standard input,
   1 standard output, 2 standard error, the others from file_open. *)
structure RuneFile =
struct
  val zeroByte = Word8.fromInt 0

  val fileOpen = _prim "file_open" : string * int -> int option
  val fileClose = _prim "file_close" : int -> unit
  val fileWrite = _prim "file_write" : int * string -> bool
  val fileFlush = _prim "file_flush" : int -> unit
  val fileReadVec = _prim "file_read_vec" : int * int -> string
  val fileAvail = _prim "file_avail" : int -> int
  val fileError = _prim "file_error" : unit -> string

  val chunkSize = 4096

  fun sysError () = OS.SysErr (fileError (), NONE)

  (* mode: 0 read, 1 write and truncate, 2 append *)
  fun open' (function, mode) name =
    case fileOpen (name, mode) of
      SOME fd => fd
    | NONE => raise IO.Io {name = name, function = function, cause = sysError ()}

  fun readVec fd n = fileReadVec (fd, n)
  fun avail fd () = case fileAvail fd of ~1 => NONE | k => SOME k
  (* The VM holds what is written to a file until it is flushed, and flushes
     every file when the program ends, so a stream that buffers nothing of
     its own (the default NO_BUF) loses nothing. *)
  fun writeString (fd, name) s =
    if fileWrite (fd, s) then size s else raise sysError ()
  fun close (fd : int) () = fileClose fd
  fun closeNothing () = ()
  fun flush (fd : int) () = fileFlush fd
end
