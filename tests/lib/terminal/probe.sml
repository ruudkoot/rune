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
    fun leave () = written := !written ^ !undone
    fun read _ = case !reads of [] => NONE | r :: rest => (reads := rest; SOME r)
    fun write s = written := !written ^ s
    fun policy () = Grapheme.ByCluster
  end
  structure L = LineEditFn (structure Device = Device)
end

structure ProbeTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))
  fun has (s, sub) = String.isSubstring sub s

  structure K = Scripted (val answers = ["\027[1;3R", "\027[?0u", "\027[?62;22c", "abc", "\r", "x", "\r"])
  structure P = Scripted (val answers = ["\027[1;7R\027[?62;22c", "abc\r"])

  fun main () =
    let
      val basic = K.L.basic K.L.defaults
      val first = if basic then K.L.End else K.L.readLine (K.L.defaults, NONE)
      val afterFirst = !K.Device.written
      val () = K.Device.written := ""
      val second = if basic then K.L.End else K.L.readLine (K.L.defaults, NONE)
      val p = if basic then P.L.End else P.L.readLine (P.L.defaults, NONE)
    in
      if basic then print "SKIP probe: the basic mode (TERM)\n"
      else
        (check ("the first read is the line", first = K.L.Line "abc");
         check ("the probe asked once", has (afterFirst, "\027[6n") andalso has (afterFirst, "\027[?u")
                                        andalso not (has (!K.Device.written, "\027[6n")));
         check ("measured by cluster", #policy (K.L.terminal ()) = SOME Grapheme.ByCluster);
         check ("kitty spoken", #kitty (K.L.terminal ()));
         check ("not on at the first read", not (has (afterFirst, "\027[>1u")));
         check ("the second read", second = K.L.Line "x");
         check ("on at the second, and off at its end", has (!K.Device.written, "\027[>1u")
                                                         andalso String.isSuffix "\027[<u" (!K.Device.written));
         check ("the other terminal's line", p = P.L.Line "abc");
         check ("measured by code point", #policy (P.L.terminal ()) = SOME Grapheme.ByCodePoint);
         check ("no kitty there", not (#kitty (P.L.terminal ()))));
      print ((if !failures = 0 then "PASS" else "FAIL") ^ " probe: " ^ Int.toString (!failures) ^ " failed\n")
    end
end

val () = ProbeTest.main ()
