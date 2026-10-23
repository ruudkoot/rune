(* Declaration-aware checks before safe binding generation.

   Area: Foreign interfaces *)
signature FOREIGN_VALIDATE =
sig
  (* A uniquely resolved function and its separate projection policy. *)
  type binding = {declaration : ForeignModel.declaration, policy : ForeignPolicy.functionPolicy}
  (* A source-located ambiguity, contradiction or unsupported selection. *)
  exception Error of ForeignModel.source * string
  (* `resolve {declarations, policy}` resolves selected C functions and
     validates names, pointer policy, extents, errors and callbacks.

     Raises: `Error` when selected declarations or annotations cannot
     produce the requested safe interface without guessing. *)
  val resolve : {declarations : ForeignModel.declaration list, policy : ForeignPolicy.policy} -> binding list
end
