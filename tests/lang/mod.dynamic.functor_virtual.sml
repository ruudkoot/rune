(* A virtual functor and its implementation in one program: _export functor
   gives the function, which the declaration functor F = _virtual takes,
   where the fingerprints of the two ABIs agree. Each application is typed
   by the signature alone -- its set and its exception new, its element the
   parameter's -- and is a call of that function (docs/units.md, Dynamic
   modules) *)
signature ORD =
sig
  type t
  val compare : t * t -> order
end

signature SET =
sig
  type elem
  type set
  exception Absent of elem
  val empty : set
  val add : set * elem -> set
  val member : set * elem -> bool
  val remove : set * elem -> set
  val elements : set -> elem list
  structure Count : sig val size : set -> int end
end

_export functor Set (O : ORD) : SET where type elem = O.t =
struct
  type elem = O.t
  type set = elem list
  exception Absent of elem
  val empty = []
  fun add ([], x) = [x]
    | add (s as y :: rest, x) =
        case O.compare (x, y) of
          LESS => x :: s
        | EQUAL => s
        | GREATER => y :: add (rest, x)
  fun member (s, x) = List.exists (fn y => O.compare (x, y) = EQUAL) s
  fun remove (s, x) = if member (s, x) then List.filter (fn y => O.compare (x, y) <> EQUAL) s else raise Absent x
  fun elements s = s
  structure Count = struct val size = List.length end
end

functor Set = _virtual (O : ORD) : SET where type elem = O.t

structure Ints = Set (struct type t = int val compare = Int.compare end)
structure Names = Set (struct type t = string val compare = String.compare end)

val s = List.foldl (fn (x, s) => Ints.add (s, x)) Ints.empty [3, 1, 4, 1, 5, 9, 2, 6]
val () = print (String.concatWith " " (List.map Int.toString (Ints.elements s)) ^ " (" ^ Int.toString (Ints.Count.size s) ^ ")\n")
val n = Names.add (Names.add (Names.empty, "b"), "a")
val () = print (String.concatWith " " (Names.elements n) ^ "\n")
val () = print (Bool.toString (Ints.member (s, 4)) ^ " " ^ Bool.toString (Ints.member (s, 7)) ^ "\n")
val () = (ignore (Ints.remove (s, 7)); print "removed\n") handle Ints.Absent k => print ("absent " ^ Int.toString k ^ "\n")
(* an exception of each application *)
val () = (ignore (Names.remove (n, "c")) handle Ints.Absent _ => print "the wrong exception\n")
         handle Names.Absent k => print ("absent " ^ k ^ "\n")
