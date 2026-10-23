(* Deterministic source generation from checked C declarations and policy.

   Area: Foreign interfaces *)
signature FOREIGN_GENERATE =
sig
  (* An ordinary generated text artifact, relative to its immutable output set. *)
  type artifact = {path : string, text : string}
  (* An explicit native field adapter selection. *)
  type field = {aggregate : string, path : string list, writable : bool}
  (* Source-located unsupported generation requests. *)
  exception Error of ForeignModel.source * string
  (* `emit {policy, profile, declarations, macros, layouts, fields, constants, sourceName}` produces sources.

     Fixed raw calls always retain native statuses. Checked public projections
     are emitted where their complete policy can be implemented. Retained
     original macros resolve explicitly typed native shim prototypes. An explicit
     adapter selection remains visible in the manifest rather than claiming
     an implemented public projection. Target layouts come from the reusable
     C analysis library; no compiler or native library is executed. *)
  val emit : {policy : ForeignPolicy.policy, profile : ForeignTarget.profile,
    declarations : CParse.declaration list, macros : CPreprocess.macro list, layouts : string list,
    fields : field list, constants : (string * IntInf.int) list,
    sourceName : string -> string} -> artifact list
end
