(* INet6Sock: addresses of the Internet protocol version 6, which the
   specification has no structure for. Only the text forms are printed: a
   machine without IPv6 still reads and writes addresses. *)
val show = fn s => case INet6Sock.fromString s of SOME a => INet6Sock.toString a | NONE => "none"
val () = print (show "::1" ^ " " ^ show "0:0:0:0:0:0:0:1" ^ " " ^ show "::" ^ "\n")
val () = print (show "fe80:0:0:0:0:0:0:1" ^ " " ^ show "::ffff:127.0.0.1" ^ "\n")
val () = print (show "127.0.0.1" ^ " " ^ show "not an address" ^ "\n")
val () = print ("family " ^ Socket.AF.toString INet6Sock.inet6AF
                ^ ", known: " ^ Bool.toString (Socket.AF.fromString "INET6" = SOME INet6Sock.inet6AF) ^ "\n")
val a = INet6Sock.toAddr (valOf (INet6Sock.fromString "::1"), 8080)
val (host, port) = INet6Sock.fromAddr a
val () = print ("address " ^ INet6Sock.toString host ^ " port " ^ Int.toString port
                ^ ", any " ^ INet6Sock.toString (#1 (INet6Sock.fromAddr (INet6Sock.any 0))) ^ "\n")
