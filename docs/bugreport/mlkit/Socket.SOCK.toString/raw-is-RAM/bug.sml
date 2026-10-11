(* "If a pair (name,sty) is in the list returned by list, then it is the
   case that name is equal to toString(sty)"; the names include "RAW" for
   raw sockets, and fromString reads a name back. *)
structure S = Socket.SOCK
fun opt NONE = "NONE"
  | opt (SOME t) = "SOME " ^ S.toString t
val () = List.app (fn (name, sty) =>
           print ("list: " ^ name ^ "   toString: " ^ S.toString sty
                  ^ "   fromString (toString): " ^ opt (S.fromString (S.toString sty)) ^ "\n"))
         (S.list ())
