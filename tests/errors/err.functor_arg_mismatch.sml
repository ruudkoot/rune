functor F (X : sig val x : int end) = struct val y = X.x end
structure A = F (struct val x = "no" end)
