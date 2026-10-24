(* --functors=functions with the expansion (M6): what a copy of a body must keep --
   polymorphic slots and a parameter's type of arity 1, exceptions and refs made anew by
   each application, a datatype of the body over the parameter's types laid out from the
   argument's, a local one, pattern bindings and a handler among the body's declarations,
   equality at the parameter's types, applications inside bodies, and substructures *)
signature COLL = sig
  type 'a t
  val empty : 'a t
  val add : 'a * 'a t -> 'a t
  val fold : ('a * 'b -> 'b) -> 'b -> 'a t -> 'b
  val name : string
end
functor Count (C : COLL) = struct
  exception Empty of string
  val counter = ref 0
  fun size s = (counter := !counter + 1; C.fold (fn (_, n) => n + 1) 0 s)
  fun fromList l = List.foldl C.add C.empty l
  fun toList s = C.fold (op ::) [] s
  fun first s = case toList s of x :: _ => x | [] => raise Empty C.name
  val (lo, hi) = (C.name ^ "<", C.name ^ ">")
  val SOME tag = SOME (String.size C.name)
  val safe = (raise Empty "never") handle Empty m => "handled " ^ m
  fun same (a : int C.t, b : int C.t) = toList a = toList b
end
structure L = struct
  type 'a t = 'a list
  val empty = []
  fun add (x, l) = x :: l
  fun fold f z l = List.foldl f z l
  val name = "list"
end
structure R = struct
  datatype 'a t = N | Cons of 'a * 'a t
  val empty = N
  fun add (x, s) = Cons (x, s)
  fun fold f z N = z | fold f z (Cons (x, s)) = fold f (f (x, z)) s
  val name = "rev"
end
structure CL = Count (L)
structure CR = Count (R)
structure CL2 = Count (L)
val s = CL.fromList [1, 2, 3]
val r = CR.fromList ["a", "b"]
val _ = print (Int.toString (CL.size s) ^ " " ^ Int.toString (CR.size r) ^ " " ^ CL.lo ^ CL.hi ^ CR.lo ^ " "
               ^ Int.toString CL.tag ^ " " ^ CL.safe ^ "\n")
val _ = print (String.concatWith "," (List.map Int.toString (CL.toList s)) ^ " " ^ String.concatWith "," (CR.toList r) ^ "\n")
val _ = print (Int.toString (!CL.counter) ^ " " ^ Int.toString (!CR.counter) ^ " " ^ Int.toString (!CL2.counter) ^ "\n")
val _ = print (Bool.toString (CL.same (s, CL.fromList [1, 2, 3])) ^ " " ^ Bool.toString (CL.same (s, CL.fromList [3])) ^ "\n")
val _ = (CL.first (CL.fromList []); ()) handle CL2.Empty m => print ("CL2 " ^ m ^ "\n") | CL.Empty m => print ("CL " ^ m ^ "\n")

signature PT = sig eqtype p val mk : int -> p val sum : p -> int end
functor Shapes (P : PT) = struct
  datatype shape = Dot of P.p | Line of P.p * P.p | None
  local
    datatype hidden = H of P.p * int
    fun hide p = H (p, 1)
    fun unhide (H (p, n)) = P.sum p + n
  in
    fun weight s = case s of Dot p => unhide (hide p) | Line (a, b) => P.sum a + P.sum b | None => 0
  end
  fun dots n = List.tabulate (n, fn i => Dot (P.mk i))
  exception Bad of shape
  fun check s = case s of None => raise Bad s | _ => s
  structure Sub = struct val origin = Dot (P.mk 0) fun isOrigin s = s = origin end
end
structure Pair = struct type p = int * int fun mk n = (n, n * 2) fun sum (a, b) = a + b end
structure One = struct type p = int fun mk n = n fun sum p = p end
structure SP = Shapes (Pair)
structure SO = Shapes (One)
val _ = print (Int.toString (List.foldl (fn (s, n) => SP.weight s + n) 0 (SP.dots 4)) ^ " "
               ^ Int.toString (SP.weight (SP.Line ((1, 2), (3, 4)))) ^ " " ^ Int.toString (SO.weight (SO.Dot 5)) ^ "\n")
val _ = print (Bool.toString (SP.Sub.isOrigin (SP.Dot (0, 0))) ^ " " ^ Bool.toString (SP.Sub.isOrigin (hd (SP.dots 2)))
               ^ " " ^ Bool.toString (SO.Sub.isOrigin (SO.Dot 1)) ^ "\n")
val _ = (SP.check SP.None; ()) handle SP.Bad s => print ("bad " ^ Int.toString (SP.weight s) ^ "\n")
val _ = case SP.Line ((5, 6), (7, 8)) of SP.Line ((a, _), (_, d)) => print (Int.toString (a + d) ^ "\n") | _ => ()

functor Twice (P : PT) = struct
  structure A = Shapes (P)
  structure B = Shapes (struct type p = P.p * P.p fun mk n = (P.mk n, P.mk (n + 1)) fun sum (x, y) = P.sum x + P.sum y end)
  fun total n = List.foldl (fn (s, m) => A.weight s + m) 0 (A.dots n) + List.foldl (fn (s, m) => B.weight s + m) 0 (B.dots n)
end
structure T1 = Twice (Pair)
structure T2 = Twice (One)
val _ = print (Int.toString (T1.total 3) ^ " " ^ Int.toString (T2.total 3) ^ " " ^ Int.toString (T1.B.weight (T1.B.Dot ((1, 1), (2, 2)))) ^ "\n")
