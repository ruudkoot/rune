(* libraries: test/unit random *)
(* Key: what streams of bytes decode to, whole and split at every place and
   at random places, so that a key whose bytes come in two reads is the
   same key; what flush makes of what is pending. *)
structure KeyTest =
struct
  val check = Expect.that

  open Key
  val ctrl = {shift = false, alt = false, ctrl = true}
  val alt = {shift = false, alt = true, ctrl = false}
  val shift = {shift = true, alt = false, ctrl = false}
  fun m (s, a, c) = {shift = s, alt = a, ctrl = c}
  fun ch c = Char (Char.ord c, none)

  (* streams and the keys they are, with nothing pending at the end *)
  val cases = [
    ("a", [ch #"a"]),
    ("abc", [ch #"a", ch #"b", ch #"c"]),
    ("\195\169", [Char (0xE9, none)]),
    ("\240\159\152\128", [Char (0x1F600, none)]),
    ("\001\005\011\023\031\000\028\029", [Char (97, ctrl), Char (101, ctrl), Char (107, ctrl), Char (119, ctrl),
                                         Char (95, ctrl), Char (64, ctrl), Char (92, ctrl), Char (93, ctrl)]),
    ("\r\t\127\b\n", [Named (Enter, none), Named (Tab, none), Named (Backspace, none), Named (Backspace, ctrl),
                     Char (106, ctrl)]),
    ("\027[A\027[B\027[C\027[D\027[H\027[F", [Named (Up, none), Named (Down, none), Named (Right, none), Named (Left, none),
                                              Named (Home, none), Named (End, none)]),
    ("\027OA\027OP\027OQ\027OR\027OS\027OH\027OM", [Named (Up, none), Named (F 1, none), Named (F 2, none), Named (F 3, none),
                                                    Named (F 4, none), Named (Home, none), Named (Enter, none)]),
    ("\027[1;5C\027[1;3D\027[1;2A\027[1;8B", [Named (Right, ctrl), Named (Left, alt), Named (Up, shift),
                                              Named (Down, m (true, true, true))]),
    ("\027[2~\027[3~\027[5~\027[6~\027[1~\027[4~\027[3;5~", [Named (Insert, none), Named (Delete, none),
                                                            Named (PageUp, none), Named (PageDown, none), Named (Home, none),
                                                            Named (End, none), Named (Delete, ctrl)]),
    ("\027[15~\027[17~\027[24~\027[1;2P", [Named (F 5, none), Named (F 6, none), Named (F 12, none), Named (F 1, shift)]),
    ("\027[Z", [Named (Tab, shift)]),
    ("\027b\027f\027\127\027\195\169", [Char (98, alt), Char (102, alt), Named (Backspace, alt), Char (0xE9, alt)]),
    ("\027\001", [Char (97, m (false, true, true))]),
    ("\027[200~hello\r\nworld\027[201~x", [Paste "hello\r\nworld", ch #"x"]),
    ("\027[200~\027[A\027[201~", [Paste "\027[A"]),
    ("\027[12;40R", [CursorAt (12, 40)]),
    ("\027[?62;22c\027[?1u", [Reply "\027[?62;22c", Reply "\027[?1u"]),
    ("\027[I\027[O", [Focus true, Focus false]),
    ("\027[99;5u\027[13;2u\027[97;5u", [Char (99, ctrl), Named (Enter, shift), Char (97, ctrl)]),
    ("\027[27;5;105~", [Char (105, ctrl)]),
    ("\027[9999z\027[1$x", [Unknown "\027[9999z", Unknown "\027[1$x"]),
    ("\027\027[A", [Named (Escape, none), Named (Up, none)]),
    ("\255a\192\128", [Char (0xFFFD, none), ch #"a", Char (0xFFFD, none), Char (0xFFFD, none)])]

  fun decodeAll parts =
    let
      fun go ([], d, acc) = (acc, d)
        | go (p :: ps, d, acc) = let val (es, d) = feed (d, p) in go (ps, d, acc @ es) end
      val (es, d) = go (parts, empty, [])
    in
      if pending d then es @ #1 (flush d) else es
    end

  fun show es = String.concatWith " " (map toString es)

  fun whole () =
    List.app (fn (s, want) =>
                let val got = decodeAll [s]
                in check ("decodes " ^ String.toString s ^ ": " ^ show got, got = want) end) cases

  (* every split of every stream into two reads, and into one read a byte *)
  fun splits () =
    List.app (fn (s, want) =>
                let
                  fun at i = decodeAll [String.substring (s, 0, i), String.extract (s, i, NONE)]
                  fun all i = i > size s orelse (at i = want andalso all (i + 1))
                  val bytes = decodeAll (map String.str (explode s))
                in
                  check ("every split of " ^ String.toString s, all 0);
                  check ("a byte a read of " ^ String.toString s ^ ": " ^ show bytes, bytes = want)
                end) cases

  (* random streams of the cases' pieces, split at random *)
  fun random () =
    let
      val pieces = Vector.fromList cases
      fun streamOf (0, g, s, want) = (s, want, g)
        | streamOf (k, g, s, want) =
            let
              val (i, g) = Random.int (0, Vector.length pieces - 1) g
              val (s', want') = Vector.sub (pieces, i)
            in
              (* a stream that ends with an Escape alone waits for the
                 next piece, whose bytes may join it: those stay last *)
              streamOf (k - 1, g, s ^ s', want @ want')
            end
      fun cut (s, g) =
        if s = "" then ([], g)
        else
          let
            val (n, g) = Random.int (1, Int.min (size s, 9)) g
            val (rest, g) = cut (String.extract (s, n, NONE), g)
          in
            (String.substring (s, 0, n) :: rest, g)
          end
      fun go (0, _) = true
        | go (k, g) =
            let
              val (s, want, g) = streamOf (5, g, "", [])
              val (parts, g) = cut (s, g)
            in
              decodeAll parts = want andalso go (k - 1, g)
            end
    in
      check ("random streams in random reads", go (2000, Random.fromSeed 0w1966))
    end

  fun pendingAndFlush () =
    let
      fun after s = #1 (flush (#2 (feed (empty, s))))
    in
      check ("Escape alone", after "\027" = [Named (Escape, none)]);
      check ("Escape [ alone", after "\027[" = [Char (Char.ord #"[", alt)]);
      check ("Escape O alone", after "\027O" = [Char (Char.ord #"O", alt)]);
      check ("a CSI not ended", after "\027[1;5" = [Unknown "\027[1;5"]);
      check ("UTF-8 not ended", after "\226\130" = [Char (0xFFFD, none)]);
      check ("a paste not ended", after "\027[200~abc\027[20" = [Paste "abc\027[20"]);
      check ("pending", pending (#2 (feed (empty, "\027["))) andalso not (pending (#2 (feed (empty, "a")))))
    end

  fun names () =
    (check ("toString", map toString [Char (97, ctrl), Char (98, alt), Named (Up, none), Named (Tab, shift),
                                      Named (F 5, none), Char (32, none), Char (0xE9, none)]
                        = ["C-a", "M-b", "Up", "S-Tab", "F5", "SPC", "\195\169"]))

  val tests =
    Test.describe "terminal/key"
      [Test.it "whole" whole, Test.it "splits" splits, Test.it "random" random,
       Test.it "pending-and-flush" pendingAndFlush, Test.it "names" names]
end

structure KeyMain = Main (struct val name = "terminal/key" val tests = KeyTest.tests end)
val () = KeyMain.main ()
