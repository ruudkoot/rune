(* dump: --passes= --dump-after=lower *)
(* The representation of a datatype's values (Rep, M11): a constructor whose
   argument is a tuple is one object of its fields (con of the fields), and
   a match takes them one by one (field); one of any other argument boxes it
   (con of one, decon). The tuple made only for a constructor is never made
   (make); one that comes whole is taken apart (rewrap); an argument used
   whole is a copy (whole). *)
datatype t = Pair of int * int | Box of int | Wrap of int * int
fun make (a, b) = Pair (a, b)
fun sum (Pair (a, b)) = a + b
  | sum (Box a) = a
  | sum (Wrap _) = 0
fun rewrap p = Wrap p
fun whole (Wrap p) = p
  | whole _ = (0, 0)
