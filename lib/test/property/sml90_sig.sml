(* The arbitrary of the input streams of the optional structure `SML90`,
   apart from `SYSTEM_ARB` because not every compiler has that structure.

   Area: Property testing *)
signature SML90_ARB =
sig
  (* The arbitrary of SML '90 input streams: a file in a scratch directory
     with a drawn string in it, removed when the case is over. *)
  val instream : SML90.instream Arb.arb
end
