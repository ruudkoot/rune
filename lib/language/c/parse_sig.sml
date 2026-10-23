(* Target-neutral C declarations, retaining layout-affecting syntax.

   Area: Languages *)
signature C_PARSE =
sig
  (* Aggregate kind, kept distinct even when layouts happen to coincide. *)
  datatype recordKind = Struct | Union
  (* Syntax attributes retain original tokens: calling conventions,
     compiler attributes, qualifiers and alignment are not inferred away. *)
  type attribute = CLex.token list
  (* C types before target layout and FFI policy. Bounds, bit widths and
     enum values retain constant-expression tokens for target evaluation. *)
  datatype ctype =
      Builtin of string
    | Named of string
    | Pointer of {target : ctype, qualifiers : string list}
    | Array of {element : ctype, bound : CLex.token list}
    | Function of {result : ctype, parameters : parameter list,
                   variadic : bool, prototype : bool}
    | Record of {kind : recordKind, tag : string option, fields : field list option,
                 pack : int option}
    | Enum of {tag : string option, values : (string * CLex.token list) list option}
    | Attributed of ctype * attribute list
  (* A function parameter, including abstract declarators without a name. *)
  and parameter = Parameter of {name : string option, ctype : ctype}
  (* An aggregate member, including anonymous members and bitfields. *)
  and field = Field of {name : string option, ctype : ctype, bits : CLex.token list,
                        location : CLex.location}
  (* A declaration or definition; inline bodies remain balanced syntax,
     not a claim that the frontend implements C statement semantics. *)
  datatype declaration = Declaration of
    {name : string option, ctype : ctype, storage : string list,
     initializer : CLex.token list, body : CLex.token list,
     location : CLex.location}
    | StaticAssert of {condition : CLex.token list, message : CLex.token list,
                       location : CLex.location}
  (* A source-located syntactic error or unsupported extension. *)
  exception Error of CLex.location * string
  (* `translationUnit {tokens, predefinedTypes}` parses preprocessed input
     with typedef-sensitive declarators.

     It preserves pragmas and applies
     `pack` push/pop state to aggregate definitions. Unmatched packing and
     unterminated syntax fail explicitly.

     Raises: `Error` for malformed declarations or unsupported syntax. *)
  val translationUnit : {tokens : CLex.token list, predefinedTypes : string list} ->
                        {declarations : declaration list, pragmas : attribute list}
  (* `typeName {tokens, predefinedTypes}` parses one abstract C type name.

     It accepts array and function declarators without changing their shape.

     Raises: `Error` for named declarators, storage classes or trailing syntax. *)
  val typeName : {tokens : CLex.token list, predefinedTypes : string list} -> ctype
end
