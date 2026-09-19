(* The signatures of the specification are in the top-level environment
   (the basis library's signature files, made from tests/basis/spec-sigs by
   scripts/gen-basis-sigs.sh, and the ones lib/basis declares itself), and
   the structures match them. One section per signature, so that a host
   without one signature still runs the others. *)
structure TestSignatures =
struct
  (*<< array *)
  structure S0 : ARRAY = Array
  val () = T.check ("Array:ARRAY/basis-signature", fn () => true)
  (*>> array *)
  (*<< array2 *)
  structure S1 : ARRAY2 = Array2
  val () = T.check ("Array2:ARRAY2/basis-signature", fn () => true)
  (*>> array2 *)
  (*<< array-slice *)
  structure S2 : ARRAY_SLICE = ArraySlice
  val () = T.check ("ArraySlice:ARRAY_SLICE/basis-signature", fn () => true)
  (*>> array-slice *)
  (*<< bit-flags *)
  structure S3 : BIT_FLAGS = Posix.FileSys.S
  val () = T.check ("Posix.FileSys.S:BIT_FLAGS/basis-signature", fn () => true)
  (*>> bit-flags *)
  (*<< bool *)
  structure S4 : BOOL = Bool
  val () = T.check ("Bool:BOOL/basis-signature", fn () => true)
  (*>> bool *)
  (*<< byte *)
  structure S5 : BYTE = Byte
  val () = T.check ("Byte:BYTE/basis-signature", fn () => true)
  (*>> byte *)
  (*<< char *)
  structure S6 : CHAR = Char
  val () = T.check ("Char:CHAR/basis-signature", fn () => true)
  (*>> char *)
  (*<< command-line *)
  structure S7 : COMMAND_LINE = CommandLine
  val () = T.check ("CommandLine:COMMAND_LINE/basis-signature", fn () => true)
  (*>> command-line *)
  (*<< date *)
  structure S8 : DATE = Date
  val () = T.check ("Date:DATE/basis-signature", fn () => true)
  (*>> date *)
  (*<< general *)
  structure S9 : GENERAL = General
  val () = T.check ("General:GENERAL/basis-signature", fn () => true)
  (*>> general *)
  (*<< generic-sock *)
  structure S10 : GENERIC_SOCK = GenericSock
  val () = T.check ("GenericSock:GENERIC_SOCK/basis-signature", fn () => true)
  (*>> generic-sock *)
  (*<< ieee-real *)
  structure S11 : IEEE_REAL = IEEEReal
  val () = T.check ("IEEEReal:IEEE_REAL/basis-signature", fn () => true)
  (*>> ieee-real *)
  (*<< imperative-io *)
  structure S12 : IMPERATIVE_IO = TextIO
  val () = T.check ("TextIO:IMPERATIVE_IO/basis-signature", fn () => true)
  (*>> imperative-io *)
  (*<< inet-sock *)
  structure S13 : INET_SOCK = INetSock
  val () = T.check ("INetSock:INET_SOCK/basis-signature", fn () => true)
  (*>> inet-sock *)
  (*<< integer *)
  structure S14 : INTEGER = Int
  val () = T.check ("Int:INTEGER/basis-signature", fn () => true)
  (*>> integer *)
  (*<< int-inf *)
  structure S15 : INT_INF = IntInf
  val () = T.check ("IntInf:INT_INF/basis-signature", fn () => true)
  (*>> int-inf *)
  (*<< io *)
  structure S16 : IO = IO
  val () = T.check ("IO:IO/basis-signature", fn () => true)
  (*>> io *)
  (*<< list *)
  structure S17 : LIST = List
  val () = T.check ("List:LIST/basis-signature", fn () => true)
  (*>> list *)
  (*<< list-pair *)
  structure S18 : LIST_PAIR = ListPair
  val () = T.check ("ListPair:LIST_PAIR/basis-signature", fn () => true)
  (*>> list-pair *)
  (*<< math *)
  structure S19 : MATH = Math
  val () = T.check ("Math:MATH/basis-signature", fn () => true)
  (*>> math *)
  (*<< net-host-db *)
  structure S20 : NET_HOST_DB = NetHostDB
  val () = T.check ("NetHostDB:NET_HOST_DB/basis-signature", fn () => true)
  (*>> net-host-db *)
  (*<< net-prot-db *)
  structure S21 : NET_PROT_DB = NetProtDB
  val () = T.check ("NetProtDB:NET_PROT_DB/basis-signature", fn () => true)
  (*>> net-prot-db *)
  (*<< net-serv-db *)
  structure S22 : NET_SERV_DB = NetServDB
  val () = T.check ("NetServDB:NET_SERV_DB/basis-signature", fn () => true)
  (*>> net-serv-db *)
  (*<< option *)
  structure S23 : OPTION = Option
  val () = T.check ("Option:OPTION/basis-signature", fn () => true)
  (*>> option *)
  (*<< os *)
  structure S24 : OS = OS
  val () = T.check ("OS:OS/basis-signature", fn () => true)
  (*>> os *)
  (*<< os-file-sys *)
  structure S25 : OS_FILE_SYS = OS.FileSys
  val () = T.check ("OS.FileSys:OS_FILE_SYS/basis-signature", fn () => true)
  (*>> os-file-sys *)
  (*<< os-io *)
  structure S26 : OS_IO = OS.IO
  val () = T.check ("OS.IO:OS_IO/basis-signature", fn () => true)
  (*>> os-io *)
  (*<< os-path *)
  structure S27 : OS_PATH = OS.Path
  val () = T.check ("OS.Path:OS_PATH/basis-signature", fn () => true)
  (*>> os-path *)
  (*<< os-process *)
  structure S28 : OS_PROCESS = OS.Process
  val () = T.check ("OS.Process:OS_PROCESS/basis-signature", fn () => true)
  (*>> os-process *)
  (*<< posix-error *)
  structure S29 : POSIX_ERROR = Posix.Error
  val () = T.check ("Posix.Error:POSIX_ERROR/basis-signature", fn () => true)
  (*>> posix-error *)
  (*<< posix-file-sys *)
  structure S30 : POSIX_FILE_SYS = Posix.FileSys
  val () = T.check ("Posix.FileSys:POSIX_FILE_SYS/basis-signature", fn () => true)
  (*>> posix-file-sys *)
  (*<< posix-io *)
  structure S31 : POSIX_IO = Posix.IO
  val () = T.check ("Posix.IO:POSIX_IO/basis-signature", fn () => true)
  (*>> posix-io *)
  (*<< posix-process *)
  structure S32 : POSIX_PROCESS = Posix.Process
  val () = T.check ("Posix.Process:POSIX_PROCESS/basis-signature", fn () => true)
  (*>> posix-process *)
  (*<< posix-proc-env *)
  structure S33 : POSIX_PROC_ENV = Posix.ProcEnv
  val () = T.check ("Posix.ProcEnv:POSIX_PROC_ENV/basis-signature", fn () => true)
  (*>> posix-proc-env *)
  (*<< posix-signal *)
  structure S34 : POSIX_SIGNAL = Posix.Signal
  val () = T.check ("Posix.Signal:POSIX_SIGNAL/basis-signature", fn () => true)
  (*>> posix-signal *)
  (*<< posix-sys-db *)
  structure S35 : POSIX_SYS_DB = Posix.SysDB
  val () = T.check ("Posix.SysDB:POSIX_SYS_DB/basis-signature", fn () => true)
  (*>> posix-sys-db *)
  (*<< real *)
  structure S36 : REAL = Real
  val () = T.check ("Real:REAL/basis-signature", fn () => true)
  (*>> real *)
  (*<< socket *)
  structure S37 : SOCKET = Socket
  val () = T.check ("Socket:SOCKET/basis-signature", fn () => true)
  (*>> socket *)
  (*<< string *)
  structure S38 : STRING = String
  val () = T.check ("String:STRING/basis-signature", fn () => true)
  (*>> string *)
  (*<< string-cvt *)
  structure S39 : STRING_CVT = StringCvt
  val () = T.check ("StringCvt:STRING_CVT/basis-signature", fn () => true)
  (*>> string-cvt *)
  (*<< substring *)
  structure S40 : SUBSTRING = Substring
  val () = T.check ("Substring:SUBSTRING/basis-signature", fn () => true)
  (*>> substring *)
  (*<< text *)
  structure S41 : TEXT = Text
  val () = T.check ("Text:TEXT/basis-signature", fn () => true)
  (*>> text *)
  (*<< text-io *)
  structure S42 : TEXT_IO = TextIO
  val () = T.check ("TextIO:TEXT_IO/basis-signature", fn () => true)
  (*>> text-io *)
  (*<< text-stream-io *)
  structure S43 : TEXT_STREAM_IO = TextIO.StreamIO
  val () = T.check ("TextIO.StreamIO:TEXT_STREAM_IO/basis-signature", fn () => true)
  (*>> text-stream-io *)
  (*<< bin-io *)
  structure S44 : BIN_IO = BinIO
  val () = T.check ("BinIO:BIN_IO/basis-signature", fn () => true)
  (*>> bin-io *)
  (*<< stream-io *)
  structure S45 : STREAM_IO = BinIO.StreamIO
  val () = T.check ("BinIO.StreamIO:STREAM_IO/basis-signature", fn () => true)
  (*>> stream-io *)
  (*<< prim-io *)
  structure S46 : PRIM_IO = TextPrimIO
  val () = T.check ("TextPrimIO:PRIM_IO/basis-signature", fn () => true)
  (*>> prim-io *)
  (*<< time *)
  structure S47 : TIME = Time
  val () = T.check ("Time:TIME/basis-signature", fn () => true)
  (*>> time *)
  (*<< timer *)
  structure S48 : TIMER = Timer
  val () = T.check ("Timer:TIMER/basis-signature", fn () => true)
  (*>> timer *)
  (*<< unix *)
  structure S49 : UNIX = Unix
  val () = T.check ("Unix:UNIX/basis-signature", fn () => true)
  (*>> unix *)
  (*<< unix-sock *)
  structure S50 : UNIX_SOCK = UnixSock
  val () = T.check ("UnixSock:UNIX_SOCK/basis-signature", fn () => true)
  (*>> unix-sock *)
  (*<< vector *)
  structure S51 : VECTOR = Vector
  val () = T.check ("Vector:VECTOR/basis-signature", fn () => true)
  (*>> vector *)
  (*<< vector-slice *)
  structure S52 : VECTOR_SLICE = VectorSlice
  val () = T.check ("VectorSlice:VECTOR_SLICE/basis-signature", fn () => true)
  (*>> vector-slice *)
  (*<< word *)
  structure S53 : WORD = Word
  val () = T.check ("Word:WORD/basis-signature", fn () => true)
  (*>> word *)
  (*<< mono-vector *)
  structure S54 : MONO_VECTOR = Word8Vector
  val () = T.check ("Word8Vector:MONO_VECTOR/basis-signature", fn () => true)
  (*>> mono-vector *)
  (*<< mono-array *)
  structure S55 : MONO_ARRAY = CharArray
  val () = T.check ("CharArray:MONO_ARRAY/basis-signature", fn () => true)
  (*>> mono-array *)
  (*<< mono-vector-slice *)
  structure S56 : MONO_VECTOR_SLICE = CharVectorSlice
  val () = T.check ("CharVectorSlice:MONO_VECTOR_SLICE/basis-signature", fn () => true)
  (*>> mono-vector-slice *)
  (*<< mono-array-slice *)
  structure S57 : MONO_ARRAY_SLICE = Word8ArraySlice
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/basis-signature", fn () => true)
  (*>> mono-array-slice *)
  (*<< posix *)
  structure S100 : POSIX = Posix
  val () = T.check ("Posix:POSIX/basis-signature", fn () => true)
  (*>> posix *)
  (*<< posix-tty *)
  structure S101 : POSIX_TTY = Posix.TTY
  val () = T.check ("Posix.TTY:POSIX_TTY/basis-signature", fn () => true)
  (*>> posix-tty *)
end
