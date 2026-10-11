(* the second unit: calls, matches and applies what the first declared *)
fun area (Circle r) = 3.0 * r * r
  | area (Rect (w, h)) = w * h
  | area Point = 0.0
structure C = Counter (struct val start = 41 end)
val sum = add (1, 2) + ((1, 2) +++ 3) + curried 1 2 3
val adders = List.map add [(1, 1), (2, 2)]
val () = Store.push 4
val () = print (Int.toString sum ^ " " ^ Int.toString (C.next ()) ^ " "
                ^ String.concatWith "," (List.map Int.toString (adders @ !Store.items)) ^ " "
                ^ Real.toString (area (Rect (2.0, 3.0))) ^ "\n")
structure Store = struct val items = ref ["shadowed"] end
