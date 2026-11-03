(* An exported functor (_export functor) is a functor of the program too: its
   body ascribed to its result's signature opaquely, so that each
   application's types are new; a datatype the result specifies is the
   body's, laid out as the specification says; and a constructor of the
   parameter's datatype whose argument is the parameter's type is laid out
   as the argument's datatype lays it, flat in Flat and boxed in Boxed
   (docs/units.md, Dynamic modules) *)
signature POINT =
sig
  type t
  datatype shape = Dot of t | Line of t * t | Nowhere
  val norm : t -> int
end

signature MEASURE =
sig
  type shape
  type total
  datatype kind = Small | Large of int
  val kind : shape -> kind
  val zero : total
  val add : total * shape -> total
  val show : total -> string
end

_export functor Measure (P : POINT) : MEASURE where type shape = P.shape =
struct
  type shape = P.shape
  type total = int * int
  datatype kind = Small | Large of int
  fun size (P.Dot p) = P.norm p
    | size (P.Line (p, q)) = P.norm p + P.norm q
    | size P.Nowhere = 0
  fun kind s = let val n = size s in if n < 10 then Small else Large n end
  val zero = (0, 0)
  fun add ((count, sum), s) = (count + 1, sum + size s)
  fun show (count, sum) = Int.toString count ^ " shapes, " ^ Int.toString sum
end

structure Flat =
struct
  type t = int * int
  datatype shape = Dot of t | Line of t * t | Nowhere
  fun norm (x, y) = abs x + abs y
end

structure Boxed =
struct
  type t = int
  datatype shape = Dot of t | Line of t * t | Nowhere
  val norm = abs
end

structure MF = Measure (Flat)
structure MB = Measure (Boxed)

fun kindName MF.Small = "small"
  | kindName (MF.Large n) = "large " ^ Int.toString n
val () = print (kindName (MF.kind (Flat.Dot (3, 4))) ^ ", " ^ kindName (MF.kind (Flat.Line ((5, 5), (1, ~2)))) ^ "\n")
val () = print (MF.show (List.foldl (fn (s, t) => MF.add (t, s)) MF.zero [Flat.Dot (1, 2), Flat.Nowhere, Flat.Line ((1, 1), (2, 2))]) ^ "\n")
val () = print (MB.show (MB.add (MB.add (MB.zero, Boxed.Dot ~7), Boxed.Line (2, 3))) ^ "\n")
val () = print (case MB.kind (Boxed.Line (20, 1)) of MB.Small => "small\n" | MB.Large n => "large " ^ Int.toString n ^ "\n")
