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
end
