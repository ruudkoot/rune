(* Posix.IO: reading and writing by descriptor. *)
structure RunePosixIO =
struct
  type file_desc = RunePosixFileSys.file_desc
  type pid = RunePosixProcess.pid

  local
    val const = _prim "posix_const" : string -> int
    val close' = _prim "posix_close" : int -> int
    val dup' = _prim "posix_dup" : int -> int
    val dup2' = _prim "posix_dup2" : int * int -> int
    val pipe' = _prim "posix_pipe" : unit -> int list
    val read' = _prim "posix_read" : int * int -> string
    val write' = _prim "posix_write" : int * string -> int
    val lseek' = _prim "posix_lseek" : int * int * int -> int
    val fsync' = _prim "posix_fsync" : int -> int
    val fcntl' = _prim "posix_fcntl" : int * int * int -> int
    val lock' = _prim "posix_lock" : int * int * int * int * int * int -> int list
    val errno' = _prim "sys_errno" : unit -> int
    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun named name = case const name of ~1 => 0 | v => v
    (* posix_read gives "" at the end of a file and when the read fails; errno
       is 0 in the first case only. *)
    fun read (fd, n) =
      case read' (fd, n) of
        "" => if n > 0 andalso errno' () <> 0 then raise RuneError.lastError () else ""
      | got => got
  in
    fun pipe () =
      case pipe' () of
        [infd, outfd] => {infd = infd, outfd = outfd}
      | _ => raise RuneError.lastError ()

    fun dup fd = check (dup' fd)
    fun dup2 {old, new} = ignore (check (dup2' (old, new)))
    fun close fd = ignore (check (close' fd))

    (* "reads at most n bytes"; the empty vector at the end of the file *)
    fun readVec (fd, n) = if n < 0 then raise Size else read (fd, n)
    fun writeVec (fd, slice) = check (write' (fd, Word8VectorSlice.vector slice))
    fun readArr (fd, slice) =
      let
        val got = read (fd, Word8ArraySlice.length slice)
        val (a, i, _) = Word8ArraySlice.base slice
      in Word8Array.copyVec {src = got, dst = a, di = i}; size got end
    fun writeArr (fd, slice) = check (write' (fd, Word8ArraySlice.vector slice))

    datatype whence = SEEK_SET | SEEK_CUR | SEEK_END
    fun whenceBits SEEK_SET = named "SEEK_SET"
      | whenceBits SEEK_CUR = named "SEEK_CUR"
      | whenceBits SEEK_END = named "SEEK_END"
    fun lseek (fd, offset, whence) = check (lseek' (fd, offset, whenceBits whence))
    fun fsync fd = ignore (check (fsync' fd))

    (* Locks on segments of a file: fcntl with a struct flock. *)
    datatype lock_type = F_RDLCK | F_WRLCK | F_UNLCK
    structure FLock =
    struct
      datatype flock = FLock of {ltype : lock_type, whence : whence, start : int, len : int, pid : pid option}
      fun flock r = FLock r
      fun ltype (FLock r) = #ltype r
      fun whence (FLock r) = #whence r
      fun start (FLock r) = #start r
      fun len (FLock r) = #len r
      fun pid (FLock r) = #pid r
    end
    local
      fun typeBits F_RDLCK = named "F_RDLCK"
        | typeBits F_WRLCK = named "F_WRLCK"
        | typeBits F_UNLCK = named "F_UNLCK"
      fun typeOf b = if b = named "F_RDLCK" then F_RDLCK else if b = named "F_WRLCK" then F_WRLCK else F_UNLCK
      fun whenceOf b = if b = named "SEEK_CUR" then SEEK_CUR else if b = named "SEEK_END" then SEEK_END else SEEK_SET
      (* The lock afterwards: for getlk the one that is in the way (with the
         process that holds it), or fl itself with the type F_UNLCK. *)
      fun lock (command, fd, FLock.FLock {ltype, whence, start, len, pid}) =
        case lock' (fd, named command, typeBits ltype, whenceBits whence, start, len) of
          [t, w, s, l, p] =>
            FLock.FLock {ltype = typeOf t, whence = whenceOf w, start = s, len = l,
                         pid = if command = "F_GETLK" then (if typeOf t = F_UNLCK then NONE else SOME p) else pid}
        | _ => raise RuneError.lastError ()
    in
      fun getlk (fd, fl) = lock ("F_GETLK", fd, fl)
      fun setlk (fd, fl) = lock ("F_SETLK", fd, fl)
      fun setlkw (fd, fl) = lock ("F_SETLKW", fd, fl)
    end

    (* The flags of a descriptor, as words; like the flags of open, all of
       them are the bits of a C int (Posix.FileSys.O).

       Implements: BIT_FLAGS *)
    structure FD =
    struct
      type flags = word
      val cloexec = Word.fromInt (named "FD_CLOEXEC")
      val all = if Word.wordSize > 32 then Word.<< (0w1, 0w32) - 0w1 else Word.notb 0w0
      fun toWord (f : flags) = f
      fun fromWord w = Word.andb (w, all)
      fun flags l = List.foldl Word.orb 0w0 l
      fun intersect l = List.foldl Word.andb all l
      fun allSet (a, b) = Word.andb (a, b) = a
      fun anySet (a, b) = Word.andb (a, b) <> 0w0
      fun clear (a, b) = Word.andb (Word.notb a, b)
    end

    (* Implements: BIT_FLAGS *)
    structure O = RunePosixFileSys.O
    datatype open_mode = datatype RunePosixFileSys.open_mode

    fun dupfd {old, base} = check (fcntl' (old, named "F_DUPFD", base))
    fun getfd fd = FD.fromWord (Word.fromInt (check (fcntl' (fd, named "F_GETFD", 0))))
    fun setfd (fd, flags) = ignore (check (fcntl' (fd, named "F_SETFD", Word.toInt flags)))
    fun getfl fd =
      let
        val bits = check (fcntl' (fd, named "F_GETFL", 0))
        val accessBits = Word.fromInt (named "O_RDONLY") (* 0 on POSIX *)
        val mode = if Word.andb (Word.fromInt bits, 0w3) = Word.fromInt (named "O_WRONLY") then O_WRONLY
                   else if Word.andb (Word.fromInt bits, 0w3) = Word.fromInt (named "O_RDWR") then O_RDWR
                   else O_RDONLY
      in (O.fromWord (Word.andb (Word.fromInt bits, Word.notb 0w3)), mode) end
    fun setfl (fd, flags) = ignore (check (fcntl' (fd, named "F_SETFL", Word.toInt flags)))

    (* The readers and writers of PRIM_IO over a descriptor. Only a regular
       file has positions: lseek fails on a pipe, a socket or a terminal, so
       that their getPos, setPos, endPos and verifyPos are NONE. *)
    fun positions fd =
      if (RunePosixFileSys.ST.isReg (RunePosixFileSys.fstat fd) handle RuneError.SysErr _ => false) then
        {getPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
         setPos = SOME (fn p => ignore (lseek (fd, p, SEEK_SET))),
         endPos = SOME (fn () =>
           let val here = lseek (fd, 0, SEEK_CUR)
               val theEnd = lseek (fd, 0, SEEK_END)
           in ignore (lseek (fd, here, SEEK_SET)); theEnd end),
         verifyPos = SOME (fn () => lseek (fd, 0, SEEK_CUR))}
      else {getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE}

    (* The same offsets as a position of TextPrimIO, which is abstract. *)
    fun textPositions fd =
      let
        val {getPos, setPos, endPos, verifyPos} = positions fd
        fun out f = fn () => RuneTextPos.fromInt (f ())
      in
        {getPos = Option.map out getPos,
         setPos = Option.map (fn f => fn p => f (RuneTextPos.toInt p)) setPos,
         endPos = Option.map out endPos,
         verifyPos = Option.map out verifyPos}
      end

    fun mkBinReader {fd, name, initBlkMode} =
      let val {getPos, setPos, endPos, verifyPos} = positions fd
      in
        BinPrimIO.RD {name = name, chunkSize = 4096,
                      readVec = SOME (fn n => readVec (fd, n)), readArr = SOME (fn sl => readArr (fd, sl)),
                      readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                      avail = fn () => NONE,
                      getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                      close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}
      end

    fun mkBinWriter {fd, name, initBlkMode, appendMode, chunkSize} =
      let val {getPos, setPos, endPos, verifyPos} = positions fd
      in
        BinPrimIO.WR {name = name, chunkSize = chunkSize,
                      writeVec = SOME (fn sl => writeVec (fd, sl)), writeArr = SOME (fn sl => writeArr (fd, sl)),
                      writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                      getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                      close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}
      end

    fun mkTextReader {fd, name, initBlkMode} =
      let val {getPos, setPos, endPos, verifyPos} = textPositions fd
      in
        TextPrimIO.RD {name = name, chunkSize = 4096,
                       readVec = SOME (fn n => readVec (fd, n)), readArr = NONE,
                       readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                       avail = fn () => NONE,
                       getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                       close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}
      end

    fun mkTextWriter {fd, name, initBlkMode, appendMode, chunkSize} =
      let val {getPos, setPos, endPos, verifyPos} = textPositions fd
      in
        TextPrimIO.WR {name = name, chunkSize = chunkSize,
                       writeVec = SOME (fn sl => check (write' (fd, CharVectorSlice.vector sl))),
                       writeArr = NONE, writeVecNB = NONE, writeArrNB = NONE,
                       block = NONE, canOutput = NONE,
                       getPos = getPos, setPos = setPos, endPos = endPos, verifyPos = verifyPos,
                       close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}
      end
  end
end
