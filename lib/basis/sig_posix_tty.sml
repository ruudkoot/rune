(* Terminals: their modes, their speeds and the characters that control them.

   What a terminal does with what is typed at it and with what is written to
   it is held in a `termios`: four sets of flags, an array of control
   characters, and two speeds. `TC.getattr` reads the settings of a
   descriptor, `TC.setattr` writes them back, and everything in between is
   how a `termios` is taken apart and put together.

   The four sets of flags are `I` for what is done to input, `O` for what is
   done to output, `C` for the line itself, and `L` for how the terminal
   treats the program -- whether it echoes, whether it waits for a whole line
   (`L.icanon`), whether typing the interrupt character sends a signal
   (`L.isig`). Turning `L.icanon` and `L.echo` off is what a program does to
   read keys as they are typed.

   `V` names the positions in the array of control characters: which
   character means end of file, which interrupts, which erases.

   Area: The operating system

   See also: `POSIX_IO`, `POSIX_PROC_ENV`, `POSIX`, `BIT_FLAGS`

   Erratum: `POSIX_TTY/flexible-types`. The types `pid` and `file_desc` are
   left flexible here, as on the page; `POSIX` fixes them.

   Implementation: `Posix.TTY/what-the-values-are`. A set of flags is a
   `tcflag_t` word of the system, a speed is its `speed_t`, and the control
   characters are a string of `V.nccs` characters; all of them are read and
   written in one call. *)
