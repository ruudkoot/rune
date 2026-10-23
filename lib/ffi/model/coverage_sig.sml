(* Declaration coverage and implementation evidence stay separate.

   Area: Foreign interfaces *)
signature FOREIGN_COVERAGE =
sig
  (* Selection alone never claims generated or executable code. *)
  datatype state = Selected | Generated | Shimmed | Unselected | Unsupported of string
  (* A foreign identity, original source and current delivery state. *)
  type entry = {identity : ForeignModel.identity, source : ForeignModel.source, state : state}
  (* A source-located conflicting or stale coverage claim. *)
  exception Error of ForeignModel.source * string
  (* `report {declarations, selected, generated, shimmed, unsupported}`
     produces one canonical entry per identity.

     Implementation consumers supply generated/shimmed evidence only after producing those artifacts.

     Raises: `Error` for unknown identities or conflicting claims. *)
  val report : {declarations : ForeignModel.declaration list,
    selected : ForeignModel.identity list, generated : ForeignModel.identity list,
    shimmed : ForeignModel.identity list, unsupported : (ForeignModel.identity * string) list} -> entry list
  (* `json entries` serializes the report without discarding source mappings. *)
  val json : entry list -> Json.value
end
