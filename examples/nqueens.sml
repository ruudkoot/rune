(* Count solutions of the N-queens problem. Pass N on the command line. *)
fun safe (q, qs) =
  let
    fun go ([], _) = true
      | go (x :: xs, d) = x <> q andalso x <> q + d andalso x <> q - d andalso go (xs, d + 1)
  in go (qs, 1) end

fun queens n =
  let
    fun place (0, qs) = 1
      | place (k, qs) =
        List.foldl (fn (q, acc) => if safe (q, qs) then acc + place (k - 1, q :: qs) else acc)
                   0 (List.tabulate (n, fn i => i + 1))
  in place (n, []) end

val n = case CommandLine.arguments () of
          [a] => (case Int.fromString a of SOME n => n | NONE => 8)
        | _ => 8
val () = print (Int.toString n ^ " queens: " ^ Int.toString (queens n) ^ " solutions\n")
