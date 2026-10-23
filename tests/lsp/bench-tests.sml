(* Independent command-level acceptance of the measurement producer. *)
structure LspBenchTests =
struct
  open Sh
  exception Failed of string
  fun need (ok, message) = if ok then () else raise Failed message
  val stem = run ^ "/lsp-bench-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  val dir =
    let val () = mkdirs run
        fun create n =
          let val path = stem ^ "-" ^ Int.toString n
          in (OS.FileSys.mkDir path; path)
             handle e as OS.SysErr _ => if exists path then create (n + 1) else raise e end
    in create 0 end
  fun json path value = write (path, Json.encode value ^ "\n")
  fun member (key, value) = case Json.member (key, value) of SOME x => x | NONE => raise Failed ("missing " ^ key)
  fun invoke name args =
    let val out = dir ^ "/" ^ name ^ ".stdout"
        val err = dir ^ "/" ^ name ^ ".stderr"
        val status = exec {cmd = fromRoot "bin/rune-lsp-bench" :: args, dir = SOME root,
                           stdin = "", stdout = out, stderr = err, timeout = 120}
    in (status, read out, read err) end
  fun main () =
    let
      val () = mkdirs dir
      val source = fromRoot "tests/lsp/fixtures/small.sml"
      val manifest = dir ^ "/fixtures.json"
      val fixture = Json.Object [("name", Json.String "small"), ("mode", Json.String "ascii"),
        ("files", Json.Array [Json.String source]), ("accepted", Json.Bool true),
        ("edits", Json.Array [Json.Object [("start", Json.int 0), ("stop", Json.int 0),
                  ("text", Json.String "(* edit *)\n"), ("accepted", Json.Bool true)]])]
      fun spec fixture = Json.Object [("version", Json.int 1), ("fixtures", Json.Array [fixture])]
      val () = json manifest (spec fixture)
      val output = dir ^ "/accepted"
      val args = ["--manifest", manifest, "--out", output, "--repetitions", "2", "--warmup", "1"]
      val (status, _, errors) = invoke "accepted" args
      val () = need (status = 0, "valid measurement failed: " ^ errors)
      val samples = List.map Json.decode (lines (read (output ^ "/samples.jsonl")))
      val () = need (length samples = 10, "warmup leaked into measured samples or a phase was omitted")
      val () = List.app (fn row =>
        let val rep = valOf (Json.toInt (member ("repetition", row)))
            val elapsed = valOf (Json.toInt (member ("wall_us", row)))
        in need ((rep = 0 orelse rep = 1) andalso elapsed >= 0, "invalid measured repetition/time") end) samples
      val verdicts = List.map Json.decode (lines (read (output ^ "/fixtures.jsonl")))
      val () = need (length verdicts = 2, "missing base or edited source identity")
      val () = need (member ("source_sha256", hd verdicts) <> member ("source_sha256", List.nth (verdicts, 1)),
                     "edit replay reused the old source identity")
      val recordedSamples = read (output ^ "/samples.jsonl")
      val (status, _, _) = invoke "existing" args
      val () = need (status <> 0 andalso read (output ^ "/samples.jsonl") = recordedSamples,
                     "measurement overwrote an existing result directory")
      val bad = dir ^ "/bad.json"
      val () = json bad (spec (Json.Object [("name", Json.String "wrong-verdict"), ("mode", Json.String "ascii"),
        ("files", Json.Array [Json.String source]), ("accepted", Json.Bool false)]))
      val rejected = dir ^ "/rejected"
      val (status, _, errors) = invoke "wrong-verdict" ["--manifest", bad, "--out", rejected,
                                                    "--repetitions", "1", "--warmup", "0"]
      val () = need (status <> 0 andalso String.isSubstring "unexpected parser verdict" errors,
                     "planted wrong parser verdict was accepted")
      val () = need (not (exists (rejected ^ "/samples.jsonl")) andalso not (exists (rejected ^ "/summary.json")),
                     "failed correctness check published timing samples")
      val service = dir ^ "/service"
      val (status, _, errors) = invoke "service" ["--manifest", manifest, "--out", service,
        "--repetitions", "2", "--warmup", "0", "--service", fromRoot "bin/rune"]
      val () = need (status = 0, "prototype measurement failed: " ^ errors)
      val serviceRows = List.map Json.decode (lines (read (service ^ "/prototype-service.jsonl")))
      fun count phase = length (List.filter (fn row => member ("phase", row) = Json.String phase) serviceRows)
      val () = need (count "startup_initialize" = 2 andalso count "hover_repeat" = 2 andalso
                     count "diagnostics_first_private_cache" = 2, "startup and query repetitions were not independently recorded")
      val failedService = dir ^ "/failed-service"
      val (status, _, _) = invoke "failed-service" ["--manifest", manifest, "--out", failedService,
        "--repetitions", "1", "--warmup", "0", "--service", fromRoot "bin/rune-lsp-bench"]
      val () = need (status <> 0 andalso not (exists (failedService ^ "/summary.json")),
                     "a failed prototype published a successful summary")
      val (status, _, _) = invoke "self-test" ["--self-test"]
      val () = need (status = 0, "independent arithmetic/fault checks failed")
    in say "PASS lsp-bench: command verdicts, phase counts, warmup, replay, provenance, prototype queries and result ownership\n" end
end
val () = LspBenchTests.main ()
  handle e => (TextIO.output (TextIO.stdErr, "FAIL lsp-bench: " ^ General.exnMessage e ^ "\n");
               OS.Process.exit OS.Process.failure)
