(* Emulator: what a terminal shows after text, wrapping, wide clusters,
   moves and erasing, as xterm does. *)
structure EmulatorTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  fun screen (cols, rows, bytes) =
    Emulator.write (Emulator.new {columns = cols, rows = rows, policy = Grapheme.ByCluster}, bytes)
  fun shows (name, cols, rows, bytes, want) =
    let val got = Emulator.text (screen (cols, rows, bytes))
    in check (name ^ ": " ^ String.toString got, got = want) end

  fun main () =
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
     shows ("split writes", 10, 2, "", "");
     let
       val s = Emulator.write (Emulator.write (Emulator.new {columns = 10, rows = 2, policy = Grapheme.ByCluster},
                                               "a\027["), "1Gb\226\130")
       val s = Emulator.write (s, "\172c")
     in
       check ("an escape and a character across writes", Emulator.text s = "b\226\130\172c")
     end;
     let val s = screen (10, 2, "\027[1;31mab\027[0mc")
     in
       check ("styles", map #style (Emulator.row (s, 0)) = [Style.parameters "1;31", Style.parameters "1;31", Style.plain])
     end;
     check ("cursor", Emulator.cursor (screen (10, 3, "ab\r\ncd")) = (1, 2));
     check ("cursor at the margin", Emulator.cursor (screen (4, 3, "abcd")) = (0, 3));
     check ("scrolled", Emulator.scrolled (screen (5, 2, "a\r\nb\r\nc\r\nd")) = 2);
     check ("modes", Emulator.modes (screen (5, 2, "\027[?2004h\027[?25l")) = {bracketedPaste = true, cursorVisible = false});
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " emulator: " ^ Int.toString (!failures) ^ " failed\n"))
end

val () = EmulatorTest.main ()
