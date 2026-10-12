(* libraries: test/unit *)
(* What the line editor asks of the terminal at its first read
   (docs/plans/repl.md, D9 and M13): the editor over a terminal of script --
   a device whose reads are given and whose writes are kept -- answered as
   a terminal that draws a cluster whole and speaks the kitty keyboard
   protocol, and as one that draws each code point. *)
functor Scripted (val answers : string list) =
struct
  structure Device =
  struct
    val reads = ref answers
    val written = ref ""
    val undone = ref ""
    fun available () = true
    fun size () = {columns = 80, rows = 24}
    fun resizes () = 0
    fun enter {undo} = undone := undo
    fun quiet () = undone := ""
    fun leave () = written := !written ^ !undone
    fun read _ = case !reads of [] => NONE | r :: rest => (reads := rest; SOME r)
    fun write s = written := !written ^ s
    fun policy () = Grapheme.ByCluster
  end
  structure L = LineEditFn (structure Device = Device)
end

structure ProbeTest =
struct
  val check = Expect.that
  fun has (s, sub) = String.isSubstring sub s

  structure K = Scripted (val answers = ["\027[1;3R", "\027[?0u", "\027[?62;22c", "abc", "\r", "x", "\r"])
  structure P = Scripted (val answers = ["\027[1;7R\027[?62;22c", "abc\r"])

  (* the terminal that draws a cluster whole and speaks the kitty protocol:
     two reads *)
  fun byCluster () =
    let
      val first = K.L.readLine (K.L.defaults, NONE)
      val afterFirst = !K.Device.written
      val () = K.Device.written := ""
      val second = K.L.readLine (K.L.defaults, NONE)
    in
      check ("the first read is the line", first = K.L.Line "abc");
      check ("the probe asked once", has (afterFirst, "\027[6n") andalso has (afterFirst, "\027[?u")
                                     andalso not (has (!K.Device.written, "\027[6n")));
      check ("measured by cluster", #policy (K.L.terminal ()) = SOME Grapheme.ByCluster);
      check ("kitty spoken", #kitty (K.L.terminal ()));
      check ("not on at the first read", not (has (afterFirst, "\027[>1u")));
      check ("the second read", second = K.L.Line "x");
      check ("on at the second, and off at its end", has (!K.Device.written, "\027[>1u")
                                                      andalso String.isSuffix "\027[<u" (!K.Device.written))
    end

  (* the terminal that draws each code point *)
  fun byCodePoint () =
    let val p = P.L.readLine (P.L.defaults, NONE)
    in
      check ("the other terminal's line", p = P.L.Line "abc");
      check ("measured by code point", #policy (P.L.terminal ()) = SOME Grapheme.ByCodePoint);
      check ("no kitty there", not (#kitty (P.L.terminal ())))
    end

  val probes = Test.describe "terminal/probe" [Test.it "by-cluster" byCluster, Test.it "by-code-point" byCodePoint]

  (* in the basic mode the editor asks nothing: the tests are listed, not
     run, and one test that passes says so, as the old program's PASS line
     did, so that a run under TERM=dumb still passes *)
  val tests =
    if K.L.basic K.L.defaults then
      Test.describe "" [Test.it "basic-mode" (fn () => ()), Test.pending "the basic mode (TERM)" probes]
    else probes
end

structure ProbeMain = Main (struct val name = "terminal/probe" val tests = ProbeTest.tests end)
val () = ProbeMain.main ()
