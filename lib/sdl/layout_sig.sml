(* Generated target facts used by SDL's SML projection.

   Area: Foreign interfaces *)
signature SDL_NATIVE_LAYOUT =
sig
  (* The selected native pointer width in bytes. *)
  val pointerBytes : int
  (* Whether native scalar objects store the least significant byte first. *)
  val littleEndian : bool
  (* Whether the target C ABI gives nonnegative enums a signed int type. *)
  val enumSigned : bool
  (* `sizeOf name` returns a selected original C object's byte size. *)
  val sizeOf : string -> int
  (* `offset (name, path)` returns a selected nested field's byte offset. *)
  val offset : string * string list -> int
  (* `constant name` returns a selected C integer constant, preserving its bits. *)
  val constant : string -> IntInf.int
end
