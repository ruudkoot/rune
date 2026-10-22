nonfix +
signature PRIVATE = sig val value : int end
structure Hidden : PRIVATE = struct val value = 41 end
type private = int
functor Secret () = struct datatype t = C end
