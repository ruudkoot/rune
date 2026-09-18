structure S :> sig type t val x : t end = struct type t = int val x = 1 end
val b = S.x = S.x
