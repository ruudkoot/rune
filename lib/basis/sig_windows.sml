(* The operating system Windows: the registry, the configuration of the
   machine, dynamic data exchange, programs started with a pipe each way, and
   the codes a process ends with.

   The structure is there on every system, so a program that names it
   compiles anywhere. What asks Windows raises `OS.SysErr` on a system that
   is not Windows, with the error `ENOSYS`: all of `Reg`, the values
   `Config` reads from the machine, `DDE`, `execute` and the group around
   it, `getVolumeInformation`, `findExecutable`, `launchApplication` and
   `openDocument`. What asks nothing of Windows works everywhere: the flags
   of `Key`, the platforms of `Config`, the codes of `Status`, `fromStatus`
   and `exit` (below).

   Area: The operating system

   Status: optional

   See also: `OS_PROCESS`, `UNIX`, `BIT_FLAGS`, `TEXT_IO`, `BIN_IO`

   Implementation: `WINDOWS/code-page`. Names, strings of the registry and
   paths go to Windows through its code page (the `A` functions of Win32),
   byte for byte; a path given as `/C:/...`, as `OS.FileSys` writes the paths
   of a drive on Windows, is taken as `C:/...`.

   Pinned by: `Windows.getVolumeInformation/root-as-OS.FileSys-writes-it` *)
