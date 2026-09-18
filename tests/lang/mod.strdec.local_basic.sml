(* local at structure level *)
local
  structure Hidden = struct val secret = 41 fun bump n = n + 1 end
in
  structure Public = struct val answer = Hidden.bump Hidden.secret end
  val alsoPublic = Hidden.secret
end
val () = print (Int.toString Public.answer ^ " " ^ Int.toString alsoPublic ^ "\n")
