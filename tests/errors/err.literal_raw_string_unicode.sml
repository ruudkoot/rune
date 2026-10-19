(* under --unicode a raw character above 127 means its code point, which a
   string cannot hold as it stands: the escape says the byte or the UTF-8 *)
val s = "café"
