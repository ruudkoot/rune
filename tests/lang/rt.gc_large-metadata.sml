(* Large-object table placement must leave the object header in the first
   chunk, where the collector and write barrier recover its owner by masking. *)
val length = 64 * 1024 * 1024
val bytes = CharArray.array (length, #"a")
val snapshot = CharArray.vector bytes
val () = CharArray.update (bytes, 0, #"z")
val () = Runtime.collect ()
val () = print ("large " ^ Int.toString (String.size snapshot) ^ " " ^
  str (String.sub (snapshot, 0)) ^ " " ^ str (CharArray.sub (bytes, 0)) ^ " " ^
  str (String.sub (snapshot, length - 1)) ^ "\n")
