(* libraries: test/unit *)
(* What the terminal is when the line editor announces its prompt
   (LineEdit.beforePrompt, where the REPL sends OSC 133's A) and after it
   has read: the editor over a terminal of script -- a device whose reads
   are given and whose writes are kept -- that knows whether it is cooked,
   raw or quiet. A key typed as soon as the prompt is announced is the
   editor's only if the terminal is raw by then: still cooked, the key is
   echoed and a return is made a newline before the editor reads it
   (tests/terminal/repl-marks.pty). *)
functor Moded (val answers : string list) =
struct
  datatype mode = Cooked | Raw | Quiet
  structure Device =
  struct
    val mode = ref Cooked
    val reads = ref answers
    val written = ref ""
    val undone = ref ""
    fun available () = true
    fun size () = {columns = 80, rows = 24}
    fun resizes () = 0
    fun enter {undo} = (mode := Raw; undone := undo)
    fun quiet () = (mode := Quiet; undone := "")
    fun leave () = (written := !written ^ !undone; undone := ""; mode := Cooked)
    fun read _ = case !reads of [] => NONE | r :: rest => (reads := rest; SOME r)
    fun write s = written := !written ^ s
    fun policy () = Grapheme.ByCluster
  end
  structure L = LineEditFn (structure Device = Device)
  (* the terminal's mode and what had been written, at each announcement *)
  val announced : (mode * string) list ref = ref []
  val () = L.beforePrompt := (fn () => announced := !announced @ [(!Device.mode, !Device.written)])
end

structure PromptTest =
struct
  val check = Expect.that
  fun has (s, sub) = String.isSubstring sub s

  structure A = Moded (val answers = ["abc\r", "x\r"])
  structure B = Moded (val answers = ["\003", "abc\r"])
  structure C = Moded (val answers = [])
  structure D = Moded (val answers = ["abc\r"])

  (* announced at every read once the terminal is raw and bracketed paste
     is on, before the prompt is drawn; quiet after a line the caller asked
     to keep so (the REPL) *)
  fun raw () =
    let
      val () = A.L.keepRaw := true
      val first = A.L.readLine (A.L.defaults, NONE)
      val afterFirst = !A.Device.mode
      val second = A.L.readLine (A.L.defaults, NONE)
    in
      check ("the lines", first = A.L.Line "abc" andalso second = A.L.Line "x");
      check ("announced at each read", length (!A.announced) = 2);
      check ("raw at each announcement", List.all (fn (m, _) => m = A.Raw) (!A.announced));
      check ("bracketed paste on before it", List.all (fn (_, w) => has (w, "\027[?2004h")) (!A.announced));
      check ("no prompt drawn before the first", not (has (#2 (hd (!A.announced)), "\027[?2026h")));
      check ("quiet after a line kept so", afterFirst = A.Quiet andalso !A.Device.mode = A.Quiet);
      check ("bracketed paste off before quiet", String.isSuffix "\027[?2004l" (!A.Device.written))
    end

  (* put back after an interrupt, at the end of the input, and after a line
     read without keepRaw *)
  fun back () =
    let
      val interrupted = B.L.readLine (B.L.defaults, NONE)
      val afterInterrupt = !B.Device.mode
      val line = B.L.readLine (B.L.defaults, NONE)
      val ended = (C.L.keepRaw := true; C.L.readLine (C.L.defaults, NONE))
    in
      check ("interrupted", interrupted = B.L.Interrupted);
      check ("raw at the announcement", List.all (fn (m, _) => m = B.Raw) (!B.announced));
      check ("back after the interrupt", afterInterrupt = B.Cooked);
      check ("back after a line without keepRaw", line = B.L.Line "abc" andalso !B.Device.mode = B.Cooked);
      check ("the end of the input", ended = C.L.End);
      check ("back at the end, though kept", !C.Device.mode = C.Cooked)
    end

  (* an announcement that fails puts the terminal back *)
  fun failing () =
    let
      val () = D.L.beforePrompt := (fn () => raise Fail "announce")
      val raised = (ignore (D.L.readLine (D.L.defaults, NONE)); false) handle Fail _ => true
    in
      check ("the failure passes through", raised);
      check ("back after it", !D.Device.mode = D.Cooked)
    end

  val prompts =
    Test.describe "terminal/prompt"
      [Test.it "raw-at-the-announcement" raw, Test.it "put-back" back, Test.it "failing-announcement" failing]

  (* in the basic mode the editor announces nothing, as in probe.sml *)
  val tests =
    if A.L.basic A.L.defaults then
      Test.describe "" [Test.it "basic-mode" (fn () => ()), Test.pending "the basic mode (TERM)" prompts]
    else prompts
end

structure PromptMain = Main (struct val name = "terminal/prompt" val tests = PromptTest.tests end)
val () = PromptMain.main ()