signature POSIX_TTY =
sig
  (* The type of the number that names a process, the one of `Posix.Process`. *)
  eqtype pid

  (* The type of an open file descriptor. *)
  eqtype file_desc

  (* The positions in the array of control characters, and the array itself. *)
  structure V :
  sig
    (* Where the end-of-file character stands.

       Reading: `Posix.TTY.V/distinct-within-a-set`. POSIX lets `min` share
       its position with `eof`, and `time` with `eol`, because a terminal is
       either in canonical mode or not; so the positions are distinct within
       each of the two sets and not across them.

       Pinned by: `Posix.TTY.V.eof/distinct` *)
    val eof : int

    (* Where the end-of-line character stands. *)
    val eol : int

    (* Where the character that erases one character stands. *)
    val erase : int

    (* Where the character that sends the interrupt signal stands. *)
    val intr : int

    (* Where the character that erases the whole line stands. *)
    val kill : int

    (* Where the smallest number of characters a raw read waits for stands. *)
    val min : int

    (* Where the character that sends the quit signal stands. *)
    val quit : int

    (* Where the character that suspends the program stands. *)
    val susp : int

    (* Where the time a raw read waits, in tenths of a second, stands. *)
    val time : int

    (* Where the character that resumes output stands. *)
    val start : int

    (* Where the character that holds output back stands. *)
    val stop : int

    (* How many positions the array has. *)
    val nccs : int

    (* The type of the array of control characters. *)
    type cc

    (* `cc l` is the array in which each position of `l` holds its character, and every other position `#"\000"`. *)
    val cc : (int * char) list -> cc

    (* `update (c, l)` is a copy of `c` in which each position of `l` holds its character.

       Raises: `Subscript` if a position is outside `[0, nccs)`. *)
    val update : cc * (int * char) list -> cc

    (* `sub (c, i)` is the character at position `i`.

       Raises: `Subscript` if `i` is outside `[0, nccs)`. *)
    val sub : cc * int -> char
  end

  (* What the terminal does with what is typed at it. *)
  structure I :
  sig
    include BIT_FLAGS

    (* A break sends the interrupt signal.

       Reading: `Posix.TTY.I/bits-are-posix's`. The page says nothing about
       what bits these flags have; the suite follows POSIX and asks that
       every named flag of `I` and `L` have non-zero bits of its own inside
       `all`, comparing through `SysWord` rather than through `allSet`.

       Pinned by: `Posix.TTY.L.echo/disjoint`, `Posix.TTY.C.cs5/in-csize` *)
    val brkint : flags

    (* A carriage return arrives as a newline. *)
    val icrnl : flags

    (* A break is ignored. *)
    val ignbrk : flags

    (* A carriage return is dropped. *)
    val igncr : flags

    (* A character with a parity error is dropped. *)
    val ignpar : flags

    (* A newline arrives as a carriage return. *)
    val inlcr : flags

    (* Check the parity of what arrives. *)
    val inpck : flags

    (* Drop the eighth bit of every character. *)
    val istrip : flags

    (* Send the stop character when the input buffer fills. *)
    val ixoff : flags

    (* Let the terminal hold output back with the stop character. *)
    val ixon : flags

    (* Mark a character with a parity error rather than dropping it. *)
    val parmrk : flags
  end

  (* What the terminal does with what is written to it. *)
  structure O :
  sig
    include BIT_FLAGS

    (* Process output at all; without it, output goes out as it stands. *)
    val opost : flags
  end

  (* The line itself: how wide a character is, how it is checked, how fast it goes. *)
  structure C :
  sig
    include BIT_FLAGS

    (* Ignore the modem lines: the line is local. *)
    val clocal : flags

    (* Let the terminal be read at all. *)
    val cread : flags

    (* Characters of five bits. *)
    val cs5 : flags

    (* Characters of six bits. *)
    val cs6 : flags

    (* Characters of seven bits. *)
    val cs7 : flags

    (* Characters of eight bits. *)
    val cs8 : flags

    (* The bits that hold the character width: `cs5` to `cs8` lie inside it. *)
    val csize : flags

    (* Send two stop bits rather than one. *)
    val cstopb : flags

    (* Hang up the line when the last process closes it. *)
    val hupcl : flags

    (* Generate and check a parity bit. *)
    val parenb : flags

    (* Make that parity odd rather than even. *)
    val parodd : flags
  end

  (* How the terminal treats the program: echoing, lines, signals. *)
  structure L :
  sig
    include BIT_FLAGS

    (* Echo what is typed. *)
    val echo : flags

    (* Echo the erase character as erasing. *)
    val echoe : flags

    (* Echo the kill character as killing the line. *)
    val echok : flags

    (* Echo a newline even when `echo` is off. *)
    val echonl : flags

    (* Wait for a whole line, and let it be edited; without it, keys arrive as they are typed. *)
    val icanon : flags

    (* Allow the system's own extensions to line editing. *)
    val iexten : flags

    (* Let the interrupt, quit and suspend characters send their signals. *)
    val isig : flags

    (* Do not flush the buffers when one of those signals is sent. *)
    val noflsh : flags

    (* Stop a background process that writes to the terminal. *)
    val tostop : flags
  end

  (* The type of a line speed.

     Implementation: `Posix.TTY.speed/is-speed_t`. It is the system's
     `speed_t`, and the named speeds are ordered by their baud rate. *)
  eqtype speed

  (* `compareSpeed (s, t)` orders two speeds, the slower first. *)
  val compareSpeed : speed * speed -> order

  (* `speedToWord s` is the `speed_t` value of `s`. *)
  val speedToWord : speed -> SysWord.word

  (* `wordToSpeed w` is the speed whose `speed_t` value is `w`. *)
  val wordToSpeed : SysWord.word -> speed

  (* Hang up: zero baud. *)
  val b0 : speed

  (* 50 baud. *)
  val b50 : speed

  (* 75 baud. *)
  val b75 : speed

  (* 110 baud. *)
  val b110 : speed

  (* 134.5 baud. *)
  val b134 : speed

  (* 150 baud. *)
  val b150 : speed

  (* 200 baud. *)
  val b200 : speed

  (* 300 baud. *)
  val b300 : speed

  (* 600 baud. *)
  val b600 : speed

  (* 1200 baud. *)
  val b1200 : speed

  (* 1800 baud. *)
  val b1800 : speed

  (* 2400 baud. *)
  val b2400 : speed

  (* 4800 baud. *)
  val b4800 : speed

  (* 9600 baud. *)
  val b9600 : speed

  (* 19200 baud. *)
  val b19200 : speed

  (* 38400 baud. *)
  val b38400 : speed

  (* The whole of a terminal's settings. *)
  type termios

  (* `termios {iflag, oflag, cflag, lflag, cc, ispeed, ospeed}` is the settings those fields make. *)
  val termios : {iflag : I.flags,
                 oflag : O.flags,
                 cflag : C.flags,
                 lflag : L.flags,
                 cc : V.cc,
                 ispeed : speed,
                 ospeed : speed}
                -> termios

  (* `fieldsOf t` is the fields of `t`, the record that `termios` takes. *)
  val fieldsOf : termios
                 -> {iflag : I.flags,
                     oflag : O.flags,
                     cflag : C.flags,
                     lflag : L.flags,
                     cc : V.cc,
                     ispeed : speed,
                     ospeed : speed}

  (* `getiflag t` is the input flags of `t`. *)
  val getiflag : termios -> I.flags

  (* `getoflag t` is the output flags of `t`. *)
  val getoflag : termios -> O.flags

  (* `getcflag t` is the line flags of `t`. *)
  val getcflag : termios -> C.flags

  (* `getlflag t` is the local flags of `t`. *)
  val getlflag : termios -> L.flags

  (* `getcc t` is the array of control characters of `t`. *)
  val getcc : termios -> V.cc

  (* The speeds of a settings record, read and set. *)
  structure CF :
  sig
    (* `getospeed t` is the speed at which `t` sends. *)
    val getospeed : termios -> speed

    (* `getispeed t` is the speed at which `t` receives. *)
    val getispeed : termios -> speed

    (* `setospeed (t, s)` is `t` with `s` as the speed it sends at. *)
    val setospeed : termios * speed -> termios

    (* `setispeed (t, s)` is `t` with `s` as the speed it receives at. *)
    val setispeed : termios * speed -> termios
  end

  (* The operations on a terminal itself: reading and writing its settings, and controlling its queues.

     Reading: `Posix.TTY.TC/not-a-terminal-raises`. The page does not say
     what happens on a descriptor that is not a terminal; POSIX reports
     `notty`, so every operation here raises `OS.SysErr` for one.

     Pinned by: `Posix.TTY.TC.*/not-a-terminal` *)
  structure TC :
  sig
    (* When `setattr` is to take effect. *)
    eqtype set_action

    (* At once. *)
    val sanow : set_action

    (* Once what has been written has gone out. *)
    val sadrain : set_action

    (* Once what has been written has gone out, discarding what has come in. *)
    val saflush : set_action

    (* What `flow` is to do. *)
    eqtype flow_action

    (* Hold output back. *)
    val ooff : flow_action

    (* Let output go on. *)
    val oon : flow_action

    (* Send the stop character, asking the terminal to hold back. *)
    val ioff : flow_action

    (* Send the start character, asking the terminal to go on. *)
    val ion : flow_action

    (* Which queue `flush` is to empty. *)
    eqtype queue_sel

    (* What has come in and not been read. *)
    val iflush : queue_sel

    (* What has been written and not gone out. *)
    val oflush : queue_sel

    (* Both. *)
    val ioflush : queue_sel

    (* `getattr fd` is the settings of the terminal `fd` is open on.

       Raises: `OS.SysErr` if `fd` is not a terminal. *)
    val getattr : file_desc -> termios

    (* `setattr (fd, when, t)` gives the terminal the settings `t`, at the moment `when` names.

       Raises: `OS.SysErr` if `fd` is not a terminal, or the settings are
       refused. *)
    val setattr : file_desc * set_action * termios -> unit

    (* `sendbreak (fd, n)` sends a break of `n` units, or of the usual length when `n` is 0.

       Raises: `OS.SysErr` if `fd` is not a terminal. *)
    val sendbreak : file_desc * int -> unit

    (* `drain fd` waits until what was written to the terminal has gone out.

       Raises: `OS.SysErr` if `fd` is not a terminal. *)
    val drain : file_desc -> unit

    (* `flush (fd, which)` throws away what is in the queue that `which` names.

       Raises: `OS.SysErr` if `fd` is not a terminal. *)
    val flush : file_desc * queue_sel -> unit

    (* `flow (fd, what)` holds the flow back or lets it go on, as `what` says.

       Raises: `OS.SysErr` if `fd` is not a terminal. *)
    val flow : file_desc * flow_action -> unit

    (* `getpgrp fd` is the process group that the terminal sends its signals to.

       Raises: `OS.SysErr` if `fd` is not a terminal. *)
    val getpgrp : file_desc -> pid

    (* `setpgrp (fd, pgid)` makes `pgid` the process group in the foreground of the terminal.

       Raises: `OS.SysErr` if `fd` is not a terminal, or the change is
       refused. *)
    val setpgrp : file_desc * pid -> unit
  end
end
