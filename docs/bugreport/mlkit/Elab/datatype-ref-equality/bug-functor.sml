signature S = sig type s val v : s end
functor F (X : S) = struct datatype t = T of X.s ref fun mk () = T (ref X.v) end
structure A = F (struct type s = int -> int val v = fn x => x end)
val a = A.mk ()
val () = print (if a = a andalso a <> A.mk () then "equal when the same\n" else "wrong\n")
