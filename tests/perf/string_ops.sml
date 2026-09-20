(* String: concat, explode/implode, tokens, fields, translate, isSubstring.
   The argument is the number of words; the work is linear in it. *)
val n = case CommandLine.arguments () of [a] => valOf (Int.fromString a) | _ => 4000
val words = List.tabulate (n, fn i => "w" ^ Int.toString (i * 31 mod 997))
val text = String.concatWith " " words
val toks = String.tokens Char.isSpace text
val upper = String.map Char.toUpper text
val rev = String.implode (List.rev (String.explode text))
val hits = List.length (List.filter (fn w => String.isSubstring "99" w) toks)
val trans = String.translate (fn #" " => "" | c => String.str c) upper
val () = print (Int.toString (String.size text) ^ " " ^ Int.toString (List.length toks) ^ " "
                ^ Int.toString hits ^ " " ^ Int.toString (String.size trans) ^ " "
                ^ String.substring (rev, 0, 8) ^ "\n")
