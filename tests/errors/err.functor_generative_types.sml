functor F (X : sig type t end) = struct datatype d = D of X.t end
structure A = F (type t = int) and B = F (type t = int)
val z = (A.D 1 = B.D 1)
