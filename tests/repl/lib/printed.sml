structure Printed :> sig type t val mk : int -> t end = struct type t = int fun mk x = x * 10 end