signature WINDOWS =
sig
  (* ---- The registry ---- *)

  (* The rights to ask for when a key of the registry is opened or created,
     as a set of flags. *)
  structure Key : sig
    include BIT_FLAGS

    (* All the rights below: `queryValue`, `enumerateSubKeys`, `notify`,
       `createSubKey`, `createLink` and `setValue` together.

       Implementation: `Windows.Key/the-unions-of-the-page`. `allAccess`,
       `read` and `write` are the unions the page gives, without the
       standard rights that `KEY_ALL_ACCESS`, `KEY_READ` and `KEY_WRITE` of
       Windows add; the others are the `KEY_*` values of Windows.

       Pinned by: `Windows.Key.allAccess/union`, `Windows.Key.read/union`,
       `Windows.Key.write/union` *)
    val allAccess : flags

    (* The right to make a symbolic link; the rest of the structure makes none. *)
    val createLink : flags

    (* The right to make subkeys. *)
    val createSubKey : flags

    (* The right to enumerate subkeys. *)
    val enumerateSubKeys : flags

    (* The right to read, the same as `read`. *)
    val execute : flags

    (* The right to be told of changes. *)
    val notify : flags

    (* The right to read values. *)
    val queryValue : flags

    (* The rights to read: `queryValue`, `enumerateSubKeys` and `notify` together. *)
    val read : flags

    (* The right to set values. *)
    val setValue : flags

    (* The rights to write: `setValue` and `createSubKey` together. *)
    val write : flags
  end

  (* Keys of the registry: opening, making, deleting, enumerating, and the
     values they hold. *)
  structure Reg : sig
    (* The type of an open key of the registry. *)
    eqtype hkey

    (* The root `HKEY_CLASSES_ROOT`: the kinds of files and the programs that open them. *)
    val classesRoot : hkey

    (* The root `HKEY_CURRENT_USER`: the settings of the user of this process. *)
    val currentUser : hkey

    (* The root `HKEY_LOCAL_MACHINE`: the settings of the machine. *)
    val localMachine : hkey

    (* The root `HKEY_USERS`: the settings of every user of the machine. *)
    val users : hkey

    (* The root `HKEY_PERFORMANCE_DATA`: counters of performance, read and never kept. *)
    val performanceData : hkey

    (* The root `HKEY_CURRENT_CONFIG`: the profile of the hardware the machine runs with. *)
    val currentConfig : hkey

    (* The root `HKEY_DYN_DATA` of Windows 95 and 98, which no Windows of today opens. *)
    val dynData : hkey

    (* What `createKeyEx` did. *)
    datatype create_result
      = CREATED_NEW_KEY of hkey      (* it made the key, which is open *)
      | OPENED_EXISTING_KEY of hkey  (* the key was there, and it opened it *)

    (* `createKeyEx (hkey, skey, regsam)` opens the subkey `skey` of `hkey` with the rights `regsam`, making it when it is not there.

       The key is not volatile, and has no class and the default security,
       as the page asks.

       Raises: `OS.SysErr` if the key cannot be made or opened, as without
       the right to. *)
    val createKeyEx : hkey * string * Key.flags -> create_result

    (* `openKeyEx (hkey, skey, regsam)` opens the subkey `skey` of `hkey` with the rights `regsam`.

       Raises: `OS.SysErr` if there is no such key, or it may not be opened so. *)
    val openKeyEx : hkey * string * Key.flags -> hkey

    (* `closeKey hkey` closes the key `hkey`; a key at a root is left open.

       Raises: `OS.SysErr` if `hkey` is not open. *)
    val closeKey : hkey -> unit

    (* `deleteKey (hkey, skey)` deletes the subkey `skey` of `hkey`, which may have no subkeys itself.

       Raises: `OS.SysErr` if there is no such key, it has subkeys, or it may not be deleted. *)
    val deleteKey : hkey * string -> unit

    (* `deleteValue (hkey, valname)` deletes the value `valname` of `hkey`.

       Raises: `OS.SysErr` if there is no such value, or it may not be deleted. *)
    val deleteValue : hkey * string -> unit

    (* `enumKeyEx (hkey, ind)` is the name of the subkey number `ind` of `hkey`, counted from zero, or `NONE` past the last.

       Raises: `Subscript` if `ind` is negative.

       Raises: `OS.SysErr` if the key cannot be read. *)
    val enumKeyEx : hkey * int -> string option

    (* `enumValueEx (hkey, ind)` is the name of the value number `ind` of `hkey`, counted from zero, or `NONE` past the last.

       Raises: `Subscript` if `ind` is negative.

       Raises: `OS.SysErr` if the key cannot be read. *)
    val enumValueEx : hkey * int -> string option

    (* A value of the registry, by its kind. *)
    datatype value
      = SZ of string                  (* a string, `REG_SZ` *)
      | DWORD of SysWord.word         (* a number of 32 bits, `REG_DWORD` *)
      | BINARY of Word8Vector.vector  (* bytes, `REG_BINARY`, and every kind not otherwise named *)
      | MULTI_SZ of string list       (* strings, `REG_MULTI_SZ` *)
      | EXPAND_SZ of string           (* a string with variables of the environment in it, `REG_EXPAND_SZ` *)

    (* `queryValueEx (hkey, name)` is the value `name` of `hkey`, or `NONE` when it has none of that name.

       Raises: `OS.SysErr` for any other failure, as for want of the right to read. *)
    val queryValueEx : hkey * string -> value option

    (* `setValueEx (hkey, name, v)` sets the value `name` of `hkey` to `v`.

       Raises: `OS.SysErr` if it may not. *)
    val setValueEx : hkey * string * value -> unit
  end

  (* ---- The machine ---- *)

  (* What the system is, where it is kept, and who uses it. *)
  structure Config : sig
    (* The platform Win32s, 32 bits on Windows 3.1, as `getVersionEx` names it. *)
    val platformWin32s : SysWord.word

    (* The platform of Windows 95, 98 and Me. *)
    val platformWin32Windows : SysWord.word

    (* The platform of Windows NT and of every Windows since, which is what `getVersionEx` says today. *)
    val platformWin32NT : SysWord.word

    (* The platform of Windows CE. *)
    val platformWin32CE : SysWord.word

    (* `getVersionEx ()` is the version of Windows: major, minor and build, the platform, and the service pack.

       Implementation: `Windows.Config.getVersionEx/the-real-version`. The
       version is the one Windows is, as `RtlGetVersion` gives it, and not
       the one a program's manifest would make `GetVersionEx` answer: 10.0
       and its build on Windows 11 too.

       Pinned by: `Windows.Config.getVersionEx/is-NT` *)
    val getVersionEx : unit -> {majorVersion : SysWord.word, minorVersion : SysWord.word,
                                buildNumber : SysWord.word, platformId : SysWord.word, csdVersion : string}

    (* `getWindowsDirectory ()` is the directory of Windows, as Windows writes it: `C:\Windows`. *)
    val getWindowsDirectory : unit -> string

    (* `getSystemDirectory ()` is the system directory of Windows, as Windows writes it: `C:\Windows\system32`. *)
    val getSystemDirectory : unit -> string

    (* `getComputerName ()` is the name of the computer. *)
    val getComputerName : unit -> string

    (* `getUserName ()` is the name of the user of this process. *)
    val getUserName : unit -> string
  end

  (* ---- Dynamic data exchange ---- *)

  (* A client of DDE: a conversation with a service, on a topic, in which
     commands are executed, each transaction waiting for its answer. *)
  structure DDE : sig
    (* The type of a conversation. *)
    type info

    (* `startDialog (service, topic)` starts a conversation with `service` on `topic`.

       Raises: `OS.SysErr` if no service of that name answers on that topic. *)
    val startDialog : string * string -> info

    (* `executeString (info, cmd, retry, delay)` has the service of `info` execute `cmd`, trying again `retry` times, `delay` apart, while it is busy.

       Each try waits for the service's answer for as long as `delay`, and
       the tries are `delay` apart.

       Raises: `OS.SysErr` if the command fails, or the service stays busy. *)
    val executeString : info * string * int * Time.time -> unit

    (* `stopDialog info` ends the conversation `info`.

       Raises: `OS.SysErr` if it has ended already. *)
    val stopDialog : info -> unit
  end

  (* ---- Files and programs ---- *)

  (* `getVolumeInformation root` is what Windows says of the volume whose root is `root`.

     The name of the volume, the name of its file system (`NTFS`), its
     serial number, and the longest name a file on it may have.

     Raises: `OS.SysErr` if `root` is not the root of a volume. *)
  val getVolumeInformation : string -> {volumeName : string, systemName : string,
                                        serialNumber : SysWord.word, maximumComponentLength : int}

  (* `findExecutable name` is the program Windows opens the file `name` with, or `NONE` when there is none. *)
  val findExecutable : string -> string option

  (* `launchApplication (file, arg)` starts the program `file` with the argument `arg`, and does not wait for it.

     Raises: `OS.SysErr` if `file` is not a program, or cannot be started. *)
  val launchApplication : string * string -> unit

  (* `openDocument file` opens `file` with the program Windows opens it with.

     Raises: `OS.SysErr` if there is no such file or no such program. *)
  val openDocument : string -> unit

  (* `simpleExecute (cmd, arg)` runs the program `cmd` with the arguments `arg`, and is its status when it ends.

     It reads from the null device and writes to it; its standard error is
     this process's.

     Raises: `OS.SysErr` if the program cannot be started. *)
  val simpleExecute : string * string -> OS.Process.status

  (* The type of a program started by `execute`, with the streams that talk to it.

     The first type variable is the stream its output is read through, the
     second the stream its input is written through. *)
  type ('a, 'b) proc

  (* `execute (cmd, arg)` starts the program `cmd` with the arguments `arg`, with a pipe each way.

     Its standard error is this process's; this process's ends of the pipes
     are not handed to programs started later.

     Raises: `OS.SysErr` if the program cannot be started. *)
  val execute : string * string -> ('a, 'b) proc

  (* `textInstreamOf pr` is a text stream from which what `pr` writes is read. *)
  val textInstreamOf : (TextIO.instream, 'a) proc -> TextIO.instream

  (* `binInstreamOf pr` is a binary stream from which what `pr` writes is read. *)
  val binInstreamOf : (BinIO.instream, 'a) proc -> BinIO.instream

  (* `textOutstreamOf pr` is a text stream to which what `pr` reads is written. *)
  val textOutstreamOf : ('a, TextIO.outstream) proc -> TextIO.outstream

  (* `binOutstreamOf pr` is a binary stream to which what `pr` reads is written. *)
  val binOutstreamOf : ('a, BinIO.outstream) proc -> BinIO.outstream

  (* `reap pr` closes the pipes of `pr`, waits for it to end, and is the code it ended with.

     Reaping it again gives the same status at once, as the page asks.

     Raises: `OS.SysErr` if the wait fails. *)
  val reap : ('a, 'b) proc -> OS.Process.status

  (* ---- How a process ends ---- *)

  (* The codes with which Windows ends a process that an exception ends:
     the `STATUS_*` codes of Windows. *)
  structure Status : sig
    (* The type of the code a process ended with. *)
    type status = SysWord.word

    (* A read or write of memory the process may not touch, `STATUS_ACCESS_VIOLATION`. *)
    val accessViolation : status

    (* An index beyond the bounds of an array, found by the processor, `STATUS_ARRAY_BOUNDS_EXCEEDED`. *)
    val arrayBoundsExceeded : status

    (* A breakpoint reached with no debugger to take it, `STATUS_BREAKPOINT`. *)
    val breakpoint : status

    (* The end of a program at ^C or at the close of its console, `STATUS_CONTROL_C_EXIT`. *)
    val controlCExit : status

    (* Data read or written at an address it may not be at, `STATUS_DATATYPE_MISALIGNMENT`. *)
    val datatypeMisalignment : status

    (* A denormal operand of floating point, `STATUS_FLOAT_DENORMAL_OPERAND`. *)
    val floatDenormalOperand : status

    (* A division of floating point by zero, `STATUS_FLOAT_DIVIDE_BY_ZERO`. *)
    val floatDivideByZero : status

    (* A result of floating point that is not exact, `STATUS_FLOAT_INEXACT_RESULT`. *)
    val floatInexactResult : status

    (* An invalid operation of floating point, `STATUS_FLOAT_INVALID_OPERATION`. *)
    val floatInvalidOperation : status

    (* An overflow of floating point, `STATUS_FLOAT_OVERFLOW`. *)
    val floatOverflow : status

    (* The stack of the floating-point unit over- or underflowed, `STATUS_FLOAT_STACK_CHECK`. *)
    val floatStackCheck : status

    (* An underflow of floating point, `STATUS_FLOAT_UNDERFLOW`. *)
    val floatUnderflow : status

    (* A guard page of memory touched, `STATUS_GUARD_PAGE_VIOLATION`. *)
    val guardPageViolation : status

    (* A division of integers by zero, `STATUS_INTEGER_DIVIDE_BY_ZERO`. *)
    val integerDivideByZero : status

    (* An overflow of integers, `STATUS_INTEGER_OVERFLOW`. *)
    val integerOverflow : status

    (* An instruction the processor does not have, `STATUS_ILLEGAL_INSTRUCTION`. *)
    val illegalInstruction : status

    (* A handler of exceptions that answered what it may not, `STATUS_INVALID_DISPOSITION`. *)
    val invalidDisposition : status

    (* A handle that is not open, `STATUS_INVALID_HANDLE`. *)
    val invalidHandle : status

    (* A page of memory that could not be read in, `STATUS_IN_PAGE_ERROR`. *)
    val inPageError : status

    (* An exception continued that may not be, `STATUS_NONCONTINUABLE_EXCEPTION`. *)
    val noncontinuableException : status

    (* An operation that has not ended yet, `STATUS_PENDING`. *)
    val pending : status

    (* An instruction only the system may execute, `STATUS_PRIVILEGED_INSTRUCTION`. *)
    val privilegedInstruction : status

    (* A step of a program traced with no debugger to take it, `STATUS_SINGLE_STEP`. *)
    val singleStep : status

    (* The stack of a thread overflowed, `STATUS_STACK_OVERFLOW`. *)
    val stackOverflow : status

    (* A wait that ran out of time, `STATUS_TIMEOUT`. *)
    val timeout : status

    (* A wait ended by a call queued for the thread, `STATUS_USER_APC`. *)
    val userAPC : status
  end

  (* `fromStatus s` is the code of Windows that the status `s` stands for. *)
  val fromStatus : OS.Process.status -> Status.status

  (* `exit st` runs the actions of `OS.Process.atExit`, flushes and closes the files, and ends this program with the code `st`.

     Implementation: `Windows.exit/the-code-off-windows`. This is one of the
     values that need no Windows, and the program ends with `st` wherever it
     runs; but a system of POSIX gives a parent the low eight bits of a code
     alone, where Windows gives the whole of it, which is what `reap` reads
     back. *)
  val exit : Status.status -> 'a
end
