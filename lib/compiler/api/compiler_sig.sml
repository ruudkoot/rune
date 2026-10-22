(* The reusable Rune compiler. Compilation and queries are static;
   execution is an explicit operation on a compiled unit. *)
signature RUNE_COMPILER =
sig
  (* An independent ordered compilation context. *)
  type session
  (* A unit's checked basis, bytecode, Mid and source snapshot. *)
  type compiled
  (* A diagnostic uses UTF-8 byte offsets in its source snapshot; line and
     column are one-based. *)
  type diagnostic = {severity : string, file : string, start : int, stop : int,
                     line : int, column : int, message : string}
  (* A compile or artifact operation failed with these diagnostics. *)
  exception Failed of diagnostic list
  (* An operation requires an open compiler context. *)
  exception Closed
  (* The compiler implementation version. *)
  val version : string
  (* `session {lib, flags}` constructs an independent ordered context.

     `NONE` selects the
     language's initial basis; `SOME root` selects the Basis and requested
     libraries under `root`. No absolute library path is built in.

     Supported flags are `--target=registers`, `--target=stack`,
     `--allow-prim`, `--unicode`, `--unicode=utf8`, `--unicode=latin1` and
     `--library NAME`. Unknown flags raise `Failed`. The defaults are
     register bytecode, ASCII source and no additional libraries. *)
  val session : {lib : string option, flags : string list} -> session
  (* `close session` releases its retained compilation history.

     Repeated
     calls do nothing. Operations requiring the context then raise `Closed`;
     immutable compiled artifacts can still be written to disk. *)
  val close : session -> unit
  (* `compileText (session, {file, text})` compiles text and appends a unit
     to the context's ordered history on success.

     It uses the context's source mode.
     Text is already decoded: Unicode text is UTF-8, also when source
     files are Latin-1. Failure leaves the preceding history unchanged.
     No user declarations, dynamic loads or compiler hooks are executed. *)
  val compileText : session * {file : string, text : string} -> compiled
  (* `compileFile (session, file)` reads a file in the configured source
     mode and compiles it as `compileText` does. *)
  val compileFile : session * string -> compiled
  (* `readUnit (session, file)` imports a unit and its checked basis/source
     companions.

     Its required units must already be available in the
     context. For older CLI artifacts without a source companion, matching
     original source must be available; mismatched source is rejected. *)
  val readUnit : session * string -> compiled
  (* `readMid (session, {basis, mid})` reads a checked basis and unit Mid,
     then generates the context's selected bytecode target. *)
  val readMid : session * {basis : string, mid : string} -> compiled
  (* `run unit` links and executes a unit with the runtime dependencies it
     needs.

     Unrelated units are not executed. Dependencies run once per
     context; calling `run` again executes this unit again. User exceptions
     propagate unchanged, and a failed initializer can be retried.

     Session execution uses separate unit namespaces, including for
     identical input units. Artifact output retains deterministic portable
     identities. Use this API to import units that depend on session units;
     raw runtime loading does not rewrite their dependency identities.

     RuneVM is required, and execution with libraries requires a host
     program built with `--units` so its Basis identities can be shared.
     A whole-program host raises `Fail` before linking any dependencies.
     Native SML hosts support static compilation and
     artifact output but raise `Fail` for execution. Host library units
     captured when the adapter starts are reused; normal build order must
     initialize those libraries before clients invoke the API. Their source
     provenance must match the configured library; differing or unavailable
     provenance raises `Fail` before dependencies execute. Explicit unit or
     Mid imports cannot replace a colliding host library implicitly.
     Replacing a shared host unit through raw runtime linking invalidates
     its provenance; later runs needing it raise `Fail` before execution. *)
  val run : compiled -> unit
  (* `writeUnit (unit, file)` writes a unit and its companion basis, Mid
     and source metadata (`.rbi`, `.rbm`, `.rbs`).

     Each file is replaced
     atomically; the source integrity record is published last. Readers
     reject a mismatched set. *)
  val writeUnit : compiled * string -> unit
  (* `writeMid (unit, file)` writes the unit's Mid representation. *)
  val writeMid : compiled * string -> unit
  (* `writeProgram (units, file)` links selected units, library finalizers
     and required dependencies into a program file.

     Units must belong to
     one context. It does not execute the program. *)
  val writeProgram : compiled list * string -> unit
  (* `typeAt (session, {file, offset})` returns the checked type of an
     annotated value occurrence, or `NONE` where none exists.

     The offset is a UTF-8 byte offset in the latest ordered history.
     The innermost occurrence is selected.
     This initial implementation performs fresh static elaboration; it
     does not retain a resident semantic snapshot or execute user code. *)
  val typeAt : session * {file : string, offset : int} -> string option

  (* The compiler's immutable project model, shared with the CLI. *)
  structure Project :
  sig
    (* A scoped plan and the inputs captured while discovering it. *)
    type t
    (* An ordered source occurrence; repeated paths retain their separate
       occurrences and annotations. mode is ascii, unicode or unicode=latin1. *)
    type source = {file : string, annotations : string list, mode : string, ordinal : int}
    (* A captured build or group-analysis input. revision hashes decoded
       text together with its source mode. *)
    type input = {file : string, text : string, mode : string, kind : string, revision : string}
    (* `read (session, request)` resolves a build through compiler rules,
       preserving scopes, order, annotations, virtual implementations and use.

       Variables are path-variable bindings. Overlays are already decoded
       UTF-8, also for Latin-1 source files. windows selects native Windows
       drive/UNC path handling. No user declarations execute and no cache
       files are written. Failure is reported through Failed. *)
    val read : session * {file : string, variables : (string * string) list,
                          overlays : {file : string, text : string} list, windows : bool} -> t
    (* `sources project` lists source occurrences in compiler order. *)
    val sources : t -> source list
    (* `inputs project` is the captured build and group-discovery text.
       Normal ordered sources need not be parsed to discover membership. *)
    val inputs : t -> input list
    (* `libraries project` lists library-header dependencies in source order. *)
    val libraries : t -> string list
    (* `cacheDirectories project` lists declared cache paths. Reading a
       project does not create or write these directories. *)
    val cacheDirectories : t -> string list
    (* `fingerprint project` identifies the captured plan, configuration
       and discovery inputs. It is not a persisted analysis snapshot. *)
    val fingerprint : t -> string
  end
end
