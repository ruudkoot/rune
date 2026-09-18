structure S :> sig type t val x : t end = struct type t = int val x = 1 end
val y = S.x + 1
