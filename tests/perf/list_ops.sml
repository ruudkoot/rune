(* List: tabulate, map, filter, foldl, rev, @, sort by insertion into a sorted list.
   The argument is the length; the work is linear in it except for the sort
   of the first 200 elements. *)
val n = case CommandLine.arguments () of [a] => valOf (Int.fromString a) | _ => 20000
val l = List.tabulate (n, fn i => (i * 7919) mod 10007)
val evens = List.filter (fn x => x mod 2 = 0) l
val doubled = List.map (fn x => x * 2) evens
val total = List.foldl (op +) 0 (List.rev doubled @ l)
fun insert (x, []) = [x]
  | insert (x, y :: ys) = if x <= y then x :: y :: ys else y :: insert (x, ys)
val sorted = List.foldl insert [] (List.take (l, Int.min (n, 200)))
val () = print (Int.toString total ^ " " ^ Int.toString (List.length evens) ^ " "
                ^ Int.toString (List.nth (sorted, 0)) ^ " " ^ Int.toString (List.last sorted) ^ "\n")
