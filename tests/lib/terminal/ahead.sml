(* libraries: test/unit *)
(* Keys typed ahead (docs/repl.md, While a declaration runs): the line
   editor over a terminal of script -- a device whose reads are given and
   whose writes are kept -- given in one read the key that ends a line
   and the keys typed after it, as a terminal gives them to a program
   that was busy. They are the next readLine's, in order, and the
   beginning of a key that the read cut is finished by the next read;
   none is lost (tests/terminal/repl-ahead.pty). *)
functor Typed (val answers : string list) =
struct
  structure Device =
  struct
    val reads = ref answers
    val written = ref ""
    fun available () = true
    fun size () = {columns = 80, rows = 24}
    fun resizes () = 0
    fun enter _ = ()
    fun quiet () = ()
    fun leave () = ()
    fun read _ = case !reads of [] => NONE | r :: rest => (reads := rest; SOME r)
    fun write s = written := !written ^ s
    fun policy () = Grapheme.ByCluster
  end
  structure L = LineEditFn (structure Device = Device)
  fun lines n = List.tabulate (n, fn _ => L.readLine (L.defaults, NONE))
end

structure AheadTest =
struct
  val check = Expect.that

  structure A = Typed (val answers = ["abc\rxy\r"])
  structure B = Typed (val answers = ["\003abc\r"])
  structure C = Typed (val answers = ["a\r\027[", "Dx\r"])
  structure D = Typed (val answers = ["one\rtwo\rthree\r", "four\r"])

  (* the next line in the read that ended a line *)
  fun nextLine () =
    check ("both lines, then the end", A.lines 3 = [A.L.Line "abc", A.L.Line "xy", A.L.End])

  (* the keys after Ctrl-C are the next prompt's *)
  fun afterInterrupt () =
    check ("interrupted, then the line", B.lines 2 = [B.L.Interrupted, B.L.Line "abc"])

  (* a key the read cut: Left, its escape sequence begun after the line *)
  fun cutKey () =
    check ("Left, not the letters of its sequence", C.lines 2 = [C.L.Line "a", C.L.Line "x"])

  (* several lines in one read, then a read of its own *)
  fun several () =
    check ("every line in order",
           D.lines 5 = [D.L.Line "one", D.L.Line "two", D.L.Line "three", D.L.Line "four", D.L.End])

  val ahead =
    Test.describe "terminal/ahead"
      [Test.it "next-line" nextLine, Test.it "after-an-interrupt" afterInterrupt, Test.it "a-key-cut" cutKey,
       Test.it "several-lines" several]

  (* in the basic mode the editor reads by lines, as in probe.sml *)
  val tests =
    if A.L.basic A.L.defaults then
      Test.describe "" [Test.it "basic-mode" (fn () => ()), Test.pending "the basic mode (TERM)" ahead]
    else ahead
end

structure AheadMain = Main (struct val name = "terminal/ahead" val tests = AheadTest.tests end)
val () = AheadMain.main ()
