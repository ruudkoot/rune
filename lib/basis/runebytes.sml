(* The VM's array of bytes, which Word8Array and CharArray are: a byte an
   element, laid out as a string's bytes are and as C has an array of them
   (docs/runtime.md). It can be written, and its equality is its identity. *)
structure RuneBytes =
struct
  type bytes = _prim "bytearray"
  val new = _prim "bytes_new" : int * int -> bytes
  val length = _prim "bytes_length" : bytes -> int
  val sub = _prim "bytes_sub" : bytes * int -> char
  val update = _prim "bytes_update" : bytes * int * char -> unit
  val blit = _prim "bytes_blit" : bytes * int * bytes * int * int -> unit
  val blitString = _prim "bytes_blit_string" : string * int * bytes * int * int -> unit
  val extract = _prim "bytes_extract" : bytes * int * int -> string
end
