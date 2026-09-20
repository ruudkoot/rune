(* Time: the conversions and the arithmetic, on values worked out by hand.
   The conversions take and give LargeInt.int, which is IntInf.int here. *)
val t = Time.fromSeconds 90
val () = print (Time.toString t ^ " " ^ LargeInt.toString (Time.toMilliseconds t) ^ " "
                ^ LargeInt.toString (Time.toMicroseconds t) ^ "\n")
(* the parts are truncated towards zero *)
val u = Time.fromMicroseconds 1500000
val () = print (LargeInt.toString (Time.toSeconds u) ^ " " ^ Time.fmt 0 u ^ " " ^ Time.fmt 1 u ^ " " ^ Time.fmt 6 u ^ "\n")
val v = Time.fromReal ~2.25
val () = print (Time.toString v ^ " " ^ Real.toString (Time.toReal v) ^ "\n")
val () = print (Time.toString (Time.+ (t, u)) ^ " " ^ Time.toString (Time.- (u, t)) ^ "\n")
val () = print (Bool.toString (Time.< (v, Time.zeroTime)) ^ Bool.toString (Time.>= (t, u))
                ^ (case Time.compare (t, t) of EQUAL => "E" | _ => "?") ^ "\n")
val () = print (Time.toString (valOf (Time.fromString " 12.5 rest")) ^ " "
                ^ (case Time.fromString "x" of NONE => "none" | SOME _ => "some") ^ "\n")
val () = print (((Time.fmt ~1 t; "no Size") handle Size => "Size") ^ "\n")
