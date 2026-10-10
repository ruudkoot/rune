val () =
  case Json.decode "{\"ab\":1}" of
    Json.Object [(k, v)] =>
      print ("key size " ^ Int.toString (size k) ^ " bytes " ^ String.concatWith "," (map (Int.toString o ord) (explode k))
             ^ " valid " ^ Bool.toString (Utf8.isValid k) ^ " equal " ^ Bool.toString (k = "ab")
             ^ " string valid " ^ Bool.toString (Utf8.isValid (String.concat [k])) ^ "\n")
  | _ => print "?\n"
val () = case Json.decode "\"ab\"" of Json.String k => print ("string: valid " ^ Bool.toString (Utf8.isValid k) ^ "\n") | _ => ()
