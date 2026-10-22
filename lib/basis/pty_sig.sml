(* A child attached to a new pseudo-terminal, independent of any terminal
   emulator program. POSIX supplies a controlling terminal and session;
   Windows supplies ConPTY. The session owns its descriptors; callers own
   waiting for its child. This interface is Rune's extension.

   Area: The runtime

   Status: extension *)
signature PTY =
sig
  (* An owned terminal and the child attached to it. *)
  type session
  (* What borrowing or resizing a closed session raises. *)
  exception Closed
  (* `spawn settings` starts a child on the terminal that settings describes.

     args includes argv[0].
     NONE environment or directory inherits the parent's. Dimensions outside
     1..32767 raise Domain. OS.SysErr reports an unavailable terminal backend
     (ENOSYS for sys_none and Windows without ConPTY). POSIX exec failure is
     a child exiting with 126, as with Subprocess.spawn. *)
  val spawn : {program : string, args : string list, env : string list option,
               dir : string option, columns : int, rows : int} -> session
  (* `input s` is the borrowed numeric descriptor for reading terminal output.

     Convert with Posix.FileSys.wordToFD o SysWord.fromInt to read/write or
     poll them. They must not be closed independently. Numeric descriptors
     keep this extension independent of Posix's abstract client types. *)
  val input : session -> int
  (* `output s` is the borrowed descriptor that writes input to the terminal.
     Convert its number as for input; never close it independently. *)
  val output : session -> int
  (* `process s` is the child, waited for with Subprocess.wait/poll, including
     after close. *)
  val process : session -> Subprocess.pid
  (* `resize (s, size)` changes the terminal dimensions and notifies its foreground program.

     Raises Domain for
     dimensions outside 1..32767, Closed after close, OS.SysErr on failure. *)
  val resize : session * {columns : int, rows : int} -> unit
  (* `close s` disconnects the terminal and discards unread output.

     Attached programs may end. Reap the child separately. Idempotent; input/output/resize then
     raise Closed. A session is an external resource: close it explicitly,
     and do not expect it to survive saved-image restoration. *)
  val close : session -> unit
end
