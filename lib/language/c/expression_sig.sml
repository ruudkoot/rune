(* Typed C integer expressions for target declaration consumers.

   Area: Languages *)
signature C_EXPRESSION =
sig
  (* A named object, enumerator or constant, before integer promotion. *)
  type binding = {ty : CParse.ctype, value : IntInf.int option}
  (* A source-located invalid or unsupported selected expression. *)
  exception Error of CLex.location * string
  (* `evaluate context` evaluates a target C integer constant expression.

     Casts, integer promotions, usual conversions, lazy conditional/logical
     operators, `sizeof` and `_Alignof` use explicit target facts. Both lazy
     branches are typechecked. Unevaluated operands do not perform arithmetic.
     Pointer-valued constants and other unsupported constructs fail explicitly.

     Raises: `Error` for invalid syntax, unresolved types or undefined arithmetic. *)
  val evaluate : {target : CInteger.target, sizeType : CInteger.integerType,
    tokens : CLex.token list, lookup : string -> binding option,
    resolveType : CLex.token list -> CParse.ctype option,
    integerType : CParse.ctype -> CInteger.integerType option,
    measure : CParse.ctype -> {size : IntInf.int, alignment : int}} -> CInteger.value
end
