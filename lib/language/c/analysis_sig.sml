(* Typed declaration analysis over explicit target C facts.

   Area: Languages *)
signature C_ANALYSIS =
sig
  (* Compiler enum policy for the supported full-int ABI profiles. *)
  datatype enumRule = SignedEnums | UnsignedNonnegative
  (* All integer, object-layout and size-type facts for one target. *)
  type target = {integers : CInteger.target, objects : CLayout.target,
    charSigned : bool, sizeType : CInteger.integerType, enumRule : enumRule}
  (* Indexed original declarations and lazily evaluated constants. *)
  type environment
  (* An ambiguous, missing, cyclic or unsupported selected declaration. *)
  exception Error of CLex.location * string
  (* `create {target, declarations}` indexes a translation unit.

     Private unresolved declarations do not force evaluation. Duplicate
     incompatible definitions are diagnosed only when selected. *)
  val create : {target : target, declarations : CParse.declaration list} -> environment
  (* `lookup environment {namespace, name}` resolves an alias or tag.

     Namespaces are typedef, struct, union and enum. Definitions take
     precedence over incomplete declarations; ambiguous definitions fail. *)
  val lookup : environment -> {namespace : string, name : string} -> CParse.ctype option
  (* `resolve environment ty` removes outer aliases and qualifiers.

     Pointer targets and aggregate fields remain separate type references. *)
  val resolve : environment -> CParse.ctype -> CParse.ctype
  (* `integer environment ty` classifies a resolved standard integer type.

     Extended enum representations require an explicit native adapter. *)
  val integer : environment -> CParse.ctype -> CInteger.integerType option
  (* `expression environment tokens` evaluates a typed integer expression.

     Typedef casts, enumerators, object types and measurements use this
     target's declarations, never the SML host's C widths. *)
  val expression : environment -> CLex.token list -> CInteger.value
  (* `enumerator environment name` evaluates a declaration-order enum value.

     Forward references and values outside the standard int range fail. *)
  val enumerator : environment -> string -> CInteger.value
  (* `layout environment {ty, source}` computes a selected object's layout.

     Raises: `Error`, or `CLayout.Shim` for a representation needing an adapter. *)
  val layout : environment -> {ty : CParse.ctype, source : CLex.location} -> CLayout.layout
end
