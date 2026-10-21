(* libraries: test/unit *)
(* Emulator: what a terminal shows after text, wrapping, wide clusters,
   moves and erasing, as xterm does. *)
structure EmulatorTest =
struct
  val check = Expect.that

  fun screen (cols, rows, bytes) =
    Emulator.write (Emulator.new {columns = cols, rows = rows, policy = Grapheme.ByCluster}, bytes)
  fun shows (name, cols, rows, bytes, want) =
    let val got = Emulator.text (screen (cols, rows, bytes))
    in check (name ^ ": " ^ String.toString got, got = want) end

  fun screens () =
    (shows ("text", 10, 3, "hello", "hello");
     shows ("wrap", 4, 3, "abcdef", "abcd\nef");
     shows ("pending wrap", 4, 3, "abcd\r\nx", "abcd\nx");
     shows ("pending wrap then CR", 4, 3, "abcd\rX", "Xbcd");
     shows ("wide", 5, 3, "a\228\184\173b", "a\228\184\173b");
     shows ("wide at the margin", 4, 3, "abc\228\184\173", "abc\n\228\184\173");
     shows ("a wide one overwritten by half", 4, 2, "\228\184\173\rx", "x");
     shows ("combining", 5, 2, "e\204\129x", "e\204\129x");
     shows ("emoji", 5, 2, "\240\159\152\128x", "\240\159\152\128x");
     shows ("CUU CUD CUF CUB", 10, 4, "a\r\nb\027[1A\027[3Cc\027[1B\027[2Dd", "a   c\nb  d");
     shows ("CHA", 10, 2, "abcdef\027[3GX", "abXdef");
     shows ("EL", 10, 2, "abcdef\027[3G\027[K", "ab");
     shows ("EL 1", 10, 2, "abcdef\027[3G\027[1K", "   def");
     shows ("ED", 10, 3, "a\r\nb\r\nc\027[2A\027[J", "a");
     shows ("scroll", 5, 2, "a\r\nb\r\nc", "b\nc");
     shows ("split writes", 10, 2, "", ""))

  fun acrossWrites () =
    let
      val s = Emulator.write (Emulator.write (Emulator.new {columns = 10, rows = 2, policy = Grapheme.ByCluster},
                                              "a\027["), "1Gb\226\130")
      val s = Emulator.write (s, "\172c")
    in
      check ("an escape and a character across writes", Emulator.text s = "b\226\130\172c");
      check ("OSC title is not screen text", Emulator.text (screen (20, 2, "a\027]0;window title\007b")) = "ab");
      check ("OSC split across writes", Emulator.text (Emulator.write (screen (20, 2, "a\027]133;A\027"), "\\b")) = "ab")
    end

  fun styles () =
    let val s = screen (10, 2, "\027[1;31mab\027[0mc")
    in
      check ("styles", map #style (Emulator.row (s, 0)) = [Style.parameters "1;31", Style.parameters "1;31", Style.plain]);
      check ("selective style reset preserves colour", Style.parameters "1;2;3;4;7;9;31;22;23;24;27;29" = Style.parameters "31");
      check ("ConPTY bold reset", map #style (Emulator.row (screen (10, 2, "\027[1ma\027[22mb"), 0)) = [Style.parameters "1", Style.plain])
    end

  fun cursor () =
    (check ("cursor", Emulator.cursor (screen (10, 3, "ab\r\ncd")) = (1, 2));
     check ("cursor at the margin", Emulator.cursor (screen (4, 3, "abcd")) = (0, 3)))

  fun scrolled () = check ("scrolled", Emulator.scrolled (screen (5, 2, "a\r\nb\r\nc\r\nd")) = 2)

  fun modes () =
    check ("modes", Emulator.modes (screen (5, 2, "\027[?2004h\027[?25l")) = {bracketedPaste = true, cursorVisible = false})

  fun resize () =
    let val s = screen (5, 3, "a\228\184\173b\r\n\027[1mstyled\027[?2004h")
        val small = Emulator.resize (s, {columns = 2, rows = 2})
        val large = Emulator.resize (small, {columns = 8, rows = 4})
    in check ("resize clips a wide cell whole", Emulator.text small = "a\nst");
       check ("resize preserves modes", #bracketedPaste (Emulator.modes large));
       check ("resize preserves styles", #bold (#style (hd (Emulator.row (large, 1)))));
       check ("resize grows with blank cells", Emulator.text large = Emulator.text small);
       check ("resize clamps the cursor", #2 (Emulator.cursor small) < 2)
    end

  val tests =
    Test.describe "terminal/emulator"
      [Test.it "screens" screens, Test.it "across-writes" acrossWrites, Test.it "styles" styles,
       Test.it "cursor" cursor, Test.it "scrolled" scrolled, Test.it "modes" modes, Test.it "resize" resize]
end

structure EmulatorMain = Main (struct val name = "terminal/emulator" val tests = EmulatorTest.tests end)
val () = EmulatorMain.main ()
