(* --functors=functions: a parameter's constructor whose argument is one of its abstract
   types, laid out flat by one argument and boxed by another, built, taken apart and
   compared in the body by the argument's descriptor; and passed on to another functor *)
signature S = sig
  type info
  datatype t = C of info | D | E of info * int
  val mk : int -> info
  val show : info -> string
end
functor F (X : S) = struct
  fun build n = if n = 0 then X.D else if n = 1 then X.C (X.mk 7) else X.E (X.mk n, n)
  fun look v = case v of X.C i => "C " ^ X.show i | X.D => "D" | X.E (i, k) => "E " ^ X.show i ^ " " ^ Int.toString k
  val wrap = X.C
  fun same (a, b) = a = b
end
structure Flat = struct
  type info = int * int
  datatype t = C of info | D | E of info * int
  fun mk n = (n, n + 1)
  fun show (a, b) = "(" ^ Int.toString a ^ "," ^ Int.toString b ^ ")"
end
structure Boxed = struct
  type info = int
  datatype t = C of info | D | E of info * int
  fun mk n = n * 10
  fun show i = Int.toString i
end
structure A = F (Flat)
structure B = F (Boxed)
val _ = print (A.look (A.build 0) ^ "; " ^ A.look (A.build 1) ^ "; " ^ A.look (A.build 5) ^ "\n")
val _ = print (B.look (B.build 0) ^ "; " ^ B.look (B.build 1) ^ "; " ^ B.look (B.build 5) ^ "\n")
val _ = print (A.look (Flat.C (3, 4)) ^ " " ^ (case A.build 1 of Flat.C (x, y) => Int.toString (x + y) | _ => "?") ^ "\n")
val _ = print (A.look (A.wrap (8, 9)) ^ " " ^ Bool.toString (A.same (Flat.C (1, 2), A.build 1)) ^ " " ^ Bool.toString (A.same (Flat.C (7, 8), A.build 1)) ^ "\n")
functor G (X : S) = struct
  structure Y = F (X)
  structure Z = F (struct open X val show = fn i => "<" ^ X.show i ^ ">" end)
  fun twice n = Y.look (Y.build n) ^ " | " ^ Z.look (Y.build (n + 1)) ^ " | " ^ Y.look (Z.build (n + 2))
  exception Oops of X.t
end
structure GA = G (Flat)
val _ = print (GA.twice 0 ^ "\n" ^ GA.twice 4 ^ "\n")
val _ = (raise GA.Oops (GA.Y.build 1)) handle GA.Oops v => print ("oops " ^ GA.Y.look v ^ "\n")
