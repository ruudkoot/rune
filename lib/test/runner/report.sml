(* The report: the status line, the failure blocks, the events and the
   summary. *)
structure Report :> REPORT =
struct
  datatype reader = Terminal | Log | Agent

  val agents = ["AI_AGENT", "CLAUDECODE", "CODEX_SANDBOX", "CURSOR_AGENT", "GEMINI_CLI"]

  fun reader () =
    if List.exists (fn v => isSome (OS.Process.getEnv v)) agents then Agent
    else if Posix.ProcEnv.isatty Posix.FileSys.stdout then Terminal
    else Log

  type ended = {path : string, verdict : string, reason : string, wall : Time.time, user : Time.time,
                system : Time.time, peakResident : int, outputBytes : int, kept : string list,
                command : string, rerun : string}

  type report = {reader : reader, events : TextIO.outstream, eventsPath : string, total : int,
                 started : Time.time, done : int ref, failed : int ref, counts : (string * int) list ref,
                 cpu : Time.time ref, slowest : (Time.time * string) list ref, lastDraw : Time.time ref,
                 lastBeat : Time.time ref, running : int ref, color : bool,
                 failures : (string * string * string * string list) list ref}

  fun say s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)
  fun seconds t = Real.fmt (StringCvt.FIX (SOME 1)) (Time.toReal t)

  fun json s =
    let
      fun esc #"\"" = "\\\""
        | esc #"\\" = "\\\\"
        | esc #"\n" = "\\n"
        | esc #"\t" = "\\t"
        | esc c = if Char.ord c < 32 then "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c)) else str c
    in "\"" ^ String.translate esc s ^ "\"" end

  fun start {reader, events, total} =
    let
      val r = {reader = reader, events = TextIO.openOut events, eventsPath = events, total = total,
               started = Runtime.clock (), done = ref 0, failed = ref 0, counts = ref [], cpu = ref Time.zeroTime,
               slowest = ref [], lastDraw = ref Time.zeroTime, lastBeat = ref (Runtime.clock ()), running = ref 0,
               color = reader = Terminal andalso Style.enabled (Style.Auto, true), failures = ref []}
    in
      (case reader of
         Agent => say ("rune-test: " ^ Int.toString total ^ " tests; events in " ^ events
                       ^ "; a passing test prints nothing\n")
       | _ => ());
      r
    end

  fun status (r : report) =
    Int.toString (!(#done r)) ^ "/" ^ Int.toString (#total r) ^ " done, " ^ Int.toString (!(#failed r)) ^ " failed, "
    ^ Int.toString (!(#running r)) ^ " running, " ^ seconds (Time.- (Runtime.clock (), #started r)) ^ " s"

  fun clear (r : report) = if #reader r = Terminal then say "\r\027[K" else ()

  fun tick (r : report, running) =
    let val now = Runtime.clock ()
    in
      #running r := running;
      case #reader r of
        Terminal =>
          if Time.> (Time.- (now, !(#lastDraw r)), Time.fromMilliseconds 100)
          then (#lastDraw r := now; clear r; say (status r)) else ()
      | _ =>
          if Time.> (Time.- (now, !(#lastBeat r)), Time.fromSeconds 30)
          then (#lastBeat r := now; say ("... " ^ status r ^ "\n")) else ()
    end

  fun paint (r : report, verdict) =
    if #color r andalso verdict <> "PASS"
    then Style.sgr {fg = Style.Ansi 1, bg = Style.Default, bold = true, faint = false, italic = false,
                    underline = false, reverse = false, struck = false} ^ verdict ^ Style.sgr Style.plain
    else verdict

  (* the five slowest, slowest first *)
  fun top5 (x as (w, _), xs) =
    let fun go [] = [x] | go ((y as (v, _)) :: ys) = if Time.>= (w, v) then x :: y :: ys else y :: go ys
    in List.take (go xs, Int.min (5, 1 + length xs)) end

  fun test (r : report, e : ended) =
    let
      val {path, verdict, reason, wall, user, system, peakResident, outputBytes, kept, command, rerun} = e
      fun bump [] = [(verdict, 1)]
        | bump ((v, n) :: rest) = if v = verdict then (v, n + 1) :: rest else (v, n) :: bump rest
    in
      #done r := !(#done r) + 1;
      #counts r := bump (!(#counts r));
      #cpu r := Time.+ (!(#cpu r), Time.+ (user, system));
      #slowest r := top5 ((wall, path), !(#slowest r));
      TextIO.output (#events r,
                     "{\"path\":" ^ json path ^ ",\"verdict\":" ^ json verdict ^ ",\"reason\":" ^ json reason
                     ^ ",\"wall\":" ^ Real.fmt (StringCvt.FIX (SOME 3)) (Time.toReal wall)
                     ^ ",\"user\":" ^ Real.fmt (StringCvt.FIX (SOME 3)) (Time.toReal user)
                     ^ ",\"system\":" ^ Real.fmt (StringCvt.FIX (SOME 3)) (Time.toReal system)
                     ^ ",\"peakResidentKB\":" ^ Int.toString peakResident
                     ^ ",\"outputBytes\":" ^ Int.toString outputBytes
                     ^ ",\"kept\":[" ^ String.concatWith "," (List.map json kept) ^ "]}\n");
      TextIO.flushOut (#events r);
      if verdict = "PASS" then ()
      (* a skip is a line with its reason: a requirement, a known gap, or a
         test it waits for that did not pass *)
      else if verdict = "SKIP" then (if reason = "" then () else (clear r; say ("SKIP " ^ path ^ ": " ^ reason ^ "\n")))
      else
        ((* a golden file written is told, and is no failure *)
         if List.exists (fn x => x = verdict) ["ACCEPTED", "FLAKY", "QUARANTINED"] then ()
         else (#failed r := !(#failed r) + 1; #failures r := (path, verdict, reason, kept) :: !(#failures r));
         clear r;
         say (paint (r, verdict) ^ " " ^ path ^ ": " ^ reason ^ "\n"
              ^ String.concat (List.map (fn d => "  kept:    " ^ d ^ "\n") kept)
              ^ (if command = "" then "" else "  command: " ^ command ^ "\n")
              ^ "  rerun:   " ^ rerun ^ "\n"))
    end

  (* the summary in Markdown, beside the events, and for GitHub's page of
     the job when it asks for one *)
  fun markdown (r : report, result, slowest) =
    let
      (* the reason's first lines, on one *)
      fun firstLine s =
        let val l = String.concatWith "; " (List.take (String.fields (fn c => c = #"\n") s, Int.min (3, length (String.fields (fn c => c = #"\n") s))))
        in if size l > 300 then String.substring (l, 0, 300) ^ "..." else l end
      fun cell s = String.translate (fn #"|" => "\\|" | c => str c) s
      val failures = rev (!(#failures r))
    in
      "# rune-test\n\n" ^ result ^ "\n\n"
      ^ (if null failures then ""
         else "| Test | Verdict | Why | Kept |\n|---|---|---|---|\n"
              ^ String.concat (List.map (fn (p, v, why, kept) =>
                                           "| " ^ cell p ^ " | " ^ v ^ " | " ^ cell (firstLine why) ^ " | "
                                           ^ cell (String.concatWith " " kept) ^ " |\n") failures)
              ^ "\n")
      ^ "Slowest: " ^ slowest ^ "\n"
    end

  fun append (file, text) =
    let val s = TextIO.openAppend file in TextIO.output (s, text); TextIO.closeOut s end
    handle IO.Io _ => ()

  fun finish (r : report, {cpus, freed, keptBytes}) =
    let
      val wall = Time.- (Runtime.clock (), #started r)
      val busy = if Time.toReal wall > 0.0 then 100.0 * Time.toReal (!(#cpu r)) / (Time.toReal wall * real cpus) else 0.0
      val counts = String.concatWith ", " (List.map (fn (v, n) => Int.toString n ^ " " ^ v) (!(#counts r)))
      (* a run that was interrupted did not pass, whatever it ran *)
      val incomplete = !(#done r) < #total r
      val ok = !(#failed r) = 0 andalso not incomplete
      val slowest = String.concatWith ", " (List.map (fn (w, p) => p ^ " " ^ seconds w ^ " s") (!(#slowest r)))
      val result = "RESULT: " ^ (if ok then "PASS" else if !(#failed r) = 0 then "INCOMPLETE" else "FAIL") ^ " " ^ Int.toString (!(#done r)) ^ " of "
                   ^ Int.toString (#total r) ^ " tests (" ^ counts ^ "), " ^ seconds wall ^ " s wall, "
                   ^ seconds (!(#cpu r)) ^ " s CPU (" ^ Real.fmt (StringCvt.FIX (SOME 0)) busy ^ "% of "
                   ^ Int.toString cpus ^ ")"
      val summaryPath = OS.Path.concat (OS.Path.dir (#eventsPath r), "summary.md")
    in
      TextIO.closeOut (#events r);
      clear r;
      say ("slowest: " ^ slowest ^ "\n");
      say ("output: kept " ^ Int.toString keptBytes ^ " bytes, freed " ^ Int.toString freed ^ "; events in "
           ^ #eventsPath r ^ ", summary in " ^ summaryPath ^ "\n");
      say (result ^ "\n");
      append (summaryPath, markdown (r, result, slowest));
      (case OS.Process.getEnv "GITHUB_STEP_SUMMARY" of
         SOME f => if f = "" then () else append (f, markdown (r, result, slowest))
       | NONE => ());
      ok
    end
end
