(* Integer constant expressions for C preprocessing and declarations.

   Area: Languages *)
signature C_CONST =
sig
  (* An intmax/uintmax value for the selected expression width. *)
  type value = {integer : IntInf.int, unsigned : bool}
  (* A source-located malformed or undefined constant expression. *)
  exception Error of CLex.location * string
  (* `literal {width, token}` decodes a C integer or single-character
     literal. The width is in bits and independent of the SML host.

     Raises: `Error` for unsupported, malformed or out-of-range literals. *)
  val literal : {width : int, token : CLex.token} -> value
  (* `evaluate {width, lookup, tokens}` evaluates an integer expression,
     including lazy logical/conditional operators.

     Unknown identifiers use
     `lookup`; the preprocessor supplies signed zero for unknown names.

     Raises: `Error` for invalid syntax, division by zero, invalid shifts,
     signed overflow or an unresolved identifier. *)
  val evaluate : {width : int, lookup : string -> value option,
                  tokens : CLex.token list} -> value
end
