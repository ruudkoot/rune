(* IO: exceptions shared by TextIO and BinIO. *)
structure IO =
struct
  exception Io of {name : string, function : string, cause : exn}
  exception ClosedStream
end
