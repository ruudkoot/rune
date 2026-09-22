(* Windows: the registry, the configuration of the machine, DDE, programs
   started with pipes to them, and the codes a process ends with, over the
   primitives win_* of vm/prims.def. On a system other than Windows every
   call of the system raises OS.SysErr with ENOSYS; the constants (the flags
   of Key, the codes of Status) are there everywhere.

   Implements: WINDOWS

   Status: optional *)
structure Windows =
struct
  local
    val regOpen = _prim "win_reg_open" : int * string * int * int -> int list
    val regClose = _prim "win_reg_close" : int -> int
    val regDelete = _prim "win_reg_delete" : int * string * int -> int
    val regEnum = _prim "win_reg_enum" : int * int * int -> string list
    val regQuery = _prim "win_reg_query" : int * string -> string list
    val regSet = _prim "win_reg_set" : int * string * int * string -> int
    val config = _prim "win_config" : int -> string
    val version = _prim "win_version" : unit -> string list
    val volume = _prim "win_volume" : string -> string list
    val findExe = _prim "win_find_executable" : string -> string list
    val shellExecute = _prim "win_shell_execute" : string * string * int -> int
    val spawn = _prim "win_spawn" : string * string * int list -> int
    val wait = _prim "win_wait" : int -> int list
    val ddeStart = _prim "win_dde_start" : string * string -> int
    val ddeExecute = _prim "win_dde_execute" : int * string * int * int -> int
    val ddeStop = _prim "win_dde_stop" : int -> int
    val errno = _prim "sys_errno" : unit -> int
    val exit' = _prim "exit" : int -> 'a
    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun checkString s = if s = "" then raise RuneError.lastError () else s
    (* a list of strings, or the failure the system left *)
    fun strings [] = raise RuneError.lastError ()
      | strings l = l
    fun number s = case Int.fromString s of SOME n => n | NONE => 0
    fun word s = SysWord.fromInt (number s)
  in
    structure Key =
    struct
      type flags = SysWord.word
      (* KEY_* of winnt.h *)
      val queryValue = 0wx1 : flags
      val setValue = 0wx2 : flags
      val createSubKey = 0wx4 : flags
      val enumerateSubKeys = 0wx8 : flags
      val notify = 0wx10 : flags
      val createLink = 0wx20 : flags
      (* the unions the specification gives, without the standard rights
         that KEY_READ, KEY_WRITE and KEY_ALL_ACCESS of winnt.h add *)
      val read = 0wx19 : flags
      val execute = read
      val write = 0wx6 : flags
      val allAccess = 0wx3F : flags
      val all = allAccess
      fun toWord (f : flags) = f
      fun fromWord w = SysWord.andb (w, all)
      fun flags l = List.foldl SysWord.orb 0w0 l
      fun intersect l = List.foldl SysWord.andb all l
      fun clear (a, b) = SysWord.andb (SysWord.notb a, b)
      fun allSet (a, b) = SysWord.andb (a, b) = a
      fun anySet (a, b) = SysWord.andb (a, b) <> 0w0
    end

    structure Reg =
    struct
      datatype hkey = KEY of int
      val classesRoot = KEY 0
      val currentUser = KEY 1
      val localMachine = KEY 2
      val users = KEY 3
      val performanceData = KEY 4
      val currentConfig = KEY 5
      val dynData = KEY 6
      datatype create_result
        = CREATED_NEW_KEY of hkey
        | OPENED_EXISTING_KEY of hkey
      fun access flags = SysWord.toInt (Key.toWord flags)
      fun openOrCreate (KEY k, name, flags, create) =
        case regOpen (k, name, access flags, create) of
          [1, key] => CREATED_NEW_KEY (KEY key)
        | [_, key] => OPENED_EXISTING_KEY (KEY key)
        | _ => raise RuneError.lastError ()
      fun createKeyEx (hkey, name, flags) = openOrCreate (hkey, name, flags, 1)
      fun openKeyEx (hkey, name, flags) =
        case openOrCreate (hkey, name, flags, 0) of
          CREATED_NEW_KEY k => k
        | OPENED_EXISTING_KEY k => k
      fun closeKey (KEY k) = ignore (check (regClose k))
      fun deleteKey (KEY k, name) = ignore (check (regDelete (k, name, 0)))
      fun deleteValue (KEY k, name) = ignore (check (regDelete (k, name, 1)))
      (* "raises the Subscript exception if ind is invalid": a negative one *)
      fun enum (KEY k, i, which) =
        if i < 0 then raise Subscript
        else case regEnum (k, i, which) of
               [name] => SOME name
             | _ => if errno () = 0 then NONE else raise RuneError.lastError ()
      fun enumKeyEx (hkey, i) = enum (hkey, i, 0)
      fun enumValueEx (hkey, i) = enum (hkey, i, 1)
      datatype value
        = SZ of string
        | DWORD of SysWord.word
        | BINARY of Word8Vector.vector
        | MULTI_SZ of string list
        | EXPAND_SZ of string
      (* REG_* of winnt.h *)
      val regSz = 1  val regExpandSz = 2  val regBinary = 3  val regDword = 4  val regMultiSz = 7
      (* a string as the registry keeps it, ended by a NUL, or not *)
      fun unterminated s =
        let val n = String.size s
        in if n > 0 andalso String.sub (s, n - 1) = #"\000" then String.substring (s, 0, n - 1) else s end
      fun dword s =
        if String.size s < 4 then 0w0
        else List.foldr (fn (i, w) => SysWord.orb (SysWord.<< (w, 0w8), SysWord.fromInt (Char.ord (String.sub (s, i)))))
                        0w0 [0, 1, 2, 3]
      fun queryValueEx (KEY k, name) =
        case regQuery (k, name) of
          [kind, data] =>
            SOME (case number kind of
                    1 => SZ (unterminated data)
                  | 2 => EXPAND_SZ (unterminated data)
                  | 4 => DWORD (dword data)
                  | 7 => MULTI_SZ (List.filter (fn s => s <> "") (String.fields (fn c => c = #"\000") data))
                  | _ => BINARY (Byte.stringToBytes data))
        | _ => if errno () = 0 then NONE else raise RuneError.lastError ()
      fun bytesOfDword w =
        String.implode (List.map (fn i => Char.chr (SysWord.toInt (SysWord.andb (SysWord.>> (w, Word.fromInt (8 * i)), 0wxFF))))
                                 [0, 1, 2, 3])
      fun setValueEx (KEY k, name, v) =
        let
          val (kind, data) =
            case v of
              SZ s => (regSz, s ^ "\000")
            | EXPAND_SZ s => (regExpandSz, s ^ "\000")
            | DWORD w => (regDword, bytesOfDword w)
            | BINARY b => (regBinary, Byte.bytesToString b)
            | MULTI_SZ l => (regMultiSz, String.concat (List.map (fn s => s ^ "\000") l) ^ "\000")
        in ignore (check (regSet (k, name, kind, data))) end
    end

    structure Config =
    struct
      (* VER_PLATFORM_* of winnt.h; Windows CE's is 3 *)
      val platformWin32s = 0w0 : SysWord.word
      val platformWin32Windows = 0w1 : SysWord.word
      val platformWin32NT = 0w2 : SysWord.word
      val platformWin32CE = 0w3 : SysWord.word
      fun getVersionEx () =
        case strings (version ()) of
          [major, minor, build, platform, csd] =>
            {majorVersion = word major, minorVersion = word minor, buildNumber = word build,
             platformId = word platform, csdVersion = csd}
        | _ => raise RuneError.lastError ()
      fun getWindowsDirectory () = checkString (config 0)
      fun getSystemDirectory () = checkString (config 1)
      fun getComputerName () = checkString (config 2)
      fun getUserName () = checkString (config 3)
    end

    structure DDE =
    struct
      datatype info = INFO of int
      fun startDialog (service, topic) = INFO (check (ddeStart (service, topic)))
      (* the delay as whole milliseconds, at least one *)
      fun executeString (INFO i, cmd, retry, delay) =
        let val ms = Int.max (1, Int.fromLarge (Time.toMilliseconds delay) handle Overflow => valOf Int.maxInt)
        in ignore (check (ddeExecute (i, cmd, retry, ms))) end
      fun stopDialog (INFO i) = ignore (check (ddeStop i))
    end

    fun getVolumeInformation root =
      case strings (volume root) of
        [volumeName, systemName, serial, longest] =>
          {volumeName = volumeName, systemName = systemName, serialNumber = word serial,
           maximumComponentLength = number longest}
      | _ => raise RuneError.lastError ()
    fun findExecutable name =
      case findExe name of
        [path] => SOME path
      | _ => if errno () = 0 then NONE else raise RuneError.lastError ()
    fun launchApplication (file, arg) = ignore (check (shellExecute (file, arg, 0)))
    fun openDocument file = ignore (check (shellExecute (file, "", 1)))

    fun number fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
    fun waitFor pid =
      case wait pid of
        [code] => RuneStatus.fromInt code
      | _ => raise RuneError.lastError ()

    (* "redirecting standard input and standard output to the null device" *)
    fun simpleExecute (cmd, arg) =
      let
        val null = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDWR, Posix.FileSys.O.flags [])
        val pid = spawn (cmd, arg, [number null, number null, ~1])
        val failure = if pid < 0 then SOME (RuneError.lastError ()) else NONE
      in
        Posix.IO.close null;
        case failure of SOME e => raise e | NONE => waitFor pid
      end

    datatype ('a, 'b) proc =
      Proc of {pid : int, infd : Posix.FileSys.file_desc, outfd : Posix.FileSys.file_desc,
               status : OS.Process.status option ref}
    (* the program with a pipe each way, as Unix.execute starts it *)
    fun execute (cmd, arg) =
      let
        val {infd = fromChildRead, outfd = fromChildWrite} = Posix.IO.pipe ()
        val {infd = toChildRead, outfd = toChildWrite} = Posix.IO.pipe ()
        val () = Posix.IO.setfd (fromChildRead, Posix.IO.FD.cloexec)
        val () = Posix.IO.setfd (toChildWrite, Posix.IO.FD.cloexec)
        val pid = spawn (cmd, arg, [number toChildRead, number fromChildWrite, ~1])
        val failure = if pid < 0 then SOME (RuneError.lastError ()) else NONE
      in
        Posix.IO.close fromChildWrite;
        Posix.IO.close toChildRead;
        case failure of
          SOME e => (Posix.IO.close fromChildRead; Posix.IO.close toChildWrite; raise e)
        | NONE => Proc {pid = pid, infd = fromChildRead, outfd = toChildWrite, status = ref NONE}
      end
    fun textInstreamOf (Proc {infd, ...}) =
      TextIO.mkInstream (TextIO.StreamIO.mkInstream
        (Posix.IO.mkTextReader {fd = infd, name = "<process>", initBlkMode = true}, ""))
    fun binInstreamOf (Proc {infd, ...}) =
      BinIO.mkInstream (BinIO.StreamIO.mkInstream
        (Posix.IO.mkBinReader {fd = infd, name = "<process>", initBlkMode = true}, Word8Vector.fromList []))
    fun textOutstreamOf (Proc {outfd, ...}) =
      TextIO.mkOutstream (TextIO.StreamIO.mkOutstream
        (Posix.IO.mkTextWriter {fd = outfd, name = "<process>", initBlkMode = true,
                                appendMode = false, chunkSize = 4096}, IO.NO_BUF))
    fun binOutstreamOf (Proc {outfd, ...}) =
      BinIO.mkOutstream (BinIO.StreamIO.mkOutstream
        (Posix.IO.mkBinWriter {fd = outfd, name = "<process>", initBlkMode = true,
                               appendMode = false, chunkSize = 4096}, IO.NO_BUF))
    (* "If reap is applied again to pr, it should immediately return the
       previous exit status" *)
    fun reap (Proc {pid, infd, outfd, status}) =
      case !status of
        SOME s => s
      | NONE =>
          let
            val () = (Posix.IO.close outfd handle _ => ())
            val () = (Posix.IO.close infd handle _ => ())
            val s = waitFor pid
          in status := SOME s; s end

    structure Status =
    struct
      type status = SysWord.word
      (* STATUS_* of ntstatus.h *)
      val accessViolation = 0wxC0000005 : status
      val arrayBoundsExceeded = 0wxC000008C : status
      val breakpoint = 0wx80000003 : status
      val controlCExit = 0wxC000013A : status
      val datatypeMisalignment = 0wx80000002 : status
      val floatDenormalOperand = 0wxC000008D : status
      val floatDivideByZero = 0wxC000008E : status
      val floatInexactResult = 0wxC000008F : status
      val floatInvalidOperation = 0wxC0000090 : status
      val floatOverflow = 0wxC0000091 : status
      val floatStackCheck = 0wxC0000092 : status
      val floatUnderflow = 0wxC0000093 : status
      val guardPageViolation = 0wx80000001 : status
      val integerDivideByZero = 0wxC0000094 : status
      val integerOverflow = 0wxC0000095 : status
      val illegalInstruction = 0wxC000001D : status
      val invalidDisposition = 0wxC0000026 : status
      val invalidHandle = 0wxC0000008 : status
      val inPageError = 0wxC0000006 : status
      val noncontinuableException = 0wxC0000025 : status
      val pending = 0wx103 : status
      val privilegedInstruction = 0wxC0000096 : status
      val singleStep = 0wx80000004 : status
      val stackOverflow = 0wxC00000FD : status
      val timeout = 0wx102 : status
      val userAPC = 0wxC0 : status
    end
    fun fromStatus s = SysWord.andb (SysWord.fromInt (RuneStatus.toInt s), 0wxFFFFFFFF)
    (* "executes all actions registered with OS.Process.atExit, flushes and
       closes all I/O streams, then terminates" *)
    fun exit (st : Status.status) = (RuneExit.run (); exit' (SysWord.toInt st))
  end
end
