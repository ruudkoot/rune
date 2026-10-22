(* LSP 3.18 wire values, integer bounds and capability negotiation.

   Area: Protocols *)
signature LSP_PROTOCOL =
sig
  (* An LSP integer, represented without dependence on the host's width. *)
  type integer = IntInf.int

  (* Zero-based line and character coordinates in the negotiated encoding. *)
  type position = {line : integer, character : integer}

  (* A half-open range, whose end is not before its start. *)
  type range = {start : position, stop : position}

  (* The position encodings supported by the protocol adapter. *)
  datatype encoding = Utf8 | Utf16 | Utf32

  (* Validated capabilities and their selected position encoding. *)
  type capabilities

  (* A decoded message, or an error with its recoverable id.

     Malformed responses and recognizable notifications have reply false,
     preventing response loops and replies to notifications. *)
  datatype decoded = Message of JsonRpc.message
                   | Invalid of {error : JsonRpc.error, id : JsonRpc.id option, reply : bool}

  (* The supported protocol version.

     Example: `version = "3.18.0"` *)
  val version : string

  (* The smallest signed LSP integer. *)
  val minInteger : integer

  (* The largest signed or unsigned LSP integer. *)
  val maxInteger : integer

  (* `integer v` is the signed 32-bit integer represented by v. *)
  val integer : Json.value -> integer option

  (* `uinteger v` is the nonnegative LSP integer represented by v.

     Example: `uinteger (Json.int ~1) = NONE` *)
  val uinteger : Json.value -> integer option

  (* `integerToJson n` is n as a signed LSP JSON integer.

     Raises: `Domain` when n is outside the signed 32-bit range. *)
  val integerToJson : integer -> Json.value

  (* `idFromJson v` reads a string id or signed LSP integer id. *)
  val idFromJson : Json.value -> JsonRpc.id option

  (* `idToJson id` writes an id or progress token.

     Raises: `Domain` for an out-of-range number or ill-formed UTF-8. *)
  val idToJson : JsonRpc.id -> Json.value

  (* `positionFromJson v` reads a position with nonnegative coordinates. *)
  val positionFromJson : Json.value -> position option

  (* `positionToJson p` writes a position.

     Raises: `Domain` when a coordinate is not an LSP unsigned integer. *)
  val positionToJson : position -> Json.value

  (* `rangeFromJson v` reads a well-ordered half-open range. *)
  val rangeFromJson : Json.value -> range option

  (* `rangeToJson r` writes a range, using the wire member end for stop.

     Raises: `Domain` when the range is reversed or a coordinate invalid. *)
  val rangeToJson : range -> Json.value

  (* `decode text` reads one JSON-RPC message under LSP's rules.

     Batches, ambiguous envelope members and out-of-range ids/codes are
     invalid. Unknown extension members remain permitted. *)
  val decode : string -> decoded

  (* `encode message` writes one LSP message, without transport framing.

     Raises: `Domain` for invalid integer ranges, params or UTF-8 text. *)
  val encode : JsonRpc.message -> string

  (* `capabilities v` validates the capability object and encoding list. *)
  val capabilities : Json.value -> capabilities option

  (* `supports (caps, path)` is whether that capability is true. *)
  val supports : capabilities * string list -> bool

  (* `positionEncoding caps` is the selected encoding: UTF-8 when offered,
     then UTF-16 or UTF-32, with UTF-16 as the mandatory fallback. *)
  val positionEncoding : capabilities -> encoding

  (* `encodingName encoding` is its protocol spelling.

     Example: `encodingName Utf16 = "utf-16"` *)
  val encodingName : encoding -> string

  (* `rawCapabilities caps` is the original capability object. *)
  val rawCapabilities : capabilities -> Json.value

  (* The error code for a request before initialization. *)
  val serverNotInitialized : integer

  (* The error code for a result invalidated by a changed context. *)
  val contentModified : integer

  (* The error code for server cancellation where the method permits it. *)
  val serverCancelled : integer

  (* The error code for a request that could not be completed. *)
  val requestFailed : integer
end
