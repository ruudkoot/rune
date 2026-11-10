(* The -lazy ports against rhc (the haskell98 roadmap's M19, its -lazy ports).
   Beside each hand-written lazy SML port of examples/benchmarks is the
   Haskell it was ported from (PORT/upstream, nofib's), with nofib's own
   run of it: its arguments and standard input in fast mode, and the output
   it must print (NAME.faststdout or NAME.stdout), the fixture the SML port
   is validated against. tests/hs/lazy-ports.tsv lists every port: `ready`
   where GHC 9.4.7 runs the upstream Main as nofib does and prints that
   fixture byte for byte, and its imports are the Report's or reach them by
   the corpus's rewrite or compat layer; otherwise `held`, and why.

   A ready port's job prepares its sources as the corpus is prepared
   (HsCorpus.prepare: h98, the import rewrite, then the 2019 nofib's compat
   layer, the first rhc compiles), with the upstream's other files beside
   them, compiles them with bin/rhc, runs the program on bin/runevm with
   nofib's arguments and input, and wants the fixture. A port rhc refuses or
   that prints otherwise is a finding, which tests/hs/rhc-corpus.txt lists
   with its cause as the corpus's are (`rhc | lazy/PORT::run | RUNE-DEV |
   reject: ...`), and whose staleness `@stale` checks.

   Held until rhc compiles: the jobs need the capability `rhc-compiles`,
   which compiles and runs a program that prints hello. Nightly. *)
structure HsLazyPorts =
struct
  open Sh

  val bench = "examples/benchmarks"
  fun manifest () = env ("RUNE_HS_LAZY_PORTS", fromRoot "tests/hs/lazy-ports.tsv")
  fun out () = fromRoot (env ("RUNE_HS_OUT", run ^ "/hs-rhc-corpus"))
  fun runevm () = env ("RUNE_HS_RUNEVM", fromRoot "bin/runevm")
  val gib = 1024 * 1024 * 1024
  val limits = {addressSpace = SOME (6 * gib), cpuTime = NONE, fileSize = SOME gib, core = SOME 0}

  (* the manifest: port, status, main, args, stdin, expected, reason *)
  fun ports () =
    let
      val text = read (manifest ())
      val ls = List.filter (fn l => l <> "" andalso not (String.isPrefix "#" l)) (lines text)
      fun row l = case String.fields (fn c => c = #"\t") l of
                    [p, s, m, a, i, e, r] => SOME {port = p, status = s, main = m, args = a, stdin = i, expected = e, reason = r}
                  | _ => NONE
    in List.mapPartial row (tl ls) end
  fun ready () = List.filter (fn r => #status r = "ready") (ports ())

  fun note (file, text) = (mkdirs (OS.Path.dir file); write (file, text))

  (* a ready port through rhc: prepared, compiled and run *)
  fun one (r : {port : string, status : string, main : string, args : string, stdin : string, expected : string,
                reason : string}) =
    let
      val port = #port r
      val id = "lazy/" ^ port
      val () = HsCorpus.rootOverride := SOME (fromRoot bench)
      val up = fromRoot bench ^ "/" ^ port ^ "/upstream"
      val c = {id = id, set = "lazy-ports", path = port ^ "/upstream/" ^ #main r, parent = "-", expect = "run"} : HsCorpus.candidate
      val work = out () ^ "/lazy/" ^ port
      val log = out () ^ "/logs/" ^ id
      val {files, rewritable, ...} = HsCorpus.closureOf c
      val variants = ["h98"] @ (if null rewritable then [] else ["rewrite"]) @ ["harness"]
      val want = read (up ^ "/" ^ #expected r)
      fun call (tag, cmd, dir, stdin, timeout) =
        let val () = mkdirs (OS.Path.dir log)
            val s = execProcess false limits (fn e => e)
                      {cmd = cmd, dir = SOME dir, stdin = stdin, stdout = log ^ "." ^ tag ^ ".out",
                       stderr = log ^ "." ^ tag ^ ".err", timeout = timeout}
        in (s, read (log ^ "." ^ tag ^ ".out"), firstNonEmpty (log ^ "." ^ tag ^ ".err")) end
      (* the first variant rhc compiles, then its run *)
      fun go [] first = first
        | go (v :: vs) first =
            let
              val (p, m) = HsCorpus.prepare (c, v, files, work ^ "/" ^ v)
              (* the upstream's inputs beside the program *)
              val () = List.app (fn n => let val s = up ^ "/" ^ n and d = p ^ "/" ^ n
                                         in if exists d then () else if isDir s then HsCorpus.copyTree (s, d)
                                            else HsCorpus.copyFile (s, d) end) (sort (entries up))
              val (cs, _, cerr) = call (v ^ ".rhc", [HsRhcCorpus.rhc (), m, "-o", "main.rbc"], p, "", 1800)
            in
              if cs <> 0 then go vs (case first of NONE => SOME (if cs = 124 then "timeout" else "reject", cerr) | s => s)
              else
                let
                  val stdin = if #stdin r = "" then "" else p ^ "/" ^ #stdin r
                  val (rs, output, rerr) = call (v ^ ".run", [runevm (), "main.rbc"] @ String.tokens Char.isSpace (#args r),
                                                 p, stdin, 1800)
                in
                  SOME (if rs = 124 then "timeout" else if output = want then (if rs = 0 then "ok" else "rtfail")
                        else if rs = 0 then "diff" else "rtfail",
                        if output = want then rerr else "printed " ^ Int.toString (size output) ^ " bytes, nofib's fixture "
                                                                   ^ Int.toString (size want) ^ (if rerr = "" then "" else ": " ^ rerr))
                end
            end
      val (got, said) = case go variants NONE of SOME x => x | NONE => ("reject", "")
    in
      rmTree work;
      {id = id, label = "run", got = got, said = said, passed = got = "ok", judged = true,
       want = "nofib's output is " ^ #expected r} : HsRhcCorpus.outcome
    end
    handle e => (note (out () ^ "/logs/lazy/" ^ #port r ^ ".exn", exnMessage e ^ "\n");
                 {id = "lazy/" ^ #port r, label = "run", got = "harness-error", said = exnMessage e, passed = false,
                  judged = true, want = "nofib's output"})

  fun runPort port =
    case List.find (fn r => #port r = port) (ready ()) of
      NONE => say ("FAIL rhc lazy " ^ port ^ ": no ready port of that name in " ^ manifest () ^ "\n")
    | SOME r => HsRhcCorpus.report ("lazy-" ^ port, [one r])

  (* compiles and runs hello: what the jobs wait for *)
  val capabilities =
    [{name = "rhc-compiles",
      probe = "d=$(mktemp -d) && printf 'main :: IO ()\\nmain = putStrLn \"hello\"\\n' > \"${d:?}/Main.hs\" && "
              ^ "bin/rhc \"${d:?}/Main.hs\" -o \"${d:?}/m.rbc\" > /dev/null 2>&1 && test \"$(bin/runevm \"${d:?}/m.rbc\")\" = hello; "
              ^ "s=$?; rm -rf \"${d:?}\"; exit $s",
      hint = "rhc does not compile a program yet: it stops after names and fixity (the haskell98 roadmap's M12); "
             ^ "the -lazy ports wait for it (tests/hs/lazy-ports.tsv)"}]

  fun tree () =
    let
      val rs = ready () handle _ => []
      val jobs = List.map (fn r => HsOracles.job (#port r, ["hs-lazy-ports", #port r], [], 3600, 2000)) rs
    in
      Test.tag "covers:tests/hs/lazy-ports.tsv" (Test.tag "covers:tests/runner/hslazyports.sml"
        (Test.tag "covers:examples/benchmarks/*" (Test.tag "nightly"
          (Test.requires ["rhc", "rhc-compiles"]
            (Test.describe "hs-lazy-ports"
              (jobs @ [HsOracles.job ("@stale", ["hs-rhc-corpus", "stale"],
                                      List.map (fn r => "hs-lazy-ports/" ^ #port r) rs, 300, 100)]))))))
    end

  fun command ["hs-lazy-ports", port] = SOME (fn () => runPort port)
    | command _ = NONE
end
