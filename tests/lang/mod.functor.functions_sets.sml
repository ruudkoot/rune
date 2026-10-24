(* --functors=functions (a prototype): a functor compiled once, to a function of its
   argument's record; each application a call, with its own exceptions and refs *)
signature ORD = sig type t val compare : t * t -> order val name : string end
functor SetFn (O : ORD) = struct
  datatype set = Empty | Node of set * O.t * set
  exception NotFound of O.t
  val empty = Empty
  fun insert (x, Empty) = Node (Empty, x, Empty)
    | insert (x, s as Node (l, y, r)) =
        case O.compare (x, y) of
          LESS => Node (insert (x, l), y, r)
        | GREATER => Node (l, y, insert (x, r))
        | EQUAL => s
  fun member (x, Empty) = false
    | member (x, Node (l, y, r)) =
        case O.compare (x, y) of LESS => member (x, l) | GREATER => member (x, r) | EQUAL => true
  fun find (x, s) = if member (x, s) then x else raise NotFound x
  fun toList Empty = [] | toList (Node (l, x, r)) = toList l @ [x] @ toList r
  val counter = ref 0
  fun tick () = (counter := !counter + 1; !counter)
  val title = "set of " ^ O.name
end
structure IntSet = SetFn (struct type t = int val compare = Int.compare val name = "int" end)
structure StrSet = SetFn (struct type t = string val compare = String.compare val name = "string" end)
val s = List.foldl IntSet.insert IntSet.empty [5, 3, 8, 1, 3]
val _ = print (IntSet.title ^ ": " ^ String.concatWith " " (List.map Int.toString (IntSet.toList s)) ^ "\n")
val t = List.foldl StrSet.insert StrSet.empty ["b", "a", "c"]
val _ = print (StrSet.title ^ ": " ^ String.concatWith " " (StrSet.toList t) ^ "\n")
val _ = print (Bool.toString (IntSet.member (8, s)) ^ " " ^ Bool.toString (IntSet.member (9, s)) ^ "\n")
val _ = (IntSet.find (9, s); ()) handle IntSet.NotFound n => print ("not found " ^ Int.toString n ^ "\n")
val _ = (StrSet.find ("z", t); ()) handle IntSet.NotFound _ => print "wrong\n" | StrSet.NotFound z => print ("not found " ^ z ^ "\n")
val _ = print (Int.toString (IntSet.tick ()) ^ Int.toString (IntSet.tick ()) ^ Int.toString (StrSet.tick ()) ^ "\n")
val _ = case s of IntSet.Node (_, x, _) => print (Int.toString x ^ "\n") | IntSet.Empty => print "empty\n"
