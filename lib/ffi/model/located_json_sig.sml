(* JSON values with physical positions for declarative policy diagnostics.

   Area: Foreign interfaces *)
signature FOREIGN_JSON =
sig
  (* Validated JSON and the physical positions of values and object keys. *)
  type document
  (* A source-located syntax or schema error. *)
  exception Error of ForeignModel.source * string
  (* `decode {file, text}` parses JSON and records physical positions.

     Raises: `Error` for malformed JSON. *)
  val decode : {file : string, text : string} -> document
  (* `value document` returns its parsed root. *)
  val value : document -> Json.value
  (* `location document path` finds a value by object keys/array indices. *)
  val location : document -> string list -> ForeignModel.source
  (* `error document path message` raises a source-located schema error. *)
  val error : document -> string list -> string -> 'a
  (* `object document path allowed value` validates keys and duplicates.

     Raises: `Error` for unknown/duplicate keys or a non-object value. *)
  val object : document -> string list -> string list -> Json.value -> (string * Json.value) list
  (* `member document path fields name` requires a named member.

     Raises: `Error` for a missing member. *)
  val member : document -> string list -> (string * Json.value) list -> string -> Json.value
  (* `optional fields name` looks up an optional member. *)
  val optional : (string * Json.value) list -> string -> Json.value option
  (* `string document path value` requires a JSON string. *)
  val string : document -> string list -> Json.value -> string
  (* `boolean document path value` requires a JSON Boolean. *)
  val boolean : document -> string list -> Json.value -> bool
  (* `array document path value` requires a JSON array. *)
  val array : document -> string list -> Json.value -> Json.value list
end
