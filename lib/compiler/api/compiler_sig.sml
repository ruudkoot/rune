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
     `--library NAME`, `--no-inline-functors` (docs/build.md, Inline
     functors and functions), `--overloading=MODE` and `--free-tyvars=MODE`
     (docs/language.md, Overloading and Free type variables). Unknown flags
     and modes raise `Failed`. The defaults are register bytecode, ASCII
     source, no additional libraries, `--overloading=declaration` and
     `--free-tyvars=refuse`. *)
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

  (* Lossless editor syntax, separate from the compiler's batch parser. *)
  structure Syntax :
  sig
    (* An immutable syntax snapshot. No mutable compiler annotations escape. *)
    type t
    (* An immutable lexical fixity environment, transferable between files. *)
    type fixities
    (* Standard ML's initial fixities. *)
    val initial : fixities
    (* A lossless source piece. start/stop are half-open decoded byte offsets. *)
    type piece = {kind:string,start:int,stop:int,text:string}
    (* A structural syntax event. Constructor tags, spans, scalar fields and
       list lengths distinguish full syntax, including signature constraints. *)
    type event = {kind:string,start:int,stop:int,values:string list}
    (* Measured work counters for this parse/edit, not elapsed-time estimates. *)
    type work = {lexedBytes:int,reusedTokens:int,parsedDeclarations:int,reusedDeclarations:int}
    (* `parse request` parses decoded text with the selected mode and incoming
       fixities. orPatterns enables Rune's optional pattern extension.

       Malformed syntax is retained with diagnostics and bounded recovery.
       It does not execute or elaborate declarations. Unknown modes raise Failed. *)
    val parse : {file:string,text:string,mode:string,orPatterns:bool,fixity:fixities} -> t
    (* `edit (snapshot, change)` applies one byte-range replacement and updates
       syntax. Incoming fixities can change after an earlier file is edited.

       It reuses unchanged lexical suffixes and declarations only with matching
       token boundaries and incoming fixities. Invalid byte ranges raise Subscript. *)
    val edit : t * {start:int,stop:int,text:string,fixity:fixities} -> t
    (* `text snapshot` returns exactly its decoded source bytes. *)
    val text : t -> string
    (* `fixities snapshot` returns the environment exported to the next file. *)
    val fixities : t -> fixities
    (* `pieces snapshot` returns nonoverlapping pieces whose concatenation is
       the entire original text, including comments and malformed tokens. *)
    val pieces : t -> piece list
    (* `events snapshot` returns structural syntax events without annotation refs. *)
    val events : t -> event list
    (* `diagnostics snapshot` returns parse/lexical errors in its own source. *)
    val diagnostics : t -> diagnostic list
    (* `work snapshot` reports lexical and declaration reuse for this operation. *)
    val work : t -> work
  end

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
    (* A build parser path occurrence. kind is source, build, directory or
       library; the byte range includes any quotes and value excludes them. *)
    type buildReference={kind:string,value:string,start:int,stop:int,quoted:bool}
    (* A bounded filesystem/path-variable completion. Its replacement range
       and text include required build-language quoting. *)
    type pathCompletion={label:string,text:string,kind:string,start:int,stop:int}
    (* A build reference expanded through the compiler's actual path rules.
       target preserves read-path arcs; its existence is not inspected. *)
    type buildLink={kind:string,target:string,start:int,stop:int}
    (* `buildSyntax request` returns observed path roles and structured build
       diagnostics through the compiler's own lexer/parser.

       Recovery retains unfinished quoted paths and variables. No files are
       read and no project declarations execute. *)
    val buildSyntax : {file:string,text:string} -> {references:buildReference list,diagnostics:diagnostic list}
    (* `buildLinks (session, request)` expands complete build path tokens.

       Source/build/cache paths use the build directory and configured path
       variables. Libraries use the same directory resolver as the compiler.
       Unfinished quotes and unresolved variables are omitted. This query
       performs no filesystem reads or execution; offsets include quotes. *)
    val buildLinks : session * {file:string,text:string,variables:(string*string) list,windows:bool} -> buildLink list
    (* `pathCompletions (session, request)` lists matching paths or variables
       at a build cursor without building or executing the project.

       Byte ranges refer to captured text. Windows roots/UNC and configured
       path variables follow the compiler project rules. Directory scanning
       is bounded to 8192 entries and results to 512; isIncomplete reports
       truncation. Native filename bytes are preserved in returned strings. *)
    val pathCompletions : session * {file:string,text:string,offset:int,variables:(string*string) list,windows:bool} ->
      {items:pathCompletion list,isIncomplete:bool}
    (* `read (session, request)` resolves a build through compiler rules,
       preserving scopes, order, annotations, virtual implementations and use.

       Variables are path-variable bindings. Overlays are already decoded
       UTF-8, also for Latin-1 source files. windows selects Windows drive/UNC
       syntax independently of the host operating system. No user declarations execute and no cache
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

  (* Versioned static analysis with immutable query data and replay checkpoints. *)
  structure Analysis :
  sig
    (* An analysis context belonging to one compiler session. *)
    type t
    (* A frozen result. It remains readable after either context is closed. *)
    type snapshot
    (* A validated unit-cache checkpoint belonging to one analysis context. *)
    type checkpoint
    (* A bounded phase observation. items counts bytes at source phases and
       entries at projection phases; checked/reused count completed units. *)
    type observation={phase:string,file:string,checked:int,reused:int,items:int}
    (* An ordered decoded source occurrence.

       revision is the caller's source
       identity/version; an empty mode selects the compiler session's mode. *)
    type input={file:string,text:string,mode:string,annotations:string list,revision:string}
    (* A half-open source byte range, before LSP position conversion. *)
    type location={file:string,start:int,stop:int}
    (* An actual compiler-resolved binding occurrence.

       The range can cover
       its enclosing syntax, so editing clients must locate identifier tokens.
       derived marks a copied functor body rather than original source syntax. *)
    type occurrence={unit:string,file:string,start:int,stop:int,kind:string,name:string,path:string list,
      binding:string option,definition:location option,declaration:location option,isDefinition:bool,derived:bool}
    (* A frozen inferred type.

       constructors are semantic type identities;
       arguments contains curried domains, with tuple components grouped. *)
    type fact={unit:string,file:string,start:int,stop:int,ty:string,derived:bool,constructors:string list,arguments:string list list}
    (* A named type's source relationships.

       Abstract types retain their
       specification separately from the known implementation. *)
    type typeDefinition={id:string,definition:location option,declaration:location option,implementation:location option}
    (* A compiler-visible name and its frozen completion detail. *)
    type candidate={name:string,kind:string,detail:string option,arguments:string list list,definition:location option}
    (* A compiler-resolved application at the cursor. argument selects a
       curried domain; parameter selects a tuple component of that domain. *)
    type call={name:string,path:string list,detail:string,arguments:string list list,argument:int,parameter:int}
    (* An inferred variable-pattern type at the end of its actual name token.
       binding is an opaque lexical identity; location selects that token. *)
    type typeHint={name:string,position:int,ty:string,binding:string,location:location}
    (* Cancellation discarded an attempt before publishing its cache. *)
    exception Cancelled
    (* An operation re-entered or closed a context during an active check. *)
    exception Busy
    (* `create (compiler, {context})` creates an isolated analysis history.

       context identifies the caller's project/target. It does not append to
       the compiler's executable history or execute user code. *)
    val create : session * {context:string} -> t
    (* `close context` releases its retained caches; repeated calls do nothing. *)
    val close : t -> unit
    (* `observe (context, callback)` installs an optional synchronous phase
       observer between checks.

       NONE disables it. Observer exceptions abort
       the current attempt; observation never executes the checked program.
       Timing and host-specific memory counters belong to the callback. *)
    val observe : t * (observation->unit) option -> unit
    (* `check (context, request)` checks captured inputs in compiler order.

       A project must come from the same compiler session; inputs must match
       its ordered occurrences, modes, annotations and group-discovery text.
       Without a project the inputs form an ordered loose-file context.
       No files or artifacts are written, and user initializers never run.

       Valid unchanged prefixes replay checked bases. Changed units receive
       fresh annotation slots in a fresh compiler owner. A failed unit returns
       diagnostics and query data for its validated prefix; later units remain
       unavailable. Cancellation is polled between analysis phases and units;
       a supervisor must bound phases that cannot yet be interrupted. *)
    val check : t * {project:Project.t option,inputs:input list,cancelled:unit->bool} -> snapshot
    (* `checkpoint context` captures only committed, validated unit entries. *)
    val checkpoint : t -> checkpoint
    (* `restore (context, checkpoint)` restores a cache from that same context.
       The next check still validates its full configuration and inputs. *)
    val restore : t * checkpoint -> unit
    (* `id snapshot` is unique within this analysis context's lifetime. *)
    val id : snapshot -> string
    (* `context snapshot` returns the caller's project/target identity. *)
    val context : snapshot -> string
    (* `project snapshot` returns its captured project fingerprint, if any. *)
    val project : snapshot -> string option
    (* `inputs snapshot` returns the exact captured user source occurrences. *)
    val inputs : snapshot -> input list
    (* `unitAt (snapshot, position)` returns the opaque unit identity of a
       primary source occurrence by its zero-based ordinal.

       Compare it with occurrence/fact unit fields within this snapshot;
       do not interpret its spelling. An invalid ordinal returns NONE.
       It remains readable after closing the analysis context or session. *)
    val unitAt : snapshot * {ordinal:int} -> string option
    (* `syntaxAt (snapshot, position)` returns the captured syntax of an
       attempted primary source occurrence, using its actual incoming fixities.

       A failed parse retains its current text and recovery diagnostics. An
       invalid ordinal, or an input not reached after an earlier failure,
       returns NONE. The result is immutable and survives closing its owner. *)
    val syntaxAt : snapshot * {ordinal:int} -> Syntax.t option
    (* `dependencies snapshot` returns captured library source and identities. *)
    val dependencies : snapshot -> input list
    (* `diagnostics snapshot` returns source-addressed analysis diagnostics. *)
    val diagnostics : snapshot -> diagnostic list
    (* `occurrences snapshot` returns frozen lexical binding relationships. *)
    val occurrences : snapshot -> occurrence list
    (* `types snapshot` returns semantic constructor identities and sources. *)
    val types : snapshot -> typeDefinition list
    (* `facts snapshot` returns inferred types without mutable compiler refs. *)
    val facts : snapshot -> fact list
    (* `work snapshot` reports checked and replayed units, including libraries. *)
    val work : snapshot -> {checked:int,reused:int}
    (* `typeAt (snapshot, position)` returns its innermost original-source type.

       Copied-body facts are used only where no original fact is available.
       A file with several source occurrences requires typeAtOccurrence. *)
    val typeAt : snapshot * {file:string,offset:int} -> string option
    (* `typeAtOccurrence (snapshot, {ordinal, offset})` queries one ordered
       source occurrence, preserving its incoming build context. *)
    val typeAtOccurrence : snapshot * {ordinal:int,offset:int} -> string option
    (* `typeHints (snapshot, range)` returns checked, unannotated variable
       patterns whose hint positions lie between start and stop, inclusively.

       Offsets address one ordered source occurrence. Explicitly typed
       patterns, constructors and copied bodies are excluded. Invalid ordinals
       or reversed/negative ranges return no hints. No source is rechecked;
       the result remains readable after closing the context or session. *)
    val typeHints : snapshot * {ordinal:int,start:int,stop:int} -> typeHint list
    (* `visibleAt (snapshot, position)` returns actual lexical bindings at a
       source occurrence's byte offset, or members of path.

       It replays validated prefixes and rechecks the requested unit. Only
       frozen names/details escape; no mutable environment is published.
       Incomplete expressions can use bounded private syntax probes whose
       facts and diagnostics are never published as original-source data.
       The snapshot remains queryable after its context closes. *)
    val visibleAt : snapshot * {ordinal:int,offset:int,path:string list} -> candidate list
    (* `signatureAt (snapshot, position)` returns the enclosing named
       application's checked callable type and argument position.

       Application structure comes from compiler syntax, including derived
       infix applications. Incomplete expressions use the same private
       probes as visibleAt. Unavailable or non-callable names return NONE. *)
    val signatureAt : snapshot * {ordinal:int,offset:int} -> call option
    (* `completionAt (snapshot, position)` returns lexical candidates and
       the compiler syntax role at the cursor.

       role is expression, pattern, type, field, structure, signature, declaration
       or unknown. fields contains labels and types only where a checked
       record operand/pattern supplies a concrete record type. A consumer
       may filter namespaces without implementing a second parser. *)
    val completionAt : snapshot * {ordinal:int,offset:int,path:string list} ->
      {role:string,fields:(string*string) list,candidates:candidate list}
    (* `documentationAt (snapshot, location)` returns the leading source
       comment of the declaration owning that captured location.

       It uses captured source and syntax, including library dependencies;
       it does not reread disk files. The comment delimiters are removed. *)
    val documentationAt : snapshot * location -> string option
  end
end
