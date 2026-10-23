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
  (* A callback's default or argument-dependent native failure result. *)
  datatype callbackFailure = Default of argument | ByArgument of
    {index : int, cases : (Word64.word * argument) list, default : argument}
  (* An integral destructor result's annotated failure condition. *)
  datatype failure = NoFailure | Zero | Nonzero | Negative
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
  (* `callback {abi, result, arguments, function, failure}` roots a closure.

     Entry is synchronous on the creating VM thread while a native call is
     active. Nested foreign calls are permitted; callbacks use a bounded
     interpreter delimiter even when their caller uses JIT or native code.
     Pointer arguments borrow identities valid for this callback only.
     The native caller must unregister the closure before `release`.
     An escaping SML exception returns the annotated failure value, then
     `invoke` or `dispose` raises it after native control returns safely.
     Foreign-thread entry returns the failure value without executing SML.

     Raises: `Error` for unavailable callbacks or invalid scalar policies. *)
  val callback : {abi : int, result : scalar, arguments : scalar list,
    function : argument list -> argument, failure : callbackFailure} -> resource
  (* `invoke (call, arguments)` executes one prepared call.

     Signed, unsigned and real results use eight little-endian bytes.
     Pointer results are opaque resources, with `NONE` for native null.
     Captured errors are interpreted by the calling library's policy.

     Raises: `Error` for unavailable support or invalid calls/arguments. *)
  val invoke : resource * argument list -> result
  (* `dispose {resource, call, arguments, failure}` runs a native destructor.

     The resource must be a native-owned pointer with no active uses or live
     dependents. Reentry cannot access or destroy it while destruction runs.
     Success retires its identity; a native failure preserves it for retry.
     The returned raw status and captured error survive either outcome.

     Raises: `Error` before native entry for invalid ownership or busy state. *)
  val dispose : {resource : resource, call : resource, arguments : argument list,
    failure : failure} -> {disposed : bool, result : result}
  (* `aliasHandle pointer` adopts a canonical opaque native handle identity.

     Native return values and callback-borrowed pointers can be adopted.
     Equal live native addresses share one identity. Handles retain their
     library and cannot be read, written or viewed as foreign storage.

     Raises: `Error` for stale pointers or aliases of Rune-owned memory. *)
  val aliasHandle : resource -> resource
  (* `consumeHandle {resource, call, arguments, failure}` destroys a handle.

     An active native caller may retain a handle while a nested callback
     destroys it. Nested native handle uses remain valid during destruction;
     recursive destruction fails. Native success retires all pointer aliases
     together, including uses suspended in outer calls. A native failure
     preserves ownership. Ordinary memory disposal retains its strict guards.

     Raises: `Error` for invalid ownership or recursive destruction. *)
  val consumeHandle : {resource : resource, call : resource, arguments : argument list,
    failure : failure} -> {disposed : bool, result : result}
  (* `sameAddress (left, right)` compares native pointer identities safely.

     This does not read storage. Allocations, views, symbols and returned
     pointers may be compared, including a pointer undergoing destruction.

     Raises: `Error` for stale or non-pointer resources. *)
  val sameAddress : resource * resource -> bool
  (* `isLive resource` checks its registry identity and refreshes its tombstone.

     A retired or previously released resource returns false. This never
     treats an old identity as a new allocation at the same native address. *)
  val isLive : resource -> bool
  (* `release resource` releases it after all dependents have been released.

     Its SML tombstone survives images; stale values cannot become live.

     Raises: `Error` for a second release, active use or live dependents. *)
  val release : resource -> unit
  (* `live ()` counts native resources owned by this VM. *)
  val live : unit -> Word64.word
end
