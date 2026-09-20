(* OS.IO: the descriptors of the files a program has open, and waiting for one
   of them to be ready. *)
structure RuneIODesc =
struct
  datatype iodesc = FD of int
  fun hash (FD fd) = Word.fromInt fd
  fun compare (FD a, FD b) = Int.compare (a, b)

  local
    val descKind = _prim "os_desc_kind" : int -> int
    val poll' = _prim "os_poll" : int list * int list * int -> int list
  in
    (* The kinds the specification names, and any other. *)
    datatype iodesc_kind = Kind of string
    structure Kind =
    struct
      val file = Kind "file"
      val dir = Kind "dir"
      val symlink = Kind "symlink"
      val tty = Kind "tty"
      val pipe = Kind "pipe"
      val socket = Kind "socket"
      val device = Kind "device"
    end

    fun kind (FD fd) =
      case descKind fd of
        0 => Kind.file
      | 1 => Kind.dir
      | 2 => Kind.symlink
      | 3 => Kind.tty
      | 4 => Kind.pipe
      | 5 => Kind.socket
      | 6 => Kind.device
      | _ => raise RuneError.lastError ()

    exception Poll

    (* A description of what to wait for: the handle and the events, as the
       bits 1 read, 2 write and 4 urgent. *)
    datatype poll_desc = PollDesc of iodesc * int
    datatype poll_info = PollInfo of poll_desc * int

    fun pollDesc desc = SOME (PollDesc (desc, 0))
    fun pollToIODesc (PollDesc (desc, _)) = desc
    fun infoToPollDesc (PollInfo (desc, _)) = desc

    fun pollIn (PollDesc (d, e)) = PollDesc (d, Word.toInt (Word.orb (Word.fromInt e, 0w1)))
    fun pollOut (PollDesc (d, e)) = PollDesc (d, Word.toInt (Word.orb (Word.fromInt e, 0w2)))
    fun pollPri (PollDesc (d, e)) = PollDesc (d, Word.toInt (Word.orb (Word.fromInt e, 0w4)))

    fun isIn (PollInfo (_, e)) = Word.andb (Word.fromInt e, 0w1) <> 0w0
    fun isOut (PollInfo (_, e)) = Word.andb (Word.fromInt e, 0w2) <> 0w0
    fun isPri (PollInfo (_, e)) = Word.andb (Word.fromInt e, 0w4) <> 0w0

    (* "returns the descriptors that are ready"; a timeout of NONE waits for
       as long as it takes. "The poll function will raise OS.SysErr if, for
       example, one of the file descriptors refers to a closed file": the
       system reports such a descriptor as one that is ready, with an event
       the primitive does not pass on, so each descriptor is looked at
       first. *)
    fun poll (descs, timeout) =
      let
        val fds = List.map (fn PollDesc (FD fd, _) => fd) descs
        val () = List.app (fn fd => if descKind fd < 0 then raise RuneError.lastError () else ()) fds
        val events = List.map (fn PollDesc (_, e) => e) descs
        val micros = case timeout of NONE => ~1 | SOME t => Time.micros t
      in
        case poll' (fds, events, micros) of
          [] => if List.null descs then [] else raise RuneError.lastError ()
        | got =>
            let
              fun gather (PollDesc d :: ds, e :: es) =
                  if e = 0 then gather (ds, es) else PollInfo (PollDesc d, e) :: gather (ds, es)
                | gather _ = []
            in gather (descs, got) end
      end
  end
end
