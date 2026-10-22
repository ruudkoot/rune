(* Messages cut out of a stream of bytes and put into one: a line each,
   or a header `Content-Length: N` and a blank line before N bytes, as the
   Language Server Protocol and the Debug Adapter Protocol frame theirs.

   A reader is a value, as `Key`'s decoder is: `feed` takes it and some
   bytes to the messages they complete and the reader that holds the rest,
   so a message may come in any number of reads.

   Area: Data formats *)
signature FRAMING =
sig
  (* How messages are framed: one to a line (a newline ends each, and a
     carriage return before it is dropped), or behind a `Content-Length`
     header. *)
  datatype framing = Lines | ContentLength

  (* What `feed` raises for a malformed header, a repeated length or an
     unsupported character encoding. *)
  exception Header of string

  (* What `feed` raises when a bounded reader's header or body is too
     large. The reader does not retain data beyond that limit. *)
  exception Limit of string

  (* A reader: the bytes of a message begun and not yet complete. *)
  type reader

  (* `reader f` is a reader of `f` that has read nothing. *)
  val reader : framing -> reader

  (* `bounded {framing, maxHeaderBytes, maxBodyBytes}` is a new reader
     with those byte limits.

     A header's limit includes its final blank line; a line-framed body's
     limit includes its optional carriage
     return but excludes the newline. Limits must be positive.

     Raises: `Domain` when either limit is not positive.

     Example: `not (pending (bounded {framing = ContentLength,
       maxHeaderBytes = 1024, maxBodyBytes = 4096}))` *)
  val bounded : {framing : framing, maxHeaderBytes : int, maxBodyBytes : int} -> reader

  (* `feed (r, s)` is the messages that `r`'s bytes and `s` complete, in
     order, and the reader that holds the rest. Empty lines are not
     messages.

     Raises: `Header` when a header cannot be read.

     Raises: `Limit` when the header or body exceeds its reader's bound.

     Example: `#1 (feed (reader Lines, "a\r\nb\nc")) = ["a", "b"]` *)
  val feed : reader * string -> string list * reader

  (* `pending r` is whether `r` holds part of a message. *)
  val pending : reader -> bool

  (* `frame (f, m)` is the message `m` framed: a newline after it, or the
     header before it.

     Example: `frame (ContentLength, "{}") = "Content-Length: 2\r\n\r\n{}"` *)
  val frame : framing * string -> string
end
