(* Posix.TTY: the settings of a terminal. A set of flags is the word of a
   tcflag_t, a speed the speed_t of the system, the control characters a
   string of NCCS of them; the primitives read and write all of them at once
   (posix_tcgetattr, posix_tcsetattr). *)

(* The flags of one field of the settings, a BIT_FLAGS structure. Every bit
   of a tcflag_t (32 of them) is in all, so that a flag the system has and
   Posix does not name survives getattr and setattr. *)
functor RunePosixTTYFlagsFn () =
struct
  type flags = word
  val all = if Word.wordSize > 32 then Word.- (Word.<< (0w1, 0w32), 0w1) else Word.notb 0w0
  fun toWord (f : flags) = f
  fun fromWord w = Word.andb (w, all)
  fun flags l = List.foldl Word.orb 0w0 l
  fun intersect l = List.foldl Word.andb all l
  fun clear (a, b) = Word.andb (Word.notb a, b)
  fun allSet (a, b) = Word.andb (a, b) = a
  fun anySet (a, b) = Word.andb (a, b) <> 0w0
end

structure RunePosixTTY =
struct
  type pid = RunePosixProcess.pid
  type file_desc = RunePosixFileSys.file_desc

  local
    val const = _prim "posix_const" : string -> int
    val getattr' = _prim "posix_tcgetattr" : int -> int list
    val setattr' = _prim "posix_tcsetattr" : int * int * int list -> int
    val tcop' = _prim "posix_tcop" : int * int * int -> int
    fun named name = case const name of ~1 => 0 | v => v
    fun bits name = Word.fromInt (named name)
    fun check r = if r < 0 then raise RuneError.lastError () else r
    structure IF = RunePosixTTYFlagsFn ()
    structure OF = RunePosixTTYFlagsFn ()
    structure CF' = RunePosixTTYFlagsFn ()
    structure LF = RunePosixTTYFlagsFn ()
  in
    (* "Indices for the special control characters" *)
    structure V =
    struct
      val eof = named "VEOF"
      val eol = named "VEOL"
      val erase = named "VERASE"
      val intr = named "VINTR"
      val kill = named "VKILL"
      val min = named "VMIN"
      val quit = named "VQUIT"
      val susp = named "VSUSP"
      val time = named "VTIME"
      val start = named "VSTART"
      val stop = named "VSTOP"
      val nccs = named "NCCS"
      type cc = string
      (* "update (cs, l) returns a copy of cs, with the new (index, value)
         pairs in l"; an index outside [0, nccs) raises Subscript *)
      fun update (c : cc, l) =
        (List.app (fn (i, _) => if i < 0 orelse i >= nccs then raise Subscript else ()) l;
         CharVector.tabulate (nccs, fn i =>
           List.foldl (fn ((j, ch), acc) => if j = i then ch else acc) (String.sub (c, i)) l))
      (* "unspecified indices set to #"\000"" *)
      fun cc l = update (CharVector.tabulate (nccs, fn _ => #"\000"), l)
      fun sub (c : cc, i) = String.sub (c, i)
    end

    structure I =
    struct
      open IF
      val brkint = bits "BRKINT"
      val icrnl = bits "ICRNL"
      val ignbrk = bits "IGNBRK"
      val igncr = bits "IGNCR"
      val ignpar = bits "IGNPAR"
      val inlcr = bits "INLCR"
      val inpck = bits "INPCK"
      val istrip = bits "ISTRIP"
      val ixoff = bits "IXOFF"
      val ixon = bits "IXON"
      val parmrk = bits "PARMRK"
    end
    structure O =
    struct
      open OF
      val opost = bits "OPOST"
    end
    structure C =
    struct
      open CF'
      val clocal = bits "CLOCAL"
      val cread = bits "CREAD"
      val cs5 = bits "CS5"
      val cs6 = bits "CS6"
      val cs7 = bits "CS7"
      val cs8 = bits "CS8"
      val csize = bits "CSIZE"
      val cstopb = bits "CSTOPB"
      val hupcl = bits "HUPCL"
      val parenb = bits "PARENB"
      val parodd = bits "PARODD"
    end
    structure L =
    struct
      open LF
      val echo = bits "ECHO"
      val echoe = bits "ECHOE"
      val echok = bits "ECHOK"
      val echonl = bits "ECHONL"
      val icanon = bits "ICANON"
      val iexten = bits "IEXTEN"
      val isig = bits "ISIG"
      val noflsh = bits "NOFLSH"
      val tostop = bits "TOSTOP"
    end

    (* a speed is the speed_t of the system; the named ones grow with the
       baud rate *)
    type speed = int
    val compareSpeed = Int.compare
    fun speedToWord (s : speed) = Word.fromInt s
    fun wordToSpeed w : speed = Word.toInt w
    val b0 = named "B0"
    val b50 = named "B50"
    val b75 = named "B75"
    val b110 = named "B110"
    val b134 = named "B134"
    val b150 = named "B150"
    val b200 = named "B200"
    val b300 = named "B300"
    val b600 = named "B600"
    val b1200 = named "B1200"
    val b1800 = named "B1800"
    val b2400 = named "B2400"
    val b4800 = named "B4800"
    val b9600 = named "B9600"
    val b19200 = named "B19200"
    val b38400 = named "B38400"

    datatype termios = T of {iflag : I.flags, oflag : O.flags, cflag : C.flags, lflag : L.flags,
                             cc : V.cc, ispeed : speed, ospeed : speed}
    fun termios r = T r
    fun fieldsOf (T r) = r
    fun getiflag (T r) = #iflag r
    fun getoflag (T r) = #oflag r
    fun getcflag (T r) = #cflag r
    fun getlflag (T r) = #lflag r
    fun getcc (T r) = #cc r

    structure CF =
    struct
      fun getospeed (T r) = #ospeed r
      fun getispeed (T r) = #ispeed r
      fun setospeed (T {iflag, oflag, cflag, lflag, cc, ispeed, ...}, s) =
        T {iflag = iflag, oflag = oflag, cflag = cflag, lflag = lflag, cc = cc, ispeed = ispeed, ospeed = s}
      fun setispeed (T {iflag, oflag, cflag, lflag, cc, ospeed, ...}, s) =
        T {iflag = iflag, oflag = oflag, cflag = cflag, lflag = lflag, cc = cc, ispeed = s, ospeed = ospeed}
    end

    structure TC =
    struct
      type set_action = int
      val sanow = named "TCSANOW"
      val sadrain = named "TCSADRAIN"
      val saflush = named "TCSAFLUSH"
      type flow_action = int
      val ooff = named "TCOOFF"
      val oon = named "TCOON"
      val ioff = named "TCIOFF"
      val ion = named "TCION"
      type queue_sel = int
      val iflush = named "TCIFLUSH"
      val oflush = named "TCOFLUSH"
      val ioflush = named "TCIOFLUSH"

      fun getattr (fd : file_desc) =
        case getattr' fd of
          iflag :: oflag :: cflag :: lflag :: ispeed :: ospeed :: cc =>
            T {iflag = Word.fromInt iflag, oflag = Word.fromInt oflag, cflag = Word.fromInt cflag,
               lflag = Word.fromInt lflag, cc = String.implode (List.map Char.chr cc),
               ispeed = ispeed, ospeed = ospeed}
        | _ => raise RuneError.lastError ()
      fun setattr (fd : file_desc, action : set_action, T {iflag, oflag, cflag, lflag, cc, ispeed, ospeed}) =
        ignore (check (setattr' (fd, action,
                                 [Word.toInt iflag, Word.toInt oflag, Word.toInt cflag, Word.toInt lflag,
                                  ispeed, ospeed] @ List.map Char.ord (String.explode cc))))
      fun drain (fd : file_desc) = ignore (check (tcop' (0, fd, 0)))
      fun flush (fd : file_desc, q : queue_sel) = ignore (check (tcop' (1, fd, q)))
      fun flow (fd : file_desc, a : flow_action) = ignore (check (tcop' (2, fd, a)))
      fun sendbreak (fd : file_desc, duration) = ignore (check (tcop' (3, fd, duration)))
      fun getpgrp (fd : file_desc) : pid = check (tcop' (4, fd, 0))
      fun setpgrp (fd : file_desc, p : pid) = ignore (check (tcop' (5, fd, p)))
    end
  end
end
