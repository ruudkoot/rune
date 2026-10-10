(* Grapheme against Unicode's own test data: every line of
   tests/lib/unicode/GraphemeBreakTest.txt (copied by
   scripts/gen-unicode-tables.py from the version Grapheme follows) is a
   string of code points with ÷ where a cluster ends and × where it does
   not; Grapheme.clusters must cut the same string at the same places. Run
   from the top of the tree. *)
structure GraphemeTest =
struct
  fun hex s = valOf (StringCvt.scanString (Int.scan StringCvt.HEX) s)

  (* "÷ 0061 × 0308 ÷" to the clusters, each a list of code points *)
  fun expected line =
    let
      val body = case String.fields (fn c => c = #"#") line of b :: _ => b | [] => ""
      val words = String.tokens Char.isSpace body
      fun go ([], cur, acc) = rev (if null cur then acc else rev cur :: acc)
        | go (w :: ws, cur, acc) =
            if w = "\195\183" then go (ws, [], if null cur then acc else rev cur :: acc)
            else if w = "\195\151" then go (ws, cur, acc)
            else go (ws, hex w :: cur, acc)
    in
      go (words, [], [])
    end

  val passed = ref 0
  val failed = ref 0

  fun check (n, line) =
    let
      val want = expected line
      val s = Utf8.implode (List.concat want)
      val got = map Utf8.explode (Grapheme.clusters s)
    in
      if got = want then passed := !passed + 1
      else (failed := !failed + 1;
            if !failed <= 10 then print ("FAIL line " ^ Int.toString n ^ ": " ^ line ^ "\n") else ())
    end

  fun main () =
    let
      val f = TextIO.openIn "tests/lib/unicode/GraphemeBreakTest.txt"
      fun loop n =
        case TextIO.inputLine f of
          NONE => ()
        | SOME l =>
            (if String.isPrefix "\195\183" l then check (n, l) else ();
             loop (n + 1))
    in
      loop 1;
      TextIO.closeIn f;
      print ((if !failed = 0 then "PASS" else "FAIL") ^ " GraphemeBreakTest " ^ Grapheme.version
             ^ ": " ^ Int.toString (!passed) ^ " passed, " ^ Int.toString (!failed) ^ " failed\n")
    end
end

val () = GraphemeTest.main ()
