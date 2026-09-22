(* Descriptors of open files, devices, pipes and sockets, and waiting until
   some of them are ready for input or output.

   An `iodesc` stands for something the operating system has opened for the
   program. The readers and writers of `PRIM_IO` give theirs (`ioDesc`), and a
   socket gives its own (`Socket.ioDesc`). `poll` waits for several descriptors
   at once, which is how a program serves more than one connection without
   threads. The structure is `OS.IO`.

   Area: The operating system

   See also: `OS`, `PRIM_IO`, `SOCKET`, `TIME` *)
signature OS_IO =
sig
  (* ---- Descriptors ---- *)

  (* A descriptor of something the operating system has opened. Two
     descriptors are equal when they stand for the same open file.

     Implementation: `OS.IO.iodesc/descriptor`. The file descriptor of the
     operating system, a small integer in a datatype of its own. *)
  eqtype iodesc

  (* `hash d` is a word that is the same for equal descriptors, for use in a
     hash table.

     Implementation: `OS.IO.hash/descriptor-number`. The hash is the number of
     the descriptor, and two `iodesc` are equal when the numbers are: the
     `iodesc` of the reader under `TextIO.stdIn` is `Posix.FileSys.fdToIOD
     Posix.FileSys.stdin`.

     Pinned by: `OS.IO.hash/TextIO.stdIn-is-Posix-stdin`,
     `OS.IO.compare/TextIO.stdIn-is-Posix-stdin` *)
  val hash : iodesc -> word

  (* `compare (d, e)` orders descriptors in some total order, which has no
     meaning beyond that. *)
  val compare : iodesc * iodesc -> order

  (* What a descriptor is a descriptor of. The known kinds are the values of
     `Kind`. *)
  eqtype iodesc_kind

  (* `kind d` is what `d` is a descriptor of.

     Raises: `OS.SysErr` if the operating system cannot tell, as for a
     descriptor that is closed.

     Reading: `OS.IO.kind/other-kinds`. "A given implementation may define
     other iodesc values": the result need not be one of the seven of `Kind`,
     and the suite allows for that. Here it always is one: what is none of
     the others is a `device`.

     Implementation: `OS.IO.kind/what-is-looked-at`. The kind is that of the
     open file, so a descriptor that was opened through a symbolic link has
     the kind of what the link names and never `symlink`. A descriptor is a
     `tty` exactly when `Posix.ProcEnv.isatty` says so, which is asked first:
     `/dev/null` is a `device`.

     Pinned by: `OS.IO.Kind.*/dev-null` *)
  val kind : iodesc -> iodesc_kind

  (* The kinds of descriptor that every system knows. *)
  structure Kind :
  sig
    val file : iodesc_kind      (* a regular file *)
    val dir : iodesc_kind       (* a directory *)
    val symlink : iodesc_kind   (* a symbolic link *)
    val tty : iodesc_kind       (* a terminal *)
    val pipe : iodesc_kind      (* a pipe *)
    val socket : iodesc_kind    (* a socket *)
    val device : iodesc_kind    (* a device *)
  end

  (* ---- Polling ---- *)

  (* A descriptor together with the events to wait for on it: input, output,
     urgent input.

     Implementation: `OS.IO.poll_desc/a-descriptor-and-its-conditions`. A
     `poll_desc` is the descriptor with the set of conditions asked for, so
     asking twice is asking once, the order of asking does not matter, and one
     that asks for input is not equal to one that asks for output.

     Pinned by: `OS.IO.pollIn/twice`, `OS.IO.pollOut/commutes-with-pollIn`,
     `OS.IO.pollOut/differs-from-pollIn` *)
  eqtype poll_desc

  (* What `poll` found out about one `poll_desc`: which of the events it asked
     about have come. *)
  type poll_info

  (* `pollDesc d` is a `poll_desc` for `d` that asks about no event yet, or
     `NONE` if `d` cannot be polled.

     Implementation: `OS.IO.pollDesc/always`. Every descriptor can be polled:
     the answer is never `NONE`. *)
  val pollDesc : iodesc -> poll_desc option

  (* `pollToIODesc pd` is the descriptor that `pd` was made from. *)
  val pollToIODesc : poll_desc -> iodesc

  (* Raised by `pollIn`, `pollOut` and `pollPri` for a descriptor that does not
     support that kind of event.

     Implementation: `OS.IO.Poll/never`. It is never raised: the operating
     system is asked about every event, and answers when `poll` is called. *)
  exception Poll

  (* `pollIn pd` is `pd` with input added to the events to wait for: data to
     read, or the end of the stream.

     Raises: `Poll` if the descriptor does not support input. *)
  val pollIn : poll_desc -> poll_desc

  (* `pollOut pd` is `pd` with output added to the events to wait for: room to
     write without waiting.

     Raises: `Poll` if the descriptor does not support output. *)
  val pollOut : poll_desc -> poll_desc

  (* `pollPri pd` is `pd` with urgent input added to the events to wait for,
     such as the out-of-band data of a socket.

     Raises: `Poll` if the descriptor does not support it. *)
  val pollPri : poll_desc -> poll_desc

  (* `poll (pds, timeout)` waits until an event that one of `pds` asks about
     has come, and says which have.

     The result has a `poll_info` for each descriptor with an event, in the
     order of `pds`; the others are left out, so the result is empty when the
     time runs out first. `timeout` is how long to wait at most: `NONE` waits
     for as long as it takes, and `SOME Time.zeroTime` does not wait at all.

     Raises: `OS.SysErr` if the operating system refuses the request.

     Reading: `OS.IO.poll/closed-SysErr`. The specification gives "one of the
     file
     descriptors refers to a closed file" as an example of what raises
     `OS.SysErr`. The operating system itself reports such a descriptor as
     ready, so every descriptor is looked at before the wait, and a closed one
     raises `OS.SysErr`. *)
  val poll : poll_desc list * Time.time option -> poll_info list

  (* `isIn info` is `true` when the descriptor has input, or is at its end. *)
  val isIn : poll_info -> bool

  (* `isOut info` is `true` when the descriptor can take output. *)
  val isOut : poll_info -> bool

  (* `isPri info` is `true` when the descriptor has urgent input. *)
  val isPri : poll_info -> bool

  (* `infoToPollDesc info` is the `poll_desc` that `info` answers. *)
  val infoToPollDesc : poll_info -> poll_desc
end
