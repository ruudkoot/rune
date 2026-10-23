(* Structured public interfaces assembled from native values and outputs.

   Area: Foreign interfaces *)
signature FOREIGN_PROJECTION =
sig
  (* A public argument/result tree. Leaves name foreign parameters;
     `$result` names the native result. No leaf is executable source. *)
  datatype tree = datatype ForeignPolicy.tree
  (* A source-located projection error. *)
  exception Error of ForeignModel.source * string
  (* `check {source, available, projection}` verifies that every leaf has
     a unique value binding and every record label is unique. *)
  val check : {source : ForeignModel.source, available : string list, projection : tree} -> unit
  (* `typeOf {source, values, projection}` builds the SML type of a checked
     projection from the separately established leaf types.

     Raises: `Error` for unknown leaves or duplicate fields. *)
  val typeOf : {source : ForeignModel.source, values : (string * ForeignPolicy.smlType) list,
                projection : tree} -> ForeignPolicy.smlType
  (* `callType {policy, inputs, result}` projects separately established
     native value types into a public argument/result pair.

     Annotations override leaf types; output parameters become returned values. *)
  val callType : {policy : ForeignPolicy.functionPolicy,
    inputs : (string * ForeignPolicy.smlType) list, result : ForeignPolicy.smlType} ->
    {input : ForeignPolicy.smlType, output : ForeignPolicy.smlType}
  (* `renderType ty` emits a type using fixed scalar spellings and checked
     resource names; it never copies arbitrary source text from policy. *)
  val renderType : ForeignPolicy.smlType -> string
end
