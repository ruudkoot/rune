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

  (* What `feed` raises for a header it cannot read: a header without
     `Content-Length`, or one whose length is no number. *)
  exception Header of string

  (* A reader: the bytes of a message begun and not yet complete. *)
  type reader

  (* `reader f` is a reader of `f` that has read nothing. *)
  val reader : framing -> reader

  (* `feed (r, s)` is the messages that `r`'s bytes and `s` complete, in
     order, and the reader that holds the rest. Empty lines are not
     messages.

     Raises: `Header` when a header cannot be read.

     Example: `#1 (feed (reader Lines, "a\r\nb\nc")) = ["a", "b"]` *)
  val feed : reader * string -> string list * reader

  (* `pending r` is whether `r` holds part of a message. *)
  val pending : reader -> bool

  (* `frame (f, m)` is the message `m` framed: a newline after it, or the
     header before it.

     Example: `frame (ContentLength, "{}") = "Content-Length: 2\r\n\r\n{}"` *)
  val frame : framing * string -> string
end
