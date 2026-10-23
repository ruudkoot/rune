(* Checked idiomatic wrappers over generated fixed native declarations.

   Area: Foreign interfaces *)
signature FOREIGN_PUBLIC =
sig
  (* The emitted public signature and sealed implementation source. *)
  type output = {signatureText : string, structureText : string}
  (* A source-located unsupported or contradictory public projection. *)
  exception Error of ForeignModel.source * string
  (* `emit {policy, profile, declarations}` generates complete selected wrappers.

     Explicit adapters are recorded by the outer generator and excluded from
     this automatic projection. Native ownership is established before a
     deferred callback exception can escape. Unsupported policies fail here. *)
  val emit : {policy : ForeignPolicy.policy, profile : ForeignTarget.profile,
    declarations : CParse.declaration list} -> output
end
