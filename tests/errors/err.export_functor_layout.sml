(* The same of an exported functor's result: its datatype is read by a
   program compiled against the result's signature alone *)
signature IN = sig val n : int end
signature OUT = sig type u datatype d = D of u | E val make : unit -> d end
_export functor F (X : IN) : OUT =
struct
  type u = int * int
  datatype d = D of u | E
  fun make () = D (X.n, X.n)
end
