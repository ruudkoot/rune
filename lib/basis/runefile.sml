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
  val fileErrno = _prim "file_errno" : unit -> int
  (* the descriptor of the system under a handle, which is what an iodesc is *)
  val descriptor = _prim "file_descriptor" : int -> int
  val fileTell = _prim "file_tell" : int -> int
  val fileSeek = _prim "file_seek" : int * int -> int

  val chunkSize = 4096

  fun sysError () = RuneError.SysErr (fileError (), SOME (fileErrno ()))

  (* mode: 0 read, 1 write and truncate, 2 append *)
  fun open' (function, mode) name =
    case fileOpen (name, mode) of
      SOME fd => fd
    | NONE => raise IO.Io {name = name, function = function, cause = sysError ()}

  fun readVec fd n = fileReadVec (fd, n)
  fun avail fd () = case fileAvail fd of ~1 => NONE | k => SOME k

  (* The positions of a file, for its reader or its writer, when it has them
     (a regular file; a pipe or a terminal has none): bytes from the start.
     After close only getPos works, and gives the position the file had
     ("Further operations on the reader (besides close and getPos) raise").
     The second result is what close has to call first. *)
  fun positions (fd, name, closed : bool ref) =
    if fileTell fd < 0 then ({getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE}, fn () => ())
    else
      let
        val last = ref 0
        fun closedIo function = raise IO.Io {name = name, function = function, cause = IO.ClosedStream}
        fun tell () = case fileTell fd of ~1 => raise sysError () | p => p
        fun getPos () = if !closed then !last else tell ()
        fun setPos p =
          if !closed then closedIo "setPos"
          else if fileSeek (fd, p) < 0 then raise sysError ()
          else ()
        fun endPos () =
          if !closed then closedIo "endPos"
          else case fileAvail fd of ~1 => raise sysError () | k => tell () + k
        fun verifyPos () = if !closed then closedIo "verifyPos" else tell ()
      in
        ({getPos = SOME getPos, setPos = SOME setPos, endPos = SOME endPos, verifyPos = SOME verifyPos},
         fn () => last := (tell () handle _ => !last))
      end
  (* The VM holds what is written to a file until it is flushed, and flushes
     every file when the program ends. A stream over such a file reports the
     mode the specification asks for (BLOCK_BUF, or LINE_BUF on a terminal)
     but holds nothing of its own, so nothing is lost and what a program
     writes through print and through a stream stays in order. *)
  fun writeString (fd, name) s =
    if fileWrite (fd, s) then size s else raise sysError ()
  fun close (fd : int) () = fileClose fd
  fun closeNothing () = ()
  fun flush (fd : int) () = fileFlush fd
end
