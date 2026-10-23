(* Typed C adapters for declarations outside the dynamic scalar ABI.

   Area: Foreign interfaces *)
signature FOREIGN_SHIM =
sig
  (* Invalid adapter names, a missing prototype or unsupported type syntax. *)
  exception Error of string
  (* `preamble headers` includes original headers and defines adapter exports.

     Header paths are validated; this emits source without running commands. *)
  val preamble : string list -> string
  (* `call {name, foreign, result, parameters, indirectResult, indirectArguments}`
     emits one typed C wrapper over an original function, inline or macro.

     Indirect values cross libffi through pointers, with target C performing
     aggregate copies. The original header supplies calling conventions.
     A macro's explicit C result/parameter types are annotation policy.

     Raises: `Error` for a mismatched argument list or unsafe source name. *)
  val call : {name : string, foreign : string, result : CParse.ctype,
    parameters : CParse.ctype list, indirectResult : bool,
    indirectArguments : bool list} -> string
  (* `field {name, aggregate, path, ty, writable}` emits member accessors.

     Native C handles bitfields and compiler-specific packing. A writable
     accessor uses normal C assignment conversion, exposed through raw access.
     Public policy performs any stronger bit-width/range validation. *)
  val field : {name : string, aggregate : CParse.ctype, path : string list,
    ty : CParse.ctype, writable : bool} -> string
end
