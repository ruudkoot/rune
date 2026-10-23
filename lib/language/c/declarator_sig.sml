(* C declarator output for verified native adapters.

   Area: Languages *)
signature C_DECLARATOR =
sig
  (* A type needing an original named alias or an unsupported declarator. *)
  exception Error of string
  (* `identifier name` validates a C identifier without emitting source text.

     Raises: `Error` for punctuation or an invalid initial character. *)
  val identifier : string -> unit
  (* `declaration (ty, name)` emits a named object/function declaration.

     Named aggregates refer to their original tags. Anonymous aggregates
     require a supplied typedef. Attributes and qualifiers retain their
     parsed spelling; original headers remain the authority on definitions.

     Raises: `Error` for a type that cannot be referenced safely. *)
  val declaration : CParse.ctype * string -> string
end
