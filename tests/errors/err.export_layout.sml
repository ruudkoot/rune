(* A datatype the signature specifies, whose constructor takes the
   signature's abstract type, lies boxed in a program compiled against the
   signature alone; the implementation, where the type is a pair, would lay
   it in two fields, which such a program would misread: refused *)
signature S = sig type u datatype d = D of u | E val make : int -> d end
_export structure M : S =
struct
  type u = int * int
  datatype d = D of u | E
  fun make n = D (n, n)
end
