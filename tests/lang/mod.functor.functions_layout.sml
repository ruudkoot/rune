(* --functors=functions: a datatype a body declares over a parameter's type keeps the
   layout the body gives it in every instance, whatever the argument's type is *)
signature S = sig type t val mk : int -> t val show : t -> string end
functor F (X : S) = struct
  datatype d = D of X.t | E
  fun make n = D (X.mk n)
  fun see v = case v of D x => "D " ^ X.show x | E => "E"
  fun same (a : d, b) = (case (a, b) of (D x, D y) => X.show x = X.show y | (E, E) => true | _ => false)
end
structure P = struct type t = int * int fun mk n = (n, n * 2) fun show (a, b) = Int.toString a ^ "/" ^ Int.toString b end
structure A = F (P)
val v = A.D (3, 4)
val _ = print (A.see v ^ " " ^ A.see (A.make 5) ^ " " ^ (case A.make 6 of A.D (x, y) => Int.toString (x + y) | A.E => "E") ^ "\n")
val _ = print (Bool.toString (A.same (A.D (5, 10), A.make 5)) ^ "\n")
