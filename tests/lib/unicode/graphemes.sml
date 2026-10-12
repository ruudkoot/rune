(* libraries: test/unit *)
(* Grapheme against Unicode's own test data: every line of
   tests/lib/unicode/GraphemeBreakTest.txt (copied by
   scripts/gen-unicode-tables.py from the version Grapheme follows) is a
   string of code points with ÷ where a cluster ends and × where it does
   not; Grapheme.clusters must cut the same string at the same places. One
   test for each, named by the number of its line. Run from the top of the
   tree. *)
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

  (* the lines of cases, with their numbers *)
  val cases =
    let
      val f = TextIO.openIn "tests/lib/unicode/GraphemeBreakTest.txt"
      fun chomp l = if String.isSuffix "\n" l then String.substring (l, 0, size l - 1) else l
      fun loop (n, acc) =
        case TextIO.inputLine f of
          NONE => rev acc
        | SOME l => loop (n + 1, if String.isPrefix "\195\183" l then (n, chomp l) :: acc else acc)
    in
      loop (1, []) before TextIO.closeIn f
    end

  fun check (n, line) () =
    let
      val want = expected line
      val s = Utf8.implode (List.concat want)
      val got = map Utf8.explode (Grapheme.clusters s)
    in
      Expect.that ("GraphemeBreakTest " ^ Grapheme.version ^ ", line " ^ Int.toString n ^ ": " ^ line, got = want)
    end

  val tests =
    Test.describe "unicode/graphemes" (map (fn (n, line) => Test.it ("line-" ^ Int.toString n) (check (n, line))) cases)
end

structure GraphemeMain = Main (struct val name = "unicode/graphemes" val tests = GraphemeTest.tests end)
val () = GraphemeMain.main ()
