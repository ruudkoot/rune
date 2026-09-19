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
    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun named name = case const name of ~1 => 0 | v => v
  in
    fun pipe () =
      case pipe' () of
        [infd, outfd] => {infd = infd, outfd = outfd}
      | _ => raise RuneError.lastError ()

    fun dup fd = check (dup' fd)
    fun dup2 {old, new} = ignore (check (dup2' (old, new)))
    fun close fd = ignore (check (close' fd))

    (* "reads at most n bytes"; the empty vector at the end of the file *)
    fun readVec (fd, n) = if n < 0 then raise Size else read' (fd, n)
    fun writeVec (fd, slice) = check (write' (fd, Word8VectorSlice.vector slice))
    fun readArr (fd, slice) =
      let
        val got = read' (fd, Word8ArraySlice.length slice)
        val (a, i, _) = Word8ArraySlice.base slice
      in Word8Array.copyVec {src = got, dst = a, di = i}; size got end
    fun writeArr (fd, slice) = check (write' (fd, Word8ArraySlice.vector slice))

    datatype whence = SEEK_SET | SEEK_CUR | SEEK_END
    fun whenceBits SEEK_SET = named "SEEK_SET"
      | whenceBits SEEK_CUR = named "SEEK_CUR"
      | whenceBits SEEK_END = named "SEEK_END"
    fun lseek (fd, offset, whence) = check (lseek' (fd, offset, whenceBits whence))
    fun fsync fd = ignore (check (fsync' fd))

    structure FD =
    struct
      type flags = word
      val cloexec = Word.fromInt (named "FD_CLOEXEC")
      fun toWord (f : flags) = f
      fun fromWord w = w
      val all = cloexec
      fun flags l = List.foldl Word.orb 0w0 l
      fun allSet (a, b) = Word.andb (a, b) = a
      fun anySet (a, b) = Word.andb (a, b) <> 0w0
      fun clear (a, b) = Word.andb (Word.notb a, b)
    end

    structure O = RunePosixFileSys.O
    datatype open_mode = datatype RunePosixFileSys.open_mode

    fun dupfd {old, base} = check (fcntl' (old, named "F_DUPFD", base))
    fun getfd fd = Word.fromInt (check (fcntl' (fd, named "F_GETFD", 0)))
    fun setfd (fd, flags) = ignore (check (fcntl' (fd, named "F_SETFD", Word.toInt flags)))
    fun getfl fd =
      let
        val bits = check (fcntl' (fd, named "F_GETFL", 0))
        val accessBits = Word.fromInt (named "O_RDONLY") (* 0 on POSIX *)
        val mode = if Word.andb (Word.fromInt bits, 0w3) = Word.fromInt (named "O_WRONLY") then O_WRONLY
                   else if Word.andb (Word.fromInt bits, 0w3) = Word.fromInt (named "O_RDWR") then O_RDWR
                   else O_RDONLY
      in (Word.andb (Word.fromInt bits, Word.notb 0w3), mode) end
    fun setfl (fd, flags) = ignore (check (fcntl' (fd, named "F_SETFL", Word.toInt flags)))

    (* The readers and writers of PRIM_IO over a descriptor. *)
    fun mkBinReader {fd, name, initBlkMode} =
      BinPrimIO.RD {name = name, chunkSize = 4096,
                    readVec = SOME (fn n => readVec (fd, n)), readArr = SOME (fn sl => readArr (fd, sl)),
                    readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                    avail = fn () => NONE,
                    getPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                    setPos = SOME (fn p => ignore (lseek (fd, p, SEEK_SET))),
                    endPos = SOME (fn () =>
                      let val here = lseek (fd, 0, SEEK_CUR)
                          val theEnd = lseek (fd, 0, SEEK_END)
                      in ignore (lseek (fd, here, SEEK_SET)); theEnd end),
                    verifyPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                    close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}

    fun mkBinWriter {fd, name, initBlkMode, appendMode, chunkSize} =
      BinPrimIO.WR {name = name, chunkSize = chunkSize,
                    writeVec = SOME (fn sl => writeVec (fd, sl)), writeArr = SOME (fn sl => writeArr (fd, sl)),
                    writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                    getPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                    setPos = SOME (fn p => ignore (lseek (fd, p, SEEK_SET))),
                    endPos = SOME (fn () =>
                      let val here = lseek (fd, 0, SEEK_CUR)
                          val theEnd = lseek (fd, 0, SEEK_END)
                      in ignore (lseek (fd, here, SEEK_SET)); theEnd end),
                    verifyPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                    close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}

    fun mkTextReader {fd, name, initBlkMode} =
      TextPrimIO.RD {name = name, chunkSize = 4096,
                     readVec = SOME (fn n => readVec (fd, n)), readArr = NONE,
                     readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                     avail = fn () => NONE,
                     getPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                     setPos = SOME (fn p => ignore (lseek (fd, p, SEEK_SET))),
                     endPos = NONE, verifyPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                     close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}

    fun mkTextWriter {fd, name, initBlkMode, appendMode, chunkSize} =
      TextPrimIO.WR {name = name, chunkSize = chunkSize,
                     writeVec = SOME (fn sl => check (write' (fd, CharVectorSlice.vector sl))),
                     writeArr = NONE, writeVecNB = NONE, writeArrNB = NONE,
                     block = NONE, canOutput = NONE,
                     getPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                     setPos = SOME (fn p => ignore (lseek (fd, p, SEEK_SET))),
                     endPos = NONE, verifyPos = SOME (fn () => lseek (fd, 0, SEEK_CUR)),
                     close = fn () => close fd, ioDesc = SOME (RuneIODesc.FD fd)}
  end
end
