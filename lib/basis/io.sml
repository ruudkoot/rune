(* IO: the exceptions and the buffering modes shared by the I/O structures:
   `Io`, which every operation of them raises, the four exceptions that are
   its causes, and `buffer_mode`.

   Implements: IO *)
structure IO =
struct
  exception Io of {name : string, function : string, cause : exn}
  exception BlockingNotSupported
  exception NonblockingNotSupported
  exception RandomAccessNotSupported
  exception ClosedStream
  datatype buffer_mode = NO_BUF | LINE_BUF | BLOCK_BUF
end
