(* A name of the elaborator, which a client of the layer from Mid on cannot
   name (mid-client-elab.build) *)
structure MidClientElab = struct val fresh = Elaborate.freshStamp end
