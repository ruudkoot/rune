(* Explicit fixed prototypes for macro and variadic C adapters.

   Area: Foreign interfaces *)
signature FOREIGN_ADAPTER =
sig
  (* Declarations and policy ready for ordinary fixed-call validation. *)
  type prepared = {policy : ForeignPolicy.policy, declarations : CParse.declaration list}
  (* An invalid prototype or mismatch with the original declaration. *)
  exception Error of ForeignModel.source * string
  (* `prepare {policy, declarations, macros}` resolves explicit shim prototypes.

     Exactly one named, fixed function prototype is accepted. Macro origins
     remain in the caller's original model; function shims preserve original
     result and fixed-prefix C types. No C statements or commands are accepted. *)
  val prepare : {policy : ForeignPolicy.policy, declarations : CParse.declaration list,
    macros : CPreprocess.macro list} -> prepared
end
