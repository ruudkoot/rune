(* The files of a program the Core interpreter runs (CoreInterp, and the
   families of primitives of CorePrimFamily): its handles, 0 to 2 standard
   input, output and error and the files it opened from 3, each a
   descriptor of the system's, read and written with no buffer, so that a
   position is what the VM's tell gives, and the error of the system's
   last call that failed, its number and its text. What standard input has
   given and a read has not yet, where it gave more than was asked for,
   waits in `pending`; standard output and error are the interpreter's
   own, written by it, not here. *)
structure CoreFiles =
struct
  datatype file = Open of Posix.IO.file_desc | Closed

  val files : (int * file) list ref = ref []
  val next = ref 3
  val pending = ref ""
  (* the last failure of an open, a write, a tell or a seek, as the VM's
     file_error and file_errno give it; and of a call of the system's, as
     its sys_errno *)
  val lastError = ref ""
  val lastErrno = ref 0
  val sysErrno = ref 0

  fun reset () = (files := []; next := 3; pending := ""; lastError := ""; lastErrno := 0; sysErrno := 0)

  fun errnoOf e =
    case e of
      OS.SysErr (_, SOME n) => SysWord.toInt (Posix.Error.toWord n)
    | _ => 0
  fun textOf e =
    case e of
      OS.SysErr (msg, _) => msg
    | IO.Io {cause = OS.SysErr (msg, _), ...} => msg
    | _ => exnMessage e
  (* a failure of a file's, which the next file_error and file_errno say *)
  fun failed e = (lastError := textOf e; lastErrno := errnoOf e)

  fun descriptorOf h =
    case h of
      0 => SOME Posix.FileSys.stdin
    | _ => (case List.find (fn (k, _) => k = h) (!files) of SOME (_, Open fd) => SOME fd | _ => NONE)

  (* a file opened to read (mode 0), to write from empty (1) or to append
     (2): its handle, or ~1, the failure kept *)
  fun openFile (path, mode) =
    let
      val perms = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.irgrp,
                                         Posix.FileSys.S.iwgrp, Posix.FileSys.S.iroth, Posix.FileSys.S.iwoth]
      val fd =
        case mode of
          0 => Posix.FileSys.openf (path, Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
        | 1 => Posix.FileSys.createf (path, Posix.FileSys.O_WRONLY, Posix.FileSys.O.trunc, perms)
        | _ => Posix.FileSys.createf (path, Posix.FileSys.O_WRONLY, Posix.FileSys.O.append, perms)
      val h = !next
    in
      next := h + 1; files := (h, Open fd) :: !files; h
    end
    handle e as OS.SysErr _ => (failed e; ~1)

  fun close h =
    (case (h > 2, descriptorOf h) of
       (true, SOME fd) => (Posix.IO.close fd handle OS.SysErr _ => ())
     | _ => ();
     files := List.map (fn (k, f) => if k = h then (k, Closed) else (k, f)) (!files))

  (* at most n bytes, waiting for one; "" at the end, and from a handle that
     is closed or none *)
  fun read (h, n) =
    let
      fun upTo s = if size s <= n then s else (pending := String.extract (s, n, NONE); String.substring (s, 0, n))
      fun fromDescriptor fd = Byte.bytesToString (Posix.IO.readVec (fd, n))
    in
      if n = 0 then ""
      else if h = 0 andalso !pending <> "" then upTo (!pending before pending := "")
      else
        case descriptorOf h of
          SOME fd => if h = 0 then upTo (fromDescriptor fd) else fromDescriptor fd
        | NONE => ""
    end

  (* the bytes written to a file; false where it fails, the failure kept *)
  fun write (h, s) =
    case descriptorOf h of
      NONE => (lastError := "Bad file descriptor"; lastErrno := 9; false)
    | SOME fd =>
        let
          val v = Byte.stringToBytes s
          fun go i = if i >= Word8Vector.length v then ()
                     else go (i + Posix.IO.writeVec (fd, Word8VectorSlice.slice (v, i, NONE)))
        in go 0; true end
        handle e as OS.SysErr _ => (failed e; false)

  (* the position of a file in bytes, ~1 where it has none *)
  fun tell h =
    case descriptorOf h of
      SOME fd =>
        (Position.toInt (Posix.IO.lseek (fd, Position.fromInt 0, Posix.IO.SEEK_CUR)) - size (if h = 0 then !pending else "")
         handle e as OS.SysErr _ => (failed e; ~1))
    | NONE => (lastError := "Bad file descriptor"; lastErrno := 9; ~1)

  (* to a position in bytes from the start: 0, or ~1, the failure kept *)
  fun seek (h, pos) =
    case descriptorOf h of
      SOME fd =>
        ((if h = 0 then pending := "" else ());
         ignore (Posix.IO.lseek (fd, Position.fromInt pos, Posix.IO.SEEK_SET)); 0
         handle e as OS.SysErr _ => (failed e; ~1))
    | NONE => (lastError := "Bad file descriptor"; lastErrno := 9; ~1)

  (* whether input waits on a handle, or comes within ms milliseconds; with
     no limit for an ms below 0 *)
  fun ready (h, ms) =
    if h = 0 andalso !pending <> "" then true
    else
      case descriptorOf h of
        NONE => false
      | SOME fd =>
          (case OS.IO.pollDesc (Posix.FileSys.fdToIOD fd) of
             NONE => true
           | SOME d =>
               not (null (OS.IO.poll ([OS.IO.pollIn d], if ms < 0 then NONE else SOME (Time.fromMilliseconds (Int.toLarge ms))))))
          handle OS.SysErr _ => false
end
