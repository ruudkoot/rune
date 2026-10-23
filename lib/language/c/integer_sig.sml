(* Target integer types and the usual C arithmetic conversions.

   Area: Languages *)
signature C_INTEGER =
sig
  (* Integer rank, independent of the generator host's widths. *)
  datatype rank = Char | Short | Int | Long | LongLong
  (* One target C integer type. *)
  type integerType = {rank : rank, width : int, signed : bool}
  (* An integer constant and its C type. *)
  type value = {integer : IntInf.int, ty : integerType}
  (* Standard target integer widths, in bits. *)
  type target = {char : int, short : int, int : int, long : int, longLong : int}
  (* A source-located invalid conversion or undefined arithmetic result. *)
  exception Error of CLex.location * string
  (* `integerType target rank signed` resolves an explicit target type. *)
  val integerType : target -> rank -> bool -> integerType
  (* `limits ty` returns the inclusive range of a target integer type. *)
  val limits : integerType -> IntInf.int * IntInf.int
  (* `literal target token` selects the C type from base, suffix and range.

     Raises: `Error` when no supported target integer type holds the value. *)
  val literal : target -> CLex.token -> value
  (* `convert ty value` applies the target's two's-complement conversion. *)
  val convert : integerType -> value -> value
  (* `promote target value` applies C integer promotion. *)
  val promote : target -> value -> value
  (* `common target (left, right)` computes the usual arithmetic type. *)
  val common : target -> integerType * integerType -> integerType
  (* `unary target token value` applies a checked promoted unary operator.

     Raises: `Error` for signed negation overflow or an unknown operator. *)
  val unary : target -> CLex.token -> value -> value
  (* `binary target token (left, right)` evaluates a checked binary operator.

     Raises: `Error` for undefined shifts, division or signed overflow. *)
  val binary : target -> CLex.token -> value * value -> value
end
