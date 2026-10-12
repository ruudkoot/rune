(* libraries: test/unit random *)
(* The line editor's core: what keys do to the text and the cursor, the
   history, search, completion and the kill ring; and the property of
   docs/plans/repl.md's D23 -- for random edits at random widths, what
   diff writes, given to the emulator over a screen that shows the frame
   before, makes it show the frame after. The editor is applied to
   PosixDevice, so that the test is the same on every compiler. *)
structure L = LineEditFn (structure Device = PosixDevice)

structure EditTest =
struct
  val check = Expect.that

  val none = Key.none
  fun ch c = Key.Char (Char.ord c, none)
  fun ctrl c = Key.Char (Char.ord c, {shift = false, alt = false, ctrl = true})
  fun alt c = Key.Char (Char.ord c, {shift = false, alt = true, ctrl = false})
  fun key n = Key.Named (n, none)
  fun typed s = map (fn c => Key.Char (c, none)) (Utf8.explode s)

  fun run (config, history, events) =
    foldl (fn (e, (s, _)) => L.step (config, s, e)) (L.start (Vector.fromList history, ""), L.Continue) events

  fun result (config, history, events) = let val (s, _) = run (config, history, events) in (L.text s, L.cursor s) end
  fun is (name, events, want) =
    let val got = result (L.defaults, [], events)
    in check (name ^ ": " ^ String.toString (#1 got) ^ " at " ^ Int.toString (#2 got), got = want) end

  fun editing () =
    (is ("typing", typed "hello", ("hello", 5));
     is ("Ctrl-A and typing", typed "world" @ [ctrl #"a"] @ typed "hello ", ("hello world", 6));
     is ("Ctrl-E", typed "ab" @ [ctrl #"a", ctrl #"e"], ("ab", 2));
     is ("Left and Right", typed "abc" @ [key Key.Left, key Key.Left, key Key.Right], ("abc", 2));
     is ("Backspace", typed "abc" @ [key Key.Backspace], ("ab", 2));
     is ("Delete", typed "abc" @ [ctrl #"a", key Key.Delete], ("bc", 0));
     is ("by cluster", typed "e\204\129x" @ [key Key.Left, key Key.Left, key Key.Delete], ("x", 0));
     is ("words", typed "val x = 1" @ [alt #"b", alt #"b"], ("val x = 1", 4));
     is ("Alt-F", typed "val x = 1" @ [ctrl #"a", alt #"f"], ("val x = 1", 3));
     is ("Ctrl-K and Ctrl-Y", typed "abc def" @ [alt #"b", ctrl #"k", ctrl #"a", ctrl #"y"], ("defabc ", 3));
     is ("kills join", typed "a b c" @ [ctrl #"w", ctrl #"w", ctrl #"y"], ("a b c", 5));
     is ("Alt-Y", typed "one two" @ [ctrl #"w"] @ typed "x " @ [ctrl #"w", ctrl #"w", ctrl #"y", alt #"y"],
         ("two", 3));
     is ("Ctrl-U", typed "abc" @ [key Key.Left, ctrl #"u"], ("c", 0));
     is ("Ctrl-T", typed "ab" @ [ctrl #"t"], ("ba", 2));
     is ("Alt-U", typed "abc def" @ [ctrl #"a", alt #"u"], ("ABC def", 3));
     is ("Alt-C", typed "abc def" @ [ctrl #"a", alt #"c", alt #"c"], ("Abc Def", 7));
     is ("undo groups a word", typed "abc def" @ [ctrl #"_"], ("abc ", 4));
     is ("undo a kill", typed "abc" @ [ctrl #"a", ctrl #"k", ctrl #"_"], ("abc", 0));
     is ("a paste", [Key.Paste "a\r\nb\rc"], ("a\nb\nc", 5));
     is ("Alt-Enter", typed "a" @ [Key.Named (Key.Enter, {shift = false, alt = true, ctrl = false})] @ typed "b",
         ("a\nb", 3));
     is ("lines", typed "ab" @ [ctrl #"j"] @ typed "cd" @ [key Key.Up, ctrl #"e"], ("ab\ncd", 2));
     is ("indentation kept", typed "  a" @ [ctrl #"j"] @ typed "b", ("  a\n  b", 7));
     is ("control characters", [ctrl #"v"], ("", 0)))

  fun outcomes () =
    let
      val incomplete = {prompt = "- ", continuation = "= ", isComplete = fn t => String.isSuffix ";" t,
                        complete = #complete L.defaults, hint = #hint L.defaults, highlight = #highlight L.defaults,
                        styles = #styles L.defaults, bindings = #bindings L.defaults,
                        escapeTimeout = #escapeTimeout L.defaults, policy = #policy L.defaults, basic = false, keys = L.Emacs}
      fun outcome (c, es) = #2 (run (c, [], es))
    in
      check ("Enter accepts", outcome (L.defaults, typed "1" @ [key Key.Enter]) = L.Accept "1");
      check ("Enter continues", outcome (incomplete, typed "1" @ [key Key.Enter]) = L.Continue
                                andalso #1 (result (incomplete, [], typed "1" @ [key Key.Enter])) = "1\n");
      check ("Enter accepts when complete", outcome (incomplete, typed "1" @ [key Key.Enter] @ typed ";" @ [key Key.Enter])
                                            = L.Accept "1\n;");
      check ("Ctrl-D on nothing", outcome (L.defaults, [ctrl #"d"]) = L.EndOfInput);
      check ("Ctrl-D on something", outcome (L.defaults, typed "a" @ [ctrl #"a", ctrl #"d"]) = L.Continue);
      check ("Ctrl-C", outcome (L.defaults, typed "a" @ [ctrl #"c"]) = L.Cancelled);
      check ("Ctrl-L", outcome (L.defaults, [ctrl #"l"]) = L.Clear);
      check ("Ctrl-Z", outcome (L.defaults, [ctrl #"z"]) = L.Stop)
    end

  fun history () =
    let
      val h = ["val a = 1;", "fun f x = x;", "val b = 2;"]
      fun r es = #1 (result (L.defaults, h, es))
    in
      check ("Up", r [key Key.Up] = "val b = 2;");
      check ("Up Up", r [key Key.Up, key Key.Up] = "fun f x = x;");
      check ("Up Up Down", r [key Key.Up, key Key.Up, key Key.Down] = "val b = 2;");
      check ("back to what was typed", r (typed "v" @ [key Key.Up, key Key.Down]) = "v");
      check ("by prefix", r (typed "val" @ [key Key.Up, key Key.Up]) = "val a = 1;");
      check ("Alt-<", r [alt #"<"] = "val a = 1;");
      check ("Ctrl-R", r ([ctrl #"r"] @ typed "f x") = "fun f x = x;");
      check ("Ctrl-R again", r ([ctrl #"r"] @ typed "val" @ [ctrl #"r"]) = "val a = 1;");
      check ("Ctrl-G gives back", r (typed "q" @ [ctrl #"r"] @ typed "fun" @ [ctrl #"g"]) = "q");
      check ("a key ends the search", r ([ctrl #"r"] @ typed "fun" @ [ctrl #"e"] @ typed "!") = "fun f x = x;!");
      check ("Enter accepts the match", #2 (run (L.defaults, h, [ctrl #"r"] @ typed "a =" @ [key Key.Enter]))
                                        = L.Accept "val a = 1;");
      (* the fuzzy menu: the characters in order, the best first *)
      check ("Down takes the menu's best", r ([ctrl #"r"] @ typed "fx" @ [key Key.Down]) = "fun f x = x;");
      check ("Down Down the next", r ([ctrl #"r"] @ typed "vl" @ [key Key.Down, key Key.Down]) = "val a = 1;");
      check ("Up back to the first", r ([ctrl #"r"] @ typed "vl" @ [key Key.Down, key Key.Down, key Key.Up]) = "val b = 2;");
      check ("Enter accepts the menu's", #2 (run (L.defaults, h, [ctrl #"r"] @ typed "fx" @ [key Key.Down, key Key.Enter]))
                                         = L.Accept "fun f x = x;");
      let
        val (s, _) = run (L.defaults, h, [ctrl #"r"] @ typed "va")
        val {rows, ...} = L.layout (L.defaults, s, 40)
        fun rowText r = String.concat (List.map #text (Vector.sub (rows, r)))
      in
        check ("the menu drawn", Vector.length rows = 4 andalso rowText 2 = "  val b = 2;" andalso rowText 3 = "  val a = 1;")
      end
    end

  fun completion () =
    let
      val words = ["print", "printLength", "println", "real"]
      fun complete (t, i) =
        let
          fun start j = if j > 0 andalso Char.isAlpha (String.sub (t, j - 1)) then start (j - 1) else j
          val st = start i
          val w = String.substring (t, st, i - st)
        in
          {start = st, candidates = List.filter (String.isPrefix w) words}
        end
      val c = {prompt = "> ", continuation = "  ", isComplete = fn _ => true, complete = complete,
               hint = fn t => if t = "pri" then SOME "nt" else NONE, highlight = #highlight L.defaults,
               styles = #styles L.defaults, bindings = #bindings L.defaults,
               escapeTimeout = #escapeTimeout L.defaults, policy = #policy L.defaults, basic = false, keys = L.Emacs}
      fun r es = #1 (result (c, [], es))
      val (s, _) = run (c, [], typed "pr" @ [key Key.Tab, key Key.Tab, key Key.Tab])
      val f = L.layout (c, s, 40)
      fun rowText k = String.concat (map #text (Vector.sub (#rows f, k)))
    in
      check ("the common prefix", r (typed "pr" @ [key Key.Tab]) = "print");
      check ("one", r (typed "re" @ [key Key.Tab]) = "real");
      check ("the menu", Vector.length (#rows f) = 2 andalso String.isPrefix "print" (rowText 1)
                         andalso String.isSubstring "println" (rowText 1));
      check ("the hint, accepted", r (typed "pri" @ [key Key.Right]) = "print")
    end

  (* a line that moves to another place is laid out with that place's
     prompt, though its text did not change *)
  fun prompts () =
    let
      val c = {prompt = "> ", continuation = ". ", isComplete = fn _ => false, complete = #complete L.defaults,
               hint = #hint L.defaults, highlight = #highlight L.defaults, styles = #styles L.defaults,
               bindings = #bindings L.defaults, escapeTimeout = #escapeTimeout L.defaults, policy = #policy L.defaults,
               basic = false, keys = L.Emacs}
      val (s, _) = run (c, [], typed "abc")
      val _ = L.layout (c, s, 20)
      val (s, _) = L.step (c, s, ctrl #"a")
      val _ = L.layout (c, s, 20)
      val (s, _) = L.step (c, s, ctrl #"j")
      (* the cursor off the moved line, which is then not laid out afresh *)
      val (s, _) = L.step (c, s, key Key.Up)
      val f = L.layout (c, s, 20)
      fun rowText k = String.concat (map #text (Vector.sub (#rows f, k)))
    in
      check ("a line moved down takes the continuation", rowText 0 = ">" andalso rowText 1 = ". abc")
    end

  (* --- the property --- *)

  fun rowOf (screen, i) = Emulator.row (screen, i)

  (* a random key of those that edit *)
  fun drawKey g =
    let
      val keys = Vector.fromList
        ([key Key.Left, key Key.Right, key Key.Up, key Key.Down, key Key.Backspace, key Key.Delete, key Key.Home,
          key Key.End, ctrl #"a", ctrl #"e", ctrl #"k", ctrl #"u", ctrl #"w", ctrl #"y", ctrl #"t", ctrl #"_",
          ctrl #"j", alt #"b", alt #"f", alt #"d", alt #"u", Key.Paste "pasted\ttext\nover lines"]
         @ map ch (explode "abcdefghij  xyz;()[]")
         @ map (fn c => Key.Char (c, none)) [0xE9, 0x4E2D, 0x6587, 0x1F600, 0x301, 0xFF21])
      val (i, g) = Random.int (0, Vector.length keys - 1) g
    in
      (Vector.sub (keys, i), g)
    end

  fun property () =
    let
      (* what each trial that failed showed *)
      val report : string list ref = ref []
      fun one (g, trial) =
        let
          val (columns, g) = Random.int (4, 30) g
          val (n, g) = Random.int (1, 60) g
          val config = {prompt = "\206\187> ", continuation = ". ", isComplete = fn _ => false,
                        complete = #complete L.defaults, hint = #hint L.defaults,
                        highlight = fn t => if size t > 3 then [(1, 3, Style.parameters "1;31")] else [],
                        styles = #styles L.defaults, bindings = #bindings L.defaults,
                        escapeTimeout = #escapeTimeout L.defaults, policy = Grapheme.ByCluster, basic = false, keys = L.Emacs}
          fun go (0, _, _, _, _, g) = (true, g)
            | go (k, s, screen, frame, drawn, g) =
                let
                  val (e, g) = drawKey g
                  val (s, _) = L.step (config, s, e)
                  val after = L.layout (config, s, columns)
                in
                  if Vector.length (#rows after) > 40 then (true, g)
                  else
                    let
                      val (bytes, drawn) = L.diff {old = SOME frame, new = after, columns = columns, drawn = drawn}
                      val screen = Emulator.write (screen, bytes)
                      val rowsOk = List.all (fn i => rowOf (screen, i) = Vector.sub (#rows after, i))
                                            (List.tabulate (Vector.length (#rows after), fn i => i))
                      val below = List.all (fn i => rowOf (screen, i) = [])
                                           (List.tabulate (50 - Vector.length (#rows after), fn i => i + Vector.length (#rows after)))
                      val cursorOk = Emulator.cursor screen = #cursor after
                    in
                      if rowsOk andalso below andalso cursorOk then go (k - 1, s, screen, after, drawn, g)
                      else
                        (report := ("trial " ^ Int.toString trial ^ " at width " ^ Int.toString columns ^ " after "
                                    ^ Key.toString e ^ ": " ^ String.toString (L.text s) ^ "\nscreen:\n"
                                    ^ Emulator.text screen) :: !report;
                         (false, g))
                    end
                end
          val s = L.start (Vector.fromList [], "")
          val first = L.layout (config, s, columns)
          val (bytes, drawn) = L.diff {old = NONE, new = first, columns = columns, drawn = 1}
          val screen = Emulator.write (Emulator.new {columns = columns, rows = 50, policy = Grapheme.ByCluster}, bytes)
        in
          go (n, s, screen, first, drawn, g)
        end
      fun trials (0, _, ok) = ok
        | trials (k, g, ok) = let val (ok', g) = one (g, k) in trials (k - 1, g, ok andalso ok') end
      val ok = trials (300, Random.fromSeed 0w23, true)
    in
      check (String.concatWith "\n" ("what diff writes, the emulator shows" :: rev (!report)), ok)
    end

  (* zsh's PROMPT_SP, as readLine writes it: on a line of its own the mark
     is overwritten, after an unfinished one it stays; after a line that
     fills the width exactly the prompt is on a line of its own, without
     the mark *)
  fun promptMark () =
    let
      val markBytes = "\027[0;7m%\027[0m" ^ CharVector.tabulate (9, fn _ => #" ") ^ "\r\027[K"
      fun after s = Emulator.text (Emulator.write (Emulator.new {columns = 10, rows = 4, policy = Grapheme.ByCluster},
                                                   s ^ markBytes ^ "> "))
    in
      check ("the mark on a fresh line", after "" = ">");
      check ("the mark after an unfinished line", after "out" = "out%\n>");
      check ("the mark after a full line", after "0123456789" = "0123456789\n>")
    end

  (* Vi's modes: Escape to the normal mode, its motions, operators and
     commands, and back to inserting; what the text and the cursor are *)
  fun vi () =
    let
      val c = {prompt = "> ", continuation = "  ", isComplete = fn _ => true, complete = #complete L.defaults,
               hint = #hint L.defaults, highlight = #highlight L.defaults, styles = #styles L.defaults,
               bindings = #bindings L.defaults, escapeTimeout = #escapeTimeout L.defaults, policy = #policy L.defaults,
               basic = false, keys = L.Vi}
      val esc = key Key.Escape
      fun v (name, events, want) =
        let val (s, _) = run (c, ["first entry"], events)
            val got = (L.text s, L.cursor s)
        in check ("vi " ^ name ^ ": " ^ String.toString (#1 got) ^ " at " ^ Int.toString (#2 got), got = want) end
      fun mode (name, events, want) = check ("vi mode " ^ name, L.normal (#1 (run (c, [], events))) = want)
    in
      mode ("inserting at first", typed "a", false);
      mode ("Escape to normal", typed "a" @ [esc], true);
      mode ("i back to inserting", typed "a" @ [esc] @ typed "i", false);
      v ("Escape moves back", typed "hello" @ [esc], ("hello", 4));
      v ("x", typed "hello" @ [esc] @ typed "x", ("hell", 3));
      v ("h and l", typed "abc" @ [esc] @ typed "hhl", ("abc", 1));
      v ("0 and $", typed "abc def" @ [esc] @ typed "0$", ("abc def", 6));
      v ("^", typed "  abc" @ [esc] @ typed "0^", ("  abc", 2));
      v ("w and b", typed "one two three" @ [esc] @ typed "0ww", ("one two three", 8));
      v ("b", typed "one two three" @ [esc] @ typed "bb", ("one two three", 4));
      v ("e", typed "one two" @ [esc] @ typed "0e", ("one two", 2));
      v ("dw", typed "one two three" @ [esc] @ typed "0dw", ("two three", 0));
      v ("a count", typed "a b c d" @ [esc] @ typed "02dw", ("c d", 0));
      v ("a count after the operator", typed "a b c d" @ [esc] @ typed "0d2w", ("c d", 0));
      v ("cw", typed "one two" @ [esc] @ typed "0cwONE", ("ONE two", 3));
      v ("cw on a word of one letter", typed "val x = 1" @ [esc] @ typed "0wcwy", ("val y = 1", 5));
      v ("de", typed "foo bar" @ [esc] @ typed "0de", (" bar", 0));
      v ("d$ and D", typed "abc def" @ [esc] @ typed "0wD", ("abc ", 3));
      v ("C", typed "abc def" @ [esc] @ typed "0wCxyz", ("abc xyz", 7));
      v ("dd", typed "line" @ [esc] @ typed "dd", ("", 0));
      v ("cc", typed "line" @ [esc] @ typed "ccnew", ("new", 3));
      v ("A", typed "ab" @ [esc] @ typed "0Acd", ("abcd", 4));
      v ("I", typed "  ab" @ [esc] @ typed "Ix", ("  xab", 3));
      v ("a", typed "ac" @ [esc] @ typed "0ab", ("abc", 2));
      v ("x then p", typed "abc" @ [esc] @ typed "0xp", ("bac", 1));
      v ("P", typed "abc" @ [esc] @ typed "0xlP", ("bac", 1));
      v ("yy and p, line by line", typed "one" @ [esc] @ typed "yyp", ("one\none", 4));
      v ("o", typed "one" @ [esc] @ typed "otwo", ("one\ntwo", 7));
      v ("O", typed "two" @ [esc] @ typed "Oone", ("one\ntwo", 3));
      v ("r", typed "abc" @ [esc] @ typed "0rz", ("zbc", 0));
      v ("~", typed "abc" @ [esc] @ typed "0~~", ("ABc", 2));
      v ("u", typed "abc" @ [esc] @ typed "0xu", ("abc", 0));
      v ("s", typed "abc" @ [esc] @ typed "0sX", ("Xbc", 1));
      v ("k into the history", typed "x" @ [esc] @ typed "k", ("first entry", 10));
      v ("gg and G", typed "a" @ [ctrl #"j"] @ typed "b" @ [esc] @ typed "gg", ("a\nb", 0));
      v ("Escape in the normal mode does nothing", typed "ab" @ [esc, esc], ("ab", 1))
    end

  val tests =
    Test.describe "terminal/edit"
      [Test.it "vi" vi, Test.it "editing" editing, Test.it "outcomes" outcomes, Test.it "history" history,
       Test.it "completion" completion, Test.it "prompts" prompts, Test.it "property" property,
       Test.it "prompt-mark" promptMark]
end

structure EditMain = Main (struct val name = "terminal/edit" val tests = EditTest.tests end)
val () = EditMain.main ()
