(* Foreign declarations, independent of target layout and SML projection.

   Area: Foreign interfaces *)
signature FOREIGN_MODEL =
sig
  (* An original description's physical source position. *)
  type source = {file : string, line : int, column : int}
  (* A stable source identity, including the foreign namespace. *)
  type identity = {family : string, namespace : string, name : string}
  (* An expression in its source language, before target evaluation. *)
  type expression = {family : string, text : string, source : source}
  (* Foreign types. Backend-specific types stay explicit and cannot silently
     become machine pointers or libffi scalars. *)
  datatype foreignType =
      Scalar of {family : string, name : string}
    | Named of identity
    | Pointer of {target : foreignType, qualifiers : string list}
    | Array of {element : foreignType, bound : expression option}
    | Callable of {result : foreignType, parameters : parameter list,
                   variadic : bool, prototype : bool}
    | Aggregate of {kind : string, tag : identity option, fields : field list option,
                    packing : int option}
    | Enumeration of {tag : identity option, values : (string * expression option) list option}
    | Attributed of foreignType * expression list
    | Macro of {parameters : string list option, variadic : bool, body : expression}
    | BackendType of {family : string, description : string}
  (* A foreign parameter before naming, ownership or output projection. *)
  and parameter = Parameter of {name : string option, ty : foreignType}
  (* A foreign aggregate member; bit widths remain source expressions. *)
  and field = Field of {name : string option, ty : foreignType,
                        bits : expression option, source : source}
  (* A declaration with source identity and linkage, separate from policy. *)
  type declaration = {identity : identity, ty : foreignType,
                      storage : string list, source : source}
  (* Target scalar facts, separate from SML host arithmetic. *)
  type scalarLayout = {size : int, alignment : int, signed : bool option}
  (* Target byte order. *)
  datatype byteOrder = Little | Big
  (* Target facts do not add ownership or projection to declarations. *)
  type target = {name : string, abi : string, byteOrder : byteOrder,
                 scalars : (string * scalarLayout) list}
  (* A checked native layout produced by the layout consumer. *)
  type layout = {size : IntInf.int, alignment : int,
                 fields : (string * IntInf.int) list}
  (* Backends state which source families and mechanisms they implement. *)
  type capabilities = {backend : string, families : string list,
                       mechanisms : string list, callbacks : string list,
                       unsupported : string list}
  (* A source-located model diagnostic. *)
  exception Error of source * string
  (* `key identity` encodes a source identity without delimiter collisions. *)
  val key : identity -> string
  (* `fromC declarations` adapts parsed C declarations without applying
     ownership, target widths or SML naming policy.

     Unresolved redeclarations remain available for a selected consumer's
     diagnostic; private declarations do not block unrelated selections. *)
  val fromC : CParse.declaration list -> declaration list
  (* `fromCMacros macros` preserves macro source, parameters and body.
     Macro identities occupy their own namespace; they are not functions. *)
  val fromCMacros : CPreprocess.macro list -> declaration list
  (* `canonical declarations` sorts identities and physical source positions.
     Input traversal order cannot affect reports or selected closures. *)
  val canonical : declaration list -> declaration list
  (* `reachable (declarations, selected)` resolves the transitive declaration
     closure, including aliases, while retaining opaque aggregate pointers.

     Raises: `Error` for missing or ambiguous selected identities. *)
  val reachable : declaration list * identity list -> declaration list
  (* An immutable lookup index over one declaration collection. *)
  type environment
  (* `index declarations` prepares repeated identity lookups without
     changing declaration/source information. *)
  val index : declaration list -> environment
  (* `lookup (environment, identity)` resolves one indexed identity.

     Raises: `Error` for an ambiguous identity. *)
  val lookup : environment * identity -> declaration option
  (* `find (declarations, identity)` resolves an exact foreign identity.

     Raises: `Error` when that identity has incompatible redeclarations. *)
  val find : declaration list * identity -> declaration option
  (* `libffi` describes the dynamic C backend contract. Runtime availability
     is checked separately; other families need explicit future backends. *)
  val libffi : capabilities
end
