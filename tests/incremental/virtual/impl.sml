(* Its implementation: a list in order *)
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
  val size = List.length
  fun remove (s, x) =
    if List.exists (fn y => O.compare (x, y) = EQUAL) s then List.filter (fn y => O.compare (x, y) <> EQUAL) s
    else raise Absent x
  fun elems s = s
end
