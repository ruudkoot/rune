(* libraries: test/unit *)
(* Normalize against Unicode's own test data: every line of
   tests/lib/unicode/NormalizationTest.txt (copied by
   scripts/gen-unicode-tables.py from the version Normalize follows) has
   five columns c1 to c5, and the invariants of the file's header for the
   canonical forms must hold:

     c2 == NFC(c1) == NFC(c2) == NFC(c3),    c4 == NFC(c4) == NFC(c5)
     c3 == NFD(c1) == NFD(c2) == NFD(c3),    c5 == NFD(c4) == NFD(c5)

   over code points (nfcList, nfdList) and over UTF-8 (nfc, nfd), with
   isNFC and the quick check agreeing with nfc. Then the rule of Part 1:
   every code point that it does not list is unchanged by both forms. One
   test for each part, which names the lines that fail; run from the top of
   the tree. *)
structure NormalizeTest =
struct
  fun hex s = valOf (StringCvt.scanString (Int.scan StringCvt.HEX) s)

  (* the parts: their names and their lines, each the line's number and its
     five columns *)
  val parts =
    let
      val f = TextIO.openIn "tests/lib/unicode/NormalizationTest.txt"
      fun columns l =
        let val body = case String.fields (fn c => c = #"#") l of b :: _ => b | [] => ""
        in List.take (map (map hex o String.tokens Char.isSpace) (String.fields (fn c => c = #";") body), 5) end
      fun loop (n, cur, acc) =
        case TextIO.inputLine f of
          NONE => rev (case cur of SOME (p, ls) => (p, rev ls) :: acc | NONE => acc)
        | SOME l =>
            if String.isPrefix "@Part" l then
              let val name = hd (String.tokens Char.isSpace l)
              in loop (n + 1, SOME (name, []), case cur of SOME (p, ls) => (p, rev ls) :: acc | NONE => acc) end
            else if String.isPrefix "#" l orelse String.size l < 2 then loop (n + 1, cur, acc)
            else
              case cur of
                SOME (p, ls) => loop (n + 1, SOME (p, (n, columns l) :: ls), acc)
              | NONE => loop (n + 1, cur, acc)
    in
      loop (1, NONE, []) before TextIO.closeIn f
    end

  val forms = [("NFC", Normalize.nfcList, Normalize.nfc, [2, 2, 2, 4, 4]),
               ("NFD", Normalize.nfdList, Normalize.nfd, [3, 3, 3, 5, 5])]

  (* what is wrong with one line: a message for each invariant that fails *)
  fun line (n, cs) =
    let
      val col = fn i => List.nth (cs, i - 1)
      fun one ((name, f, g, want), msgs) =
        case List.foldl
              (fn (w, (i, msgs)) =>
                 let
                   val x = col i
                   val y = col w
                   val bad = (if f x = y then [] else [name ^ "(c" ^ Int.toString i ^ ") over code points"])
                             @ (if g (Utf8.implode x) = Utf8.implode y then []
                                else [name ^ "(c" ^ Int.toString i ^ ") over UTF-8"])
                 in
                   (i + 1, msgs @ bad)
                 end)
              (1, msgs) want of
          (_, msgs) => msgs
      val invariants = List.foldl one [] forms
      (* isNFC and the quick check against NFC, for each column *)
      fun nfcCheck (x, msgs) =
        let
          val s = Utf8.implode x
          val isNfc = Normalize.nfc s = s
          val q = Normalize.quickCheck s
          val ok = Normalize.isNFC s = isNfc andalso Normalize.isNFCList x = isNfc
                   andalso (q <> Normalize.Yes orelse isNfc) andalso (q <> Normalize.No orelse not isNfc)
                   andalso Normalize.quickCheckList x = q
        in
          if ok then msgs else msgs @ ["isNFC or quickCheck"]
        end
      val msgs = List.foldl nfcCheck invariants cs
    in
      if null msgs then NONE
      else SOME ("line " ^ Int.toString n ^ ": " ^ String.concatWith ", " msgs)
    end

  (* a part: every line, the first ten failures named *)
  fun part (name, ls) () =
    let
      val bad = List.mapPartial line ls
    in
      List.app (fn m => Expect.that (m, false)) (List.take (bad, Int.min (10, length bad)));
      Expect.that (name ^ ": " ^ Int.toString (length bad) ^ " of " ^ Int.toString (length ls)
                   ^ " lines fail (NormalizationTest " ^ Normalize.version ^ ")", null bad)
    end

  (* whether the code point c is its own NFC and NFD, as a list and as
     UTF-8 *)
  fun unchanged c =
    let val s = Utf8.encode c
    in Normalize.nfcList [c] = [c] andalso Normalize.nfdList [c] = [c] andalso Normalize.nfc s = s
       andalso Normalize.nfd s = s andalso Normalize.isNFC s end

  (* Part 1's rule: the code points it does not list are unchanged *)
  fun unlisted () =
    let
      val listed = Array.array (0x110000, false)
      val part1 = case List.find (fn (p, _) => p = "@Part1") parts of SOME (_, ls) => ls | NONE => []
      val () = List.app (fn (_, cs) => case hd cs of [c] => Array.update (listed, c, true) | _ => ()) part1
      fun go (c, bad, count) =
        if c > 0x10FFFF then (bad, count)
        else if c = 0xD800 then go (0xE000, bad, count)
        else if Array.sub (listed, c) then go (c + 1, bad, count)
        else if unchanged c orelse length bad >= 10 then go (c + 1, bad, count + 1)
        else go (c + 1, c :: bad, count + 1)
      val (bad, count) = go (0, [], 0)
    in
      List.app (fn c => Expect.that ("U+" ^ Int.fmt StringCvt.HEX c ^ " changes", false)) (rev bad);
      Expect.that (Int.toString count ^ " code points not in Part 1 are unchanged by NFC and NFD", null bad)
    end

  val tests =
    Test.describe "unicode/normalize"
      (map (fn p as (name, _) => Test.it (String.extract (name, 1, NONE)) (part p)) parts
       @ [Test.it "Part1-unlisted" unlisted])
end

structure NormalizeMain = Main (struct val name = "unicode/normalize" val tests = NormalizeTest.tests end)
val () = NormalizeMain.main ()
