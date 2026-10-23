(* Declarative FFI policy; reading a sidecar never executes its adapters.

   Area: Foreign interfaces *)
signature FOREIGN_POLICY =
sig
  (* Supported text encodings; raw buffers use bytes explicitly. *)
  datatype encoding = Bytes | Utf8 | Wtf8 | Utf16
  (* Parameter movement and copy-back direction. *)
  datatype direction = In | Out | InOut
  (* Ownership is separate from C pointer syntax. *)
  datatype ownership = Borrowed of string | Owned of string
  (* Buffer extents name a parameter or a fixed element count. *)
  datatype extent = ParameterLength of string | FixedLength of IntInf.int
  (* A structured SML type, never an executable SML source fragment. *)
  datatype smlType = Scalar of string | Resource of string | Option of smlType
    | Vector of smlType | Array of smlType | Tuple of smlType list
    | Record of (string * smlType) list
  (* Structured input/output grouping; leaves refer to foreign parameters
     or `$result`. It contains no SML expressions. *)
  datatype tree = Unit | Value of string | Product of tree list | Fields of (string * tree) list
  (* A parameter or returned-value annotation. Absence stays explicit until
     declaration-aware validation; the decoder guesses no ownership. *)
  type valuePolicy = {name : string option, direction : direction option,
    ownership : ownership option, nullable : bool option, encoding : encoding option, terminator : bool option,
    extent : extent option, callback : string option, projection : smlType option,
    output : string option, consumes : bool, source : ForeignModel.source}
  (* Native error predicates and capture mechanisms are independent. *)
  type errorPolicy = {predicate : string, capture : string, getter : string option}
  (* A selected function and its naming/marshalling policy.

     An optional shim is one fixed C prototype, parsed as declaration data;
     it supplies a macro ABI or an explicit variadic tail. *)
  type functionPolicy = {foreign : string, namespace : string, name : string, raw : string option,
    parameters : valuePolicy list, result : valuePolicy, errors : errorPolicy,
    variadic : string, unsafeRaw : bool, adapter : string option, shim : string option,
    input : tree option, returns : tree option,
    source : ForeignModel.source}
  (* A constant callback failure result, or a table keyed by one native
     argument, such as a Win32 message identifier. *)
  datatype failure = ConstantFailure of IntInf.int
    | ArgumentFailure of {parameter : string, cases : (string * IntInf.int) list,
                          otherwise : IntInf.int}
  (* Callback lifetime, thread and failure rules must be declared. *)
  type callbackPolicy = {foreign : string, lifetime : string, owner : string option,
    thread : string, failure : failure, source : ForeignModel.source}
  (* Sidecar contents; paths and library names are data. *)
  type policy = {version : int, family : string, structureName : string,
    headers : string list, libraries : string list, resources : string list, functions : functionPolicy list,
    callbacks : callbackPolicy list, source : ForeignModel.source}
  (* A source-located sidecar diagnostic. *)
  exception Error of ForeignModel.source * string
  (* `decode {file, text}` reads version one JSON policy, checking field
     names, duplicates, names, enums and structured projection types.

     Raises: `Error` for malformed or unsupported policy. *)
  val decode : {file : string, text : string} -> policy
  (* `rawName name` escapes foreign identifiers into legal SML value names.
     A projection consumer must check collisions across its complete API. *)
  val rawName : string -> string
end
