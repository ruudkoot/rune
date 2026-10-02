(* dump: --passes=simplify --dump-after=lower *)
(* A closure captures nothing for the branch of a tag tested again, which
   the switch on the tag leaves out (Lower): k, used only there, is not
   captured, since every value a closure captures it reads (LowLint). *)
datatype t = A of int | B of int | C of int | D of int
fun dead k =
  fn x => case x of
            A n => n
          | B n => n + 1
          | C n => n + 2
          | _ => (case x of A n => n + k | _ => 0)
