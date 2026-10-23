(* Timings of the existing newline compiler-service prototype. This is
   deliberately not labelled LSP: it is the independent starting point
   for comparing resident analysis later. Each run owns a private cache. *)
structure LspServiceBaseline =
struct
  exception Failed of string
  fun need (ok, message) = if ok then () else raise Failed message
  fun close fd = Posix.IO.close fd handle OS.SysErr _ => ()
  fun fd fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
  fun integer n = Json.int n
  fun time t = Json.Number (LargeInt.toString (Time.toMicroseconds t))
  fun request id method params = Json.encode (Json.Object
    [("jsonrpc", Json.String "2.0"), ("id", integer id),
     ("method", Json.String method), ("params", params)]) ^ "\n"
  fun send output text =
    let val bytes = Byte.stringToBytes text
        fun loop i = if i = Word8Vector.length bytes then ()
                     else let val n = Posix.IO.writeVec (output, Word8VectorSlice.slice (bytes, i, NONE))
                          in need (n > 0, "service input closed"); loop (i + n) end
    in loop 0 end
  fun line input pending =
    let
      val deadline = Time.+ (Runtime.clock (), Time.fromSeconds 30)
      fun go () =
        case CharVector.findi (fn (_, c) => c = #"\n") (!pending) of
          SOME (i, _) =>
            let val result = String.substring (!pending, 0, i)
            in pending := String.extract (!pending, i + 1, NONE); result end
        | NONE =>
            let val () = need (Time.< (Runtime.clock (), deadline), "service response deadline exceeded")
                val poll = valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD input))
                val ready = OS.IO.poll ([OS.IO.pollIn poll], SOME (Time.fromMilliseconds 50))
            in
              if null ready then go ()
              else let val bytes = Posix.IO.readVec (input, 4096)
                       val () = need (Word8Vector.length bytes > 0, "service ended before its response")
                       val () = pending := !pending ^ Byte.bytesToString bytes
                       val () = need (size (!pending) <= 2 * 1024 * 1024, "service response exceeds the baseline bound")
                   in go () end
            end
    in go () end
  fun run {compiler, output, repetitions, warmup} =
    let
      val source = "val answer = 42\nval result = answer\n"
      val path = OS.Path.mkAbsolute {path = "tests/lsp/fixtures/hover.sml", relativeTo = OS.FileSys.getDir ()}
      val toChild = Posix.IO.pipe ()
      val fromChild = Posix.IO.pipe ()
      val errors = Posix.FileSys.creat (output ^ "/service.stderr",
        Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
      val handles = [#infd toChild, #outfd toChild, #infd fromChild, #outfd fromChild, errors]
      val () = List.app (fn f => Posix.IO.setfd (f, Posix.IO.FD.flags [Posix.IO.FD.cloexec])) handles
      val cache = OS.Path.mkAbsolute {path = output ^ "/prototype-cache", relativeTo = OS.FileSys.getDir ()}
      val start = Runtime.clock ()
      val pid = (Subprocess.spawn {program = compiler, args = [compiler, "--serve", "--cache-dir", cache],
        env = NONE, search = false, dir = NONE, stdin = SOME (fd (#infd toChild)),
        stdout = SOME (fd (#outfd fromChild)), stderr = SOME (fd errors), group = true,
        limits = {addressSpace = NONE, cpuTime = SOME 120, fileSize = SOME (4 * 1024 * 1024), core = SOME 0}}
        handle e => (List.app close handles; raise e))
      val () = List.app close [#infd toChild, #outfd fromChild, errors]
      val pending = ref ""
      val next = ref 0
      val samples = ref [] : Json.value list ref
      val ended = ref false
      fun call method params =
        let val id = !next
            val () = next := id + 1
            val begin = Runtime.clock ()
            val () = send (#outfd toChild) (request id method params)
            val result = Json.decode (line (#infd fromChild) pending)
            val elapsed = Time.- (Runtime.clock (), begin)
            val () = need (Json.member ("id", result) = SOME (integer id), "service response ID differs")
            val () = need (not (isSome (Json.member ("error", result))), "prototype service returned an error")
        in (case Json.member ("result", result) of SOME v => v | NONE => raise Failed "service omitted result", elapsed) end
      fun record phase repetition elapsed = samples := Json.Object
        [("phase", Json.String phase), ("repetition", integer repetition), ("wall_us", time elapsed)] :: !samples
      val params = Json.Object [("files", Json.Array [Json.String path]), ("path", Json.String path),
        ("text", Json.String source), ("offset", integer 29)]
      fun checkDiagnostics result =
        need (Json.member ("diagnostics", result) = SOME (Json.Array []), "valid prototype source has diagnostics")
      fun checkHover result =
        need (Json.member ("name", result) = SOME (Json.String "answer") andalso
              Json.member ("type", result) = SOME (Json.String "int"), "prototype hover does not resolve answer : int")
      fun cleanup () =
        if !ended then ()
        else (ended := true; List.app close handles;
              (Subprocess.kill (pid, Posix.Signal.kill) handle OS.SysErr _ => ());
              ignore (Subprocess.wait (SOME pid)) handle OS.SysErr _ => ())
      fun work () =
        let
          val (initialized, _) = call "initialize" (Json.Object [])
          val () = need (Json.member ("name", initialized) = SOME (Json.String "rune"), "wrong service identity")
          val () = record "startup_initialize" 0 (Time.- (Runtime.clock (), start))
          val (cold, elapsed) = call "diagnostics" params
          val () = checkDiagnostics cold
          val () = record "diagnostics_first_private_cache" 0 elapsed
          fun cycle i =
            let val (diagnostics, dt) = call "diagnostics" params
                val () = checkDiagnostics diagnostics
                val (hover, ht) = call "hover" params
                val () = checkHover hover
            in if i < 0 then () else (record "diagnostics_repeat" i dt; record "hover_repeat" i ht) end
          val () = List.app cycle (List.tabulate (warmup, fn i => ~ (i + 1)))
          val () = List.app cycle (List.tabulate (repetitions, fn i => i))
          val _ = call "shutdown" (Json.Object [])
          val () = List.app close [#outfd toChild, #infd fromChild]
          val result = Subprocess.wait (SOME pid)
          val () = ended := true
          val () = need (#status result = Posix.Process.W_EXITED, "prototype server exited unsuccessfully")
          val summary = Json.Object [("phase", Json.String "waited_process"),
            ("user_us", time (#user result)), ("system_us", time (#system result)),
            ("peak_resident_kb", integer (#peakResident result)),
            ("compiler", Json.String compiler), ("cache", Json.String cache),
            ("meaning", Json.String "newline prototype with a fresh child for each analysis request")]
        in rev (!samples) @ [summary] end
    in work () handle e => (cleanup (); raise e) end
end
