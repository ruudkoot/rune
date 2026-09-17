datatype expr = Num of int | Add of expr * expr | Block of stmt list
and stmt = Print of expr | Seq of stmt * stmt
fun eval (Num n) = n
  | eval (Add (a, b)) = eval a + eval b
  | eval (Block ss) = (List.app exec ss; 0)
and exec (Print e) = print (Int.toString (eval e) ^ "\n")
  | exec (Seq (a, b)) = (exec a; exec b)
val () = exec (Seq (Print (Add (Num 1, Num 2)), Print (Block [Print (Num 7)])))
