(* Bounded native buffers and scoped borrowed SML array copies.

   Area: Foreign interfaces *)
signature FOREIGN_MEMORY =
sig
  (* A checked native allocation, view or explicitly bounded pointer view. *)
  type buffer
  (* Input snapshots, copied outputs, or both. *)
  datatype direction = Input | Output | InputOutput
  (* One array range passed as a native pointer during a scoped call. *)
  type argument = {array : Word8Array.array, offset : int, length : int, direction : direction}
  (* A negative size or range beyond its known object extent. *)
  exception Bounds
  (* `allocate length` creates retained zeroed storage; its caller releases it.

     Native bridge failures propagate.

     Raises: `Bounds` for a negative size. *)
  val allocate : int -> buffer
  (* `fromBytes bytes` makes a retained native copy, released by its caller. *)
  val fromBytes : string -> buffer
  (* `release buffer` releases its registry identity after all views close.

     The native bridge rejects stale storage and live dependents. *)
  val release : buffer -> unit
  (* `length buffer` returns its annotated byte extent. *)
  val length : buffer -> int
  (* `raw buffer` returns its opaque pointer identity for raw native calls. *)
  val raw : buffer -> RuneForeign.resource
  (* `slice (buffer, offset, length)` creates a sharing view retaining its owner.

     Raises: `Bounds` for an invalid range. *)
  val slice : buffer * int * int -> buffer
  (* `pointer {pointer, length}` bounds an annotated native pointer.

     The caller establishes the foreign extent and ownership. Releasing this
     view never calls a native deallocator; it retains the pointer identity. *)
  val pointer : {pointer : RuneForeign.resource, length : int} -> buffer
  (* `read (buffer, offset, length)` copies a checked range to SML. *)
  val read : buffer * int * int -> string
  (* `write (buffer, offset, bytes)` updates storage visible through all views. *)
  val write : buffer * int * string -> unit
  (* `terminated {buffer, unitBytes}` reads through a native NUL code unit.

     Unit width is one or two bytes; the terminator must fit in the extent.
     Reads stop at the terminator, avoiding a copy beyond the foreign string.

     Raises: `Bounds` if no complete terminator is present. *)
  val terminated : {buffer : buffer, unitBytes : int} -> string
  (* `withBytes bytes body` scopes one copied native input buffer. *)
  val withBytes : string -> (buffer -> 'a) -> 'a
  (* `withArrays arguments body` supplies native views in argument order.

     Ranges of the same SML array share one backing allocation, preserving
     overlap and pointer aliasing. Inputs are snapshots; outputs copy back on
     every returning path. Output bytes supersede callback-side SML writes.
     Temporary views close first; outputs then copy back before allocations
     close. *)
  val withArrays : argument list -> (buffer list -> 'a) -> 'a
end
