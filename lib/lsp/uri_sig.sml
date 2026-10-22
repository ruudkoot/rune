(* Client document URIs and native filesystem paths.

   Area: Protocols *)
signature LSP_URI =
sig
  (* The filesystem convention used by the adapter, independent of the
     host running a codec test. *)
  datatype platform = Posix | Windows
  (* A validated URI retaining its original client spelling. *)
  type t
  (* Malformed URI syntax, an invalid native path, or a decoded NUL. *)
  exception Invalid

  (* `parse uri` reads an absolute URI, including unsaved and cell schemes.

     Percent escapes must be complete hexadecimal pairs. Raw UTF-8 is
     accepted for compatibility with clients sending Unicode URI text.
     Raw whitespace, controls and reserved non-URI punctuation are invalid.

     Raises: `Invalid` for malformed input. *)
  val parse : string -> t
  (* `original uri` preserves exactly what the client supplied.

     Example: `original (parse "file:///tmp/a%20b.sml") = "file:///tmp/a%20b.sml"` *)
  val original : t -> string
  (* `native (platform, uri)` maps a supported file URI to a path and key,
     or NONE for a virtual, remote or non-file view.

     POSIX paths preserve filename bytes. Windows paths support absolute
     drive and UNC forms and preserve lone UTF-16 surrogates through
     percent-encoded WTF-8. Malformed Windows byte sequences are rejected.
     Localhost is treated as local. File views with a query or fragment
     are retained as virtual documents.

     Keys remove single-dot arcs and normalize a Windows drive letter or
     UNC hostname. Path-component case and parent arcs are preserved; no
     symlinks are resolved. Client document identities remain distinct
     even when native keys coincide.

     Native byte strings need not be valid UTF-8: use a URI when sending
     them through JSON. Raises: `Invalid` for an unusable native path. *)
  val native : platform * t -> {path : string, key : string} option
  (* `fromPath (platform, path)` converts an absolute native path to a URI.

     Bytes outside the unreserved set are percent encoded; Windows
     separators become slashes. Original client URIs should be retained
     for existing documents instead of reconstructed with this function.

     Raises: `Invalid` for a relative path, NUL, or malformed Windows
     WTF-8. *)
  val fromPath : platform * string -> t
end
