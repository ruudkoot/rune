(* Target byte representations independent of the SML host's widths.

   Area: Foreign interfaces *)
signature FOREIGN_BYTES =
sig
  (* Invalid widths, malformed byte counts or out-of-range values. *)
  exception Error of string
  (* `integer {width, signed, littleEndian, value}` encodes one C integer.

     Width is in bytes, from one through sixteen. Values are range checked;
     negative signed values use two's complement. *)
  val integer : {width : int, signed : bool, littleEndian : bool, value : IntInf.int} -> string
  (* `value {signed, littleEndian, bytes}` decodes a bounded integer object.

     Raises: `Error` unless the string contains one through sixteen bytes. *)
  val value : {signed : bool, littleEndian : bool, bytes : string} -> IntInf.int
  (* `real64 {littleEndian, value}` encodes an IEEE binary64 object.

     Raises: `Error` when the host's default SML real has another width. *)
  val real64 : {littleEndian : bool, value : real} -> string
  (* `real64Value {littleEndian, bytes}` decodes exactly eight bytes.

     Raises: `Error` for another byte count. *)
  val real64Value : {littleEndian : bool, bytes : string} -> real
  (* `real32 {littleEndian, value}` rounds binary64 to IEEE binary32 bytes.

     Rounding is to nearest, ties to even. Overflow produces signed infinity;
     NaNs use a canonical quiet payload. This is independent of the C process
     floating-point rounding mode. *)
  val real32 : {littleEndian : bool, value : real} -> string
  (* `real32Value {littleEndian, bytes}` widens an IEEE binary32 object exactly.

     Raises: `Error` unless exactly four bytes are supplied. *)
  val real32Value : {littleEndian : bool, bytes : string} -> real
end
