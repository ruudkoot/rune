(* What the whole of the I/O stack shares: the exception it raises and the
   ways a stream may hold output back.

   Every operation of `PRIM_IO`, `STREAM_IO`, `IMPERATIVE_IO`, `TEXT_IO` and
   `BIN_IO` reports failure as `Io`, whatever the reason: a file that cannot
   be opened, a reader that fails, an operation on a stream that is closed.
   The `cause` says which. What a reader or a writer raises is caught and
   becomes the cause, so a program has one exception to handle and can still
   see what happened underneath; a failure of the system arrives that way as
   `OS.SysErr`.

   The other four exceptions are the causes that the layers raise themselves.
   A reader or a writer need not offer every operation, and when a stream
   wants one that is missing it raises `Io` with the matching cause:
   `BlockingNotSupported` for a read or a write that would have to wait,
   `NonblockingNotSupported` for one that must not wait,
   `RandomAccessNotSupported` for a position.

   Area: Input and output

   See also: `PRIM_IO`, `STREAM_IO`, `TEXT_IO`, `BIN_IO`, `OS_IO` *)
signature IO =
sig
  (* The exception of every I/O operation, which says where it happened and why.

     `name` names the stream, the file or the reader the operation was on;
     `function` is the operation that raised; `cause` is the exception behind
     it.

     Reading: `IO.Io/function-is-unqualified`. "The name of the function
     raising the exception" is taken unqualified: `"openIn"`, not
     `"TextIO.openIn"`, as MLton and SML/NJ take it. Poly/ML writes the
     qualified name.

     Pinned by: `*IO.open*/Io-function` *)
  exception Io of {name : string, function : string, cause : exn}

  (* The cause of an `Io` when an operation would have to wait and nothing can make it wait.

     A reader with neither a blocking read nor `block` cannot serve `input`;
     a writer with neither a blocking write nor `block` cannot serve
     `output`. *)
  exception BlockingNotSupported

  (* The cause of an `Io` when an operation must not wait and nothing can promise that.

     The reader or the writer has no non-blocking operation, and no
     `canInput` or `canOutput` to tell whether the blocking one would
     wait. *)
  exception NonblockingNotSupported

  (* The cause of an `Io` when a position is asked of a stream whose reader or writer has none.

     `STREAM_IO.filePosIn`, `getPosOut` and `setPosOut` raise it. A regular
     file has positions; a pipe, a socket and a terminal have none. *)
  exception RandomAccessNotSupported

  (* The cause of an `Io` when the stream, the reader or the writer is closed or has been given away.

     A stream is also unusable once `getReader` or `getWriter` has handed the
     reader or the writer over; such a stream is called truncated or
     terminated. *)
  exception ClosedStream

  (* How much a stream holds back before it passes what is written to its writer. *)
  datatype buffer_mode
    = NO_BUF      (* nothing: every output reaches the writer at once *)
    | LINE_BUF    (* a line: what is held goes out when a newline is written *)
    | BLOCK_BUF   (* a block: what is held goes out at the writer's chunkSize *)
end
