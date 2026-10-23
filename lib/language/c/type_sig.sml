(* Shared C type spelling and abstract type-name analysis.

   Area: Languages *)
signature C_TYPE =
sig
  (* `canonical spelling` normalizes equivalent builtin C spellings.

     Invalid or unsupported spellings remain visible rather than becoming
     an unrelated scalar type. Microsoft fixed-width spellings are included. *)
  val canonical : string -> string
  (* `parse {tokens, typedefs}` recognizes an abstract C type name.

     Original token positions survive; expression parentheses return `NONE`.
     Typedef names must be supplied explicitly by the declaration consumer. *)
  val parse : {tokens : CLex.token list, typedefs : string list} -> CParse.ctype option
  (* `integer {target, charSigned, ty}` resolves an unaliased integer type.

     Qualifiers are transparent; aliases remain the caller's responsibility. *)
  val integer : {target : CInteger.target, charSigned : bool, ty : CParse.ctype} ->
    CInteger.integerType option
  (* `spelling ty` returns a canonical builtin name for an integer type. *)
  val spelling : CInteger.integerType -> string
end
