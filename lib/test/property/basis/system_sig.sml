(* The arbitraries of the values of the operating system that the Basis
   Library's laws are written over (docs/plans/quickcheck.md, M6).

   These are made, not drawn: a stream over drawn bytes or a file in a
   scratch directory, a pipe, a socket, the process's own ids. What a case
   makes is undone when the case is over (`Gen.resource`). A value with no
   Standard ML that makes it again is shown as a comment that says what it
   is.

   Area: Property testing *)
signature SYSTEM_ARB =
sig
  (* The arbitrary of binary input streams over drawn bytes, shown as the
     bytes they have left. *)
  val binInstream : BinIO.instream Arb.arb

  (* The arbitrary of functional binary input streams over drawn bytes. *)
  val binStreamInstream : BinIO.StreamIO.instream Arb.arb

  (* The arbitrary of binary writers that keep what they are given and
     accept every write. *)
  val binWriter : BinIO.StreamIO.writer Arb.arb

  (* The arbitrary of functional binary output streams over a writer of
     `binWriter`, with any buffer mode. *)
  val binOutstream : BinIO.StreamIO.outstream Arb.arb

  (* The arbitrary of text input streams over a drawn string, shown as the
     characters they have left. *)
  val textInstream : TextIO.instream Arb.arb

  (* The arbitrary of functional text input streams over a drawn string. *)
  val textStreamInstream : TextIO.StreamIO.instream Arb.arb

  (* The arbitrary of text writers that keep what they are given and accept
     every write. *)
  val textWriter : TextIO.StreamIO.writer Arb.arb

  (* The arbitrary of functional text output streams over a writer of
     `textWriter`, with any buffer mode. *)
  val textOutstream : TextIO.StreamIO.outstream Arb.arb

  (* The arbitrary of the positions of text readers: that of a reader over a
     drawn string after a drawn number of its characters. *)
  val textPos : TextPrimIO.pos Arb.arb

  (* The arbitrary of I/O descriptors: the read end of a pipe, closed when
     the case is over. *)
  val iodesc : OS.IO.iodesc Arb.arb

  (* The arbitrary of poll descriptors of `iodesc`'s pipes. *)
  val pollDesc : OS.IO.poll_desc Arb.arb

  (* The arbitrary of file ids: that of a file in a scratch directory,
     removed when the case is over. *)
  val fileId : OS.FileSys.file_id Arb.arb

  (* The arbitrary of the system's errors: each that `Posix.Error` names,
     `acces` the simplest. *)
  val syserror : OS.syserror Arb.arb

  (* The arbitrary of Posix file descriptors: the read end of a pipe, closed
     when the case is over. *)
  val fileDesc : Posix.FileSys.file_desc Arb.arb

  (* The arbitrary of process ids: the process's own and its parent's. *)
  val pid : Posix.Process.pid Arb.arb

  (* The arbitrary of signals: each that `Posix.Signal` names. *)
  val signal : Posix.Signal.signal Arb.arb

  (* The arbitrary of user ids: the process's own and 0. *)
  val uid : Posix.ProcEnv.uid Arb.arb

  (* The arbitrary of group ids: the process's own and 0. *)
  val gid : Posix.ProcEnv.gid Arb.arb

  (* The arbitrary of line speeds: each that `Posix.TTY` names. *)
  val speed : Posix.TTY.speed Arb.arb

  (* The arbitrary of terminal settings: flags from drawn words, control
     characters drawn for every index, and speeds of `speed`. *)
  val termios : Posix.TTY.termios Arb.arb

  (* The arbitrary of the records of the fields of terminal settings, as
     `Posix.TTY.fieldsOf` gives them, drawn as `termios` draws settings. *)
  val termiosFields : {iflag : Posix.TTY.I.flags, oflag : Posix.TTY.O.flags, cflag : Posix.TTY.C.flags,
                       lflag : Posix.TTY.L.flags, cc : Posix.TTY.V.cc, ispeed : Posix.TTY.speed,
                       ospeed : Posix.TTY.speed} Arb.arb

  (* The arbitrary of the input flags of terminal settings, from a drawn
     word; two are equal when their words are. *)
  val ttyIflags : Posix.TTY.I.flags Arb.arb

  (* The arbitrary of the output flags of terminal settings. *)
  val ttyOflags : Posix.TTY.O.flags Arb.arb

  (* The arbitrary of the control flags of terminal settings. *)
  val ttyCflags : Posix.TTY.C.flags Arb.arb

  (* The arbitrary of the local flags of terminal settings. *)
  val ttyLflags : Posix.TTY.L.flags Arb.arb

  (* The arbitrary of the control characters of terminal settings, one drawn
     for every index; two are equal when they have the same characters. *)
  val ttyCc : Posix.TTY.V.cc Arb.arb

  (* The arbitrary of the origins of a seek, `Posix.IO.SEEK_SET` the
     simplest. *)
  val whence : Posix.IO.whence Arb.arb

  (* The arbitrary of kinds of lock, `Posix.IO.F_RDLCK` the simplest. *)
  val lockType : Posix.IO.lock_type Arb.arb

  (* The arbitrary of address families: each of `Socket.AF.list ()`. *)
  val addrFamily : Socket.AF.addr_family Arb.arb

  (* The arbitrary of socket types: each of `Socket.SOCK.list ()`. *)
  val sockType : Socket.SOCK.sock_type Arb.arb

  (* `inetStreamSock ()` is the arbitrary of new TCP sockets over IPv4, closed
     when the case is over. *)
  val inetStreamSock : unit -> 'mode INetSock.stream_sock Arb.arb

  (* The arbitrary of IPv4 addresses: four drawn bytes. *)
  val inAddr : NetHostDB.in_addr Arb.arb

  (* The arbitrary of host entries: that of `localhost`. *)
  val hostEntry : NetHostDB.entry Arb.arb
end
