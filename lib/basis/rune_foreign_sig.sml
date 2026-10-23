(* The trusted generic bridge used by ordinary foreign-support libraries.
   Native addresses stay outside the SML heap; resource handles are opaque.

   Area: The runtime

   Status: extension *)
signature RUNE_FOREIGN =
sig
  (* A process-local library, symbol, allocation, view or prepared call. *)
  eqtype resource
  (* Fixed scalar ABI types. Target C aliases are resolved above this layer. *)
  datatype scalar = Void | SInt8 | UInt8 | SInt16 | UInt16 | SInt32 | UInt32
    | SInt64 | UInt64 | Float32 | Float64 | Pointer
  (* Checked scalar arguments; addresses use resource identities. *)
  datatype argument = Signed of Int64.int | Unsigned of Word64.word
    | Real of real | Address of resource option
  (* Captured immediately after native execution, before cleanup. *)
  type error = {number : int, native : Word32.word, message : string}
  (* A successful native invocation's raw result and captured error. *)
  type result = {bytes : string, pointer : resource option, error : error}
  (* A bridge, availability, lifetime, bounds or native loader failure. *)
  exception Error of error
  (* `available ()` reports whether this runtime has libffi support. *)
  val available : unit -> bool
  (* `target ()` reports C pointer bytes, byte order and x86 Windows stdcall.

     These are native ABI facts; SML's word size is independent of them.
     Target facts remain available when dynamic calls are disabled. *)
  val target : unit -> {pointerBytes : int, littleEndian : bool, stdcall : bool}
  (* `openLibrary name` opens a native library lazily requested by a caller.

     Raises: `Error` for unavailable support or a loader failure. *)
  val openLibrary : string -> resource
  (* `symbol (library, name)` resolves one symbol and retains its library.

     Raises: `Error` for missing symbols or invalid resources. *)
  val symbol : resource * string -> resource
  (* `allocate length` makes zeroed foreign-owned storage of that byte size.

     Raises: `Error` for unavailable support or allocation failure. *)
  val allocate : Word64.word -> resource
  (* `read (memory, offset, length)` copies bytes into an immutable string.

     Allocations and views have checked bounds. A pointer returned by native
     code inherits known allocation bounds when possible; other returned
     pointers require the calling library to establish the readable extent.

     Raises: `Error` for stale resources or out-of-bounds runs. *)
  val read : resource * Word64.word * int -> string
  (* `write (memory, offset, bytes)` copies bytes into foreign storage.

     Raises: `Error` for stale resources or out-of-bounds runs. *)
  val write : resource * Word64.word * string -> unit
  (* `view (memory, offset, length)` shares a checked foreign-memory range.

     Raises: `Error` for invalid runs. The parent remains retained. *)
  val view : resource * Word64.word * Word64.word -> resource
  (* `prepare {symbol, abi, result, arguments}` prepares a fixed call.

     ABI 0 is the target default; ABI 1 is Windows x86 stdcall.

     Raises: `Error` for unsupported interfaces or invalid resources. *)
  val prepare : {symbol : resource, abi : int, result : scalar, arguments : scalar list} -> resource
  (* `invoke (call, arguments)` executes one prepared call.

     Signed, unsigned and real results use eight little-endian bytes.
     Pointer results are opaque resources, with `NONE` for native null.
     Captured errors are interpreted by the calling library's policy.

     Raises: `Error` for unavailable support or invalid calls/arguments. *)
  val invoke : resource * argument list -> result
  (* `release resource` releases it after all dependents have been released.

     Its SML tombstone survives images; stale values cannot become live.

     Raises: `Error` for a second release, active use or live dependents. *)
  val release : resource -> unit
  (* `live ()` counts native resources owned by this VM. *)
  val live : unit -> Word64.word
end
