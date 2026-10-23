(* Explicit target ABI profiles for foreign layout and marshalling.

   Area: Foreign interfaces *)
signature FOREIGN_TARGET =
sig
  (* One parsed profile, independent of the generator host. *)
  type profile = {name : string, triple : string, abi : string,
    byteOrder : ForeignModel.byteOrder, analysis : CAnalysis.target,
    predefined : (string * string) list}
  (* A physical profile position and invalid target fact. *)
  exception Error of ForeignModel.source * string
  (* `decode {file, text}` checks a version-one target profile.

     Scalar widths, alignments, size type, enum policy and byte order are
     explicit. Invalid or unsupported profiles fail before native generation. *)
  val decode : {file : string, text : string} -> profile
  (* `model profile` returns target facts in the neutral binding model. *)
  val model : profile -> ForeignModel.target
end
