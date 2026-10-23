(* LSP positions over immutable UTF-8 document text.

   Area: Protocols *)
signature LSP_POSITION =
sig
  (* Text with a line index and sparse Unicode checkpoints. *)
  type t
  (* Malformed UTF-8 or an invalid byte edit boundary. *)
  exception Invalid
  (* A requested line-count bound would be exceeded. *)
  exception Limit

  (* `make text` indexes well-formed UTF-8, preserving its BOM and exact
     line endings. Empty text has one line.

     Raises: `Invalid` for malformed UTF-8, and `Size` for an index larger
     than the host's vectors permit. *)
  val make : string -> t
  (* `bounded {text, maxLines}` indexes text with a line-count limit.

     Raises: `Limit` before indexing more than maxLines lines; `Domain`
     when maxLines is not positive; `Invalid` as make does. *)
  val bounded : {text : string, maxLines : int} -> t
  (* `text index` is the original UTF-8 text. *)
  val text : t -> string
  (* `lineCount index` counts LF, CRLF and CR as line endings. A trailing
     line ending starts a final empty line.

     Example: `lineCount (make "a\r\nb\rc\n") = 4` *)
  val lineCount : t -> int
  (* `offset (index, encoding, position)` converts a negotiated position
     to a byte offset, or NONE for invalid coordinates or split scalars.

     A character beyond its line clamps to that line's end. A line beyond
     the document clamps to EOF. Negative or out-of-protocol coordinates
     are invalid. UTF-16 positions inside a surrogate pair and UTF-8
     positions inside a multibyte character are rejected. *)
  val offset : t * LspProtocol.encoding * LspProtocol.position -> int option
  (* `position (index, encoding, offset)` converts a byte offset, or is
     NONE for an out-of-bounds offset or one inside a multibyte character.

     Offsets in line-ending bytes clamp to the line's end: LSP cannot
     address the middle of CRLF. The BOM is a character when present. *)
  val position : t * LspProtocol.encoding * int -> LspProtocol.position option
  (* `edit (index, start, stop, text)` replaces a half-open byte range.

     Unchanged Unicode checkpoints are reused. Line-ending changes
     reconstruct the affected line region. The original index remains
     valid for callers holding its document snapshot.

     Raises: `Invalid` for malformed inserted UTF-8, reversed/out-of-bounds
     ranges or split scalar boundaries. *)
  val edit : t * int * int * string -> t
  (* `editBounded edit` applies a byte edit with a maximum output line
     count, preserving the input index when the edit fails.

     Raises: `Limit` when the output exceeds maxLines, `Domain` for a
     nonpositive limit, and `Invalid` as edit does. *)
  val editBounded : {document : t, start : int, stop : int, text : string,
                     maxLines : int} -> t
end
