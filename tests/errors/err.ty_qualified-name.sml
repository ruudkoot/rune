(* A type that the top level does not name by its own name is named by its
   path: WideString.string, not string *)
val s : string = WideString.implode []
