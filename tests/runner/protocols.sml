(* The REPL's, the compiler service's and the other protocol suites on the
   runner (docs/plans/unit-testing.md, M11).

   Written in SML from their drivers: the REPL's transcripts, each typed to
   rune-repl and its output compared, with interrupts at the points a
   transcript names (tests/repl/run.sh and drive.py), in each of the four
   ways make test-repl ran them; the diagnostics, in colour, plain, short
   and as JSON (tests/diagnostics/run.sh); and `rune --serve`, spoken to in
   JSON-RPC over its standard streams (tests/serve/run.py).

   Framed REPL, DAP and notebook drivers are SML workers of
   bin/rune-protocol-check. Their pipe/connection ways remain distinct;
   Python is retained only for independent Jupyter/ZMTP peers. *)
structure Protocols =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")

  (* ---- the REPL's transcripts *)
  (* a way: its name's suffix and the VM's options *)
  val replWays = [("", []), ("-off", ["--jit=off"]), ("-all", ["--jit=all"]), ("-tier2", ["--jit=all", "--jit-tier=2"])]

  (* the arguments of a transcript: its .args, a line each (a last line
     without its end is not read, as the shell's read leaves it), or
     --no-init *)
  fun replArgs name =
    let val f = "tests/repl/" ^ name ^ ".args"
    in
      if not (exists f) then ["--no-init"]
      else
        let val parts = String.fields (fn c => c = #"\n") (read f)
        in List.take (parts, length parts - 1) end
    end

  (* the number of times TEXT occurs in S, apart *)
  fun occurrences (text, s) =
    let
      fun go (i, n) =
        if i + size text > size s then n
        else if String.substring (s, i, size text) = text then go (i + size text, n + 1)
        else go (i + 1, n)
    in if text = "" then 0 else go (0, 0) end

  (* drive.py: type the transcript, and at `#!interrupt after TEXT` wait
     until the output has TEXT once more, and send SIGINT to the REPL *)
  fun drive (envf, cmd, transcript, outFile) =
    let
      val mode = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr]
      val out = Posix.FileSys.creat (outFile, mode)
      val {infd, outfd} = Posix.IO.pipe ()
      val () = Posix.IO.setfd (outfd, Posix.IO.FD.cloexec)
      fun n fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
      val pid = Subprocess.spawn {program = fromRoot (hd cmd), args = cmd, env = SOME (envf (Posix.ProcEnv.environ ())),
                                  search = false, dir = NONE, stdin = SOME (n infd), stdout = SOME (n out), stderr = SOME (n out),
                                  group = false, limits = Subprocess.unlimited}
      val () = (Posix.IO.close infd; Posix.IO.close out)
      fun writeAll s =
        let val v = Word8VectorSlice.full (Byte.stringToBytes s)
            fun go sl = if Word8VectorSlice.length sl = 0 then ()
                        else let val k = Posix.IO.writeVec (outfd, sl) in go (Word8VectorSlice.subslice (sl, k, NONE)) end
        in go v end
      val seen = ref [] : (string * int) list ref
      fun ended () = isSome (Subprocess.poll (SOME pid))
      fun waitFor text =
        let
          val want = 1 + getOpt (Option.map #2 (List.find (fn (t, _) => t = text) (!seen)), 0)
          val start = Runtime.clock ()
          fun go () =
            if occurrences (text, read outFile) >= want then
              (seen := (text, want) :: List.filter (fn (t, _) => t <> text) (!seen); true)
            else if ended () then false
            else if Time.toSeconds (Time.- (Runtime.clock (), start)) >= 60 then false
            else (OS.Process.sleep (Time.fromMilliseconds 50); go ())
        in go () end
      val lines = let val parts = String.fields (fn c => c = #"\n") (read transcript)
                      fun keep [] = [] | keep [x] = if x = "" then [] else [x] | keep (x :: xs) = (x ^ "\n") :: keep xs
                  in keep parts end
      val interrupt = "#!interrupt after "
      fun go [] = true
        | go (l :: rest) =
            if String.isPrefix interrupt l then
              let val text = String.extract (l, size interrupt, NONE)
                  val text = if String.isSuffix "\n" text then String.substring (text, 0, size text - 1) else text
              in
                if waitFor text then
                  (OS.Process.sleep (Time.fromMilliseconds 200);
                   (Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)), Posix.Signal.int)
                    handle OS.SysErr _ => ());
                   go rest)
                else (fail ("repl: " ^ hd cmd ^ " never wrote " ^ text); false)
              end
            else ((writeAll l handle OS.SysErr _ => ()); go rest)
      val ok = go lines
      val () = Posix.IO.close outfd
      val start = Runtime.clock ()
      fun finish () =
        if ended () then ()
        else if not ok orelse Time.toSeconds (Time.- (Runtime.clock (), start)) >= 120 then
          ((Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)), Posix.Signal.kill)
            handle OS.SysErr _ => ()); ignore (Subprocess.wait (SOME pid)))
        else (OS.Process.sleep (Time.fromMilliseconds 50); finish ())
    in finish () end

  (* every FROM in S replaced by TO. FROM is not empty, and the search moves
     past each match, so TO may contain FROM. *)
  fun replace (from, to, s) =
    let
      val n = size from
      fun go (ss, acc) =
        let val (pre, rest) = Substring.position from ss
        in
          if Substring.isEmpty rest then List.rev (Substring.string ss :: acc)
          else go (Substring.triml n rest, to :: Substring.string pre :: acc)
        end
    in
      if n = 0 then s else String.concat (go (Substring.full s, []))
    end

  fun repl suffix =
    case List.find (fn (s, _) => s = suffix) replWays of
      NONE => fail ("repl: no way " ^ suffix)
    | SOME (_, vmopts) =>
        let
          (* where run.sh wrote: the transcripts that save an image name it.
             The four ways run at once. A transcript writes the files it
             uses under this directory, as @REPL@, so the ways do not share
             them. The expected transcripts name tests/out/repl. *)
          val canon = "tests/out/repl"
          val out = canon ^ suffix
          val () = mkdirs out
          val cache = out ^ "/cache"
          val () = rmTree cache
          val envf = setEnv ("XDG_CONFIG_HOME", root ^ "/tests/repl/lib/config") o setEnv ("RUNE_REPL_OUT", out)
                     o setEnv ("RUNE_CACHE", cache) o unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"]
          fun vm args = ["bin/runevm"] @ vmopts @ ["--heap-size", "67108864", "--restore"] @ args
          (* the transcripts in order, which share the cache *)
          val transcripts = List.map basename (List.filter (fn f => String.isSuffix ".in" f) (glob ("tests/repl", ".in")))
          fun name t = String.substring (OS.Path.file t, 0, size (OS.Path.file t) - 3)
          (* what the REPL printed, with this way's directory written as the
             directory the expected transcript names *)
          fun canonical (got, cmp) = write (cmp, replace (out, canon, read got))
          fun one t =
            let
              val n = name t
              val src = "tests/repl/" ^ n ^ ".in"
              val got = out ^ "/" ^ n ^ ".out"
              val fed = out ^ "/" ^ n ^ ".in"
              val () = write (fed, replace ("@REPL@", out, read src))
              val () =
                if List.exists (fn l => String.isPrefix "#!interrupt " l) (lines (read src))
                then drive (envf, vm ["bin/rune-repl.img", "--", "--no-init"], fed, got)
                else ignore (execEnv envf {cmd = vm (["bin/rune-repl.img", "--"] @ replArgs n), dir = NONE, stdin = fed,
                                           stdout = got, stderr = got, timeout = 600})
              val expected = "tests/repl/" ^ n ^ ".expected"
              val cmp = out ^ "/" ^ n ^ ".cmp"
              val () = canonical (got, cmp)
            in
              if not (same (expected, cmp)) then
                if accepting then write (expected, read cmp)
                else fail ("repl" ^ suffix ^ "." ^ n ^ " (diff " ^ expected ^ " " ^ cmp ^ "): " ^ difference (expected, cmp))
              else if exists ("tests/repl/" ^ n ^ ".then") then
                let
                  val thenSrc = "tests/repl/" ^ n ^ ".then"
                  val thenFed = out ^ "/" ^ n ^ ".then.in"
                  val then' = out ^ "/" ^ n ^ ".then.out"
                  val thenCmp = out ^ "/" ^ n ^ ".then.cmp"
                  val () = write (thenFed, replace ("@REPL@", out, read thenSrc))
                  val _ = execEnv envf {cmd = vm [out ^ "/" ^ n ^ ".img", "--", "--no-init"], dir = NONE,
                                        stdin = thenFed, stdout = then', stderr = then', timeout = 600}
                  val () = canonical (then', thenCmp)
                  val texp = "tests/repl/" ^ n ^ ".then.expected"
                in
                  if same (texp, thenCmp) then ()
                  else fail ("repl" ^ suffix ^ "." ^ n ^ ", restored (diff " ^ texp ^ " " ^ thenCmp ^ "): " ^ difference (texp, thenCmp))
                end
              else ()
            end
        in List.app one (glob ("tests/repl", ".in")) end

  (* ---- the diagnostics *)
  val esc = str (Char.chr 27)
  (* ESC [ digits and semicolons m, removed *)
  fun uncolour s =
    let
      fun go (i, acc) =
        if i >= size s then String.concat (rev acc)
        else if String.sub (s, i) = Char.chr 27 andalso i + 1 < size s andalso String.sub (s, i + 1) = #"[" then
          let
            fun skip j = if j < size s andalso (Char.isDigit (String.sub (s, j)) orelse String.sub (s, j) = #";") then skip (j + 1) else j
            val j = skip (i + 2)
          in if j < size s andalso String.sub (s, j) = #"m" then go (j + 1, acc) else go (i + 1, str (String.sub (s, i)) :: acc) end
        else go (i + 1, str (String.sub (s, i)) :: acc)
    in go (0, []) end

  fun diagnosticsOne n =
    let
      val out = run ^ "/diagnostics"
      val () = mkdirs out
      val src = "tests/diagnostics/" ^ n ^ ".sml"
      fun o' ext = out ^ "/" ^ n ^ ext
      val envf = unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE", "NO_COLOR", "CLICOLOR", "RUNE_COLORS", "COLORFGBG"]
      fun rune (flags, err) = ignore (execEnv envf {cmd = ["bin/rune"] @ flags @ [src, "-o", o' ".rbc"], dir = NONE, stdin = "",
                                                    stdout = "", stderr = err, timeout = 120})
      val () = rune (["--color=always", "--diagnostics=full"], o' ".color")
      val () = write (o' ".shown", String.translate (fn c => if c = Char.chr 27 then "\\e" else str c) (read (o' ".color")))
      val () = rune (["--color=never", "--diagnostics=full"], o' ".plain")
      val () = rune ([], o' ".short")
      val expected = "tests/diagnostics/" ^ n ^ ".expected"
      fun check (ok, what) = if ok then () else fail (n ^ ": " ^ what)
      val () =
        if same (o' ".shown", expected) then ()
        else if accepting then write (expected, read (o' ".shown"))
        else fail (n ^ ": the diagnostics differ from " ^ expected ^ ": " ^ difference (expected, o' ".shown"))
      val () = check (uncolour (read (o' ".color")) = read (o' ".plain"), "the colours are not all that tells the coloured from the plain")
      val prefix = src ^ ":"
      val () = check (String.concat (List.map (fn l => l ^ "\n") (List.filter (fn l => String.isPrefix prefix l)
                                                                            (String.fields (fn c => c = #"\n") (read (o' ".plain")))))
                      = read (o' ".short"),
                      "the short form is not the plain one's first lines")
      val jexp = "tests/diagnostics/" ^ n ^ ".json.expected"
    in
      if exists jexp then
        let
          val _ = execEnv envf {cmd = ["bin/rune", "--diagnostics-json", o' ".json", src, "-o", o' ".rbc"], dir = NONE, stdin = "",
                                stdout = "", stderr = "", timeout = 120}
          (* "compilerVersion":"..." as VERSION *)
          val text = read (o' ".json")
          val key = "\"compilerVersion\":\""
          val shown =
            case Substring.position key (Substring.full text) of
              (pre, rest) =>
                if Substring.isEmpty rest then text
                else
                  let val after = Substring.triml (size key) rest
                      val (_, tail) = Substring.splitl (fn c => c <> #"\"") after
                  in Substring.string pre ^ key ^ "VERSION" ^ Substring.string tail end
        in
          write (o' ".json.shown", shown);
          if same (o' ".json.shown", jexp) then ()
          else if accepting then write (jexp, shown)
          else fail (n ^ ": the JSON differs from " ^ jexp ^ ": " ^ difference (jexp, o' ".json.shown"))
        end
      else ()
    end

  (* --diagnostics-json for a file whose name is not UTF-8, Latin-1's
     "caf\233.sml": the byte is written as the character of its number, and
     the report reads back *)
  fun diagnosticsLatin1 () =
    let
      val dir = run ^ "/diagnostics-latin1"
      val () = (rmTree dir; mkdirs dir)
      val src = dir ^ "/caf\233.sml"
      val () = write (src, "val x : int = \"a\"\n")
      val _ = exec {cmd = ["bin/rune", "--diagnostics-json", dir ^ "/report.json", src, "-o", dir ^ "/a.rbc"], dir = NONE,
                    stdin = "", stdout = "", stderr = "", timeout = 120}
      val report = Json.decode (read (dir ^ "/report.json")) handle Json.Syntax _ => Json.Null
      val paths =
        case Json.member ("diagnostics", report) of
          SOME (Json.Array ds) => List.map (fn d => Json.member ("path", d)) ds
        | _ => []
    in
      if paths = [SOME (Json.String (dir ^ "/caf\195\169.sml"))] then ()
      else fail ("diagnostics.latin1-name: " ^ read (dir ^ "/report.json"))
    end

  (* the first line of a diagnostic escapes what a file's name holds that
     would not show, or could make the line read otherwise (D14): a byte
     that is not UTF-8, as Latin-1's "caf\233.sml" has, and a bidirectional
     control, U+202E; the column after a character above ASCII counts it
     once (D15) *)
  fun diagnosticsNames () =
    let
      val dir = run ^ "/diagnostics-names"
      val () = (rmTree dir; mkdirs dir)
      fun one (name, shown, text, col) =
        let
          val src = dir ^ "/" ^ name
          val () = write (src, text)
          val () = ignore (exec {cmd = ["bin/rune", "--diagnostics=short", "--color=never", src, "-o", dir ^ "/a.rbc"],
                                 dir = NONE, stdin = "", stdout = "", stderr = dir ^ "/err", timeout = 120})
          val want = dir ^ "/" ^ shown ^ ":1:" ^ col ^ ": error: "
        in
          if String.isPrefix want (read (dir ^ "/err")) then ()
          else fail ("diagnostics.escaped-names: wanted " ^ want ^ "..., got " ^ read (dir ^ "/err"))
        end
    in
      one ("caf\233.sml", "caf\\xE9.sml", "val x : int = \"a\"\n", "5");
      one ("a\226\128\174b.sml", "a\\u{202E}b.sml", "(* \206\187 *) val x : int = \"a\"\n", "13")
    end

  (* ---- rune --serve *)
  fun serve () =
    let
      val dir = run ^ "/serve"
      val () = (rmTree dir; mkdirs dir)
      val () = write (dir ^ "/lib.sml", "structure Lib = struct fun double x = x * 2 end\n")
      val good = "val y = Lib.double 21\nfun twice f x = f (f x)\n"
      val bad = "val y = Lib.double \"21\"\nval z = undefinedName\n"
      val () = write (dir ^ "/a.sml", good)
      val toServe = Posix.IO.pipe () and fromServe = Posix.IO.pipe ()
      val () = Posix.IO.setfd (#outfd toServe, Posix.IO.FD.cloexec)
      val () = Posix.IO.setfd (#infd fromServe, Posix.IO.FD.cloexec)
      val errf = Posix.FileSys.creat (dir ^ "/serve.err", Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
      fun n fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
      val pid = Subprocess.spawn {program = fromRoot "bin/rune", args = ["bin/rune", "--serve", "--cache-dir", "cache"], env = NONE,
                                  search = false, dir = SOME dir, stdin = SOME (n (#infd toServe)),
                                  stdout = SOME (n (#outfd fromServe)), stderr = SOME (n errf), group = false,
                                  limits = Subprocess.unlimited}
      val () = (Posix.IO.close (#infd toServe); Posix.IO.close (#outfd fromServe); Posix.IO.close errf)
      val pending = ref ""
      fun readLine () =
        case CharVector.findi (fn (_, c) => c = #"\n") (!pending) of
          SOME (i, _) => let val l = String.substring (!pending, 0, i)
                         in pending := String.extract (!pending, i + 1, NONE); SOME l end
        | NONE =>
            let val v = Posix.IO.readVec (#infd fromServe, 65536)
            in if Word8Vector.length v = 0 then NONE else (pending := !pending ^ Byte.bytesToString v; readLine ()) end
      fun send text =
        let fun go sl = if Word8VectorSlice.length sl = 0 then ()
                        else let val k = Posix.IO.writeVec (#outfd toServe, sl) in go (Word8VectorSlice.subslice (sl, k, NONE)) end
        in go (Word8VectorSlice.full (Byte.stringToBytes (text ^ "\n"))) end
      fun q s = Json.encode (Json.String s)
      fun request (i, method, params) =
        (send ("{\"jsonrpc\": \"2.0\", \"id\": " ^ Int.toString i ^ ", \"method\": " ^ q method ^ ", \"params\": " ^ params ^ "}");
         case readLine () of
           SOME l => (Json.decode l handle Json.Syntax _ => Json.Null)
         | NONE => Json.Null)
      fun buffer (text, extra) =
        "{\"files\": [\"lib.sml\", \"a.sml\"], \"path\": \"a.sml\", \"text\": " ^ text ^ extra ^ "}"
      fun field (v, path) = List.foldl (fn (k, SOME x) => Json.member (k, x) | (_, NONE) => NONE) (SOME v) path
      fun str v = case v of SOME (Json.String s) => SOME s | _ => NONE
      fun num v = case v of SOME (x as Json.Number _) => Json.toInt x | _ => NONE
      fun want (what, r, ok) = if ok then () else fail ("serve." ^ what ^ ": " ^ Json.encode r)
      fun diags r = case field (r, ["result", "diagnostics"]) of SOME (Json.Array ds) => ds | _ => []
      fun index (s, sub) = case Substring.position sub (Substring.full s) of (pre, _) => Substring.size pre
      val r = request (1, "initialize", "{}")
      val () = want ("initialize", r, str (field (r, ["result", "name"])) = SOME "rune"
                                     andalso (case field (r, ["result", "methods"]) of
                                                SOME (Json.Array ms) => List.exists (fn m => m = Json.String "hover") ms
                                              | _ => false))
      val r = request (2, "diagnostics", buffer (q bad, ""))
      val () = want ("diagnostics-errors", r,
                     List.map (fn d => (str (field (d, ["severity"])), num (field (d, ["line"])), num (field (d, ["start"])),
                                        num (field (d, ["stop"])))) (diags r)
                     = [(SOME "error", SOME 1, SOME (index (bad, "\"21\"")), SOME (index (bad, "\"21\"") + 4)),
                        (SOME "error", SOME 2, SOME (index (bad, "undefinedName")), SOME (index (bad, "undefinedName") + 13))])
      val r = request (3, "diagnostics", buffer (q good, ""))
      val () = want ("diagnostics-none", r, field (r, ["result"]) = SOME (Json.Object [("diagnostics", Json.Array [])]))
      val r = request (4, "hover", buffer (q good, ", \"offset\": " ^ Int.toString (index (good, "double"))))
      val () = want ("hover-function", r, str (field (r, ["result", "type"])) = SOME "int -> int"
                                         andalso str (field (r, ["result", "name"])) = SOME "Lib.double")
      val r = request (5, "hover", buffer (q good, ", \"offset\": " ^ Int.toString (index (good, "f x)"))))
      val () = want ("hover-variable", r, str (field (r, ["result", "name"])) = SOME "f"
                                         andalso (case str (field (r, ["result", "type"])) of SOME t => String.isSuffix "-> 'a" t | NONE => false))
      val r = request (6, "hover", buffer (q good, ", \"offset\": 0"))
      val () = want ("hover-nothing", r, field (r, ["result"]) = SOME Json.Null)
      (* a buffer of non-ASCII text, in a comment, where the default takes
         it, sent as Python sends it: \u escapes, a character beyond 16 bits
         as two; offsets are its bytes in UTF-8 *)
      val accented = "(* caf\195\169 \226\134\146 \240\159\152\128 *)\nval z = alsoUndefined\n"
      val escaped = "\"(* caf\\u00e9 \\u2192 \\ud83d\\ude00 *)\\nval z = alsoUndefined\\n\""
      val r = request (9, "diagnostics", buffer (escaped, ""))
      val () = want ("diagnostics-utf8", r,
                     List.map (fn d => (num (field (d, ["line"])), num (field (d, ["start"])))) (diags r)
                     = [(SOME 2, SOME (index (accented, "alsoUndefined")))])
      (* a lone surrogate names no character, and has no UTF-8: the request
         is refused as text that is not JSON, and the service goes on *)
      val r = request (20, "diagnostics", buffer ("\"val s = \\\"\\ud800\\\"\\n\"", ""))
      val () = want ("lone-surrogate", r, num (field (r, ["error", "code"])) = SOME ~32700
                                          andalso (case str (field (r, ["error", "message"])) of
                                                     SOME m => String.isSubstring "lone surrogate" m
                                                   | NONE => false))
      val () = List.app (fn k => ignore (request (10 + k, "diagnostics", buffer (q good, "")))) (List.tabulate (9, fn k => k))
      val r = request (7, "nosuch", "{}")
      val () = want ("unknown-method", r, num (field (r, ["error", "code"])) = SOME ~32601)
      val r = request (8, "shutdown", "{}")
      val start = Runtime.clock ()
      fun waitEnd () =
        case Subprocess.poll (SOME pid) of
          SOME {status, ...} => status = Posix.Process.W_EXITED
        | NONE => if Time.toSeconds (Time.- (Runtime.clock (), start)) >= 30
                  then ((Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)), Posix.Signal.kill)
                         handle OS.SysErr _ => ()); ignore (Subprocess.wait (SOME pid)); false)
                  else (OS.Process.sleep (Time.fromMilliseconds 20); waitEnd ())
    in
      want ("shutdown", r, isSome (field (r, ["result"])) andalso waitEnd ());
      Posix.IO.close (#outfd toServe); Posix.IO.close (#infd fromServe)
    end

  (* ---- the tree *)
  fun jobIn pools (path, args, after, memory, timeout) =
    Test.it path
      {program = "/bin/sh",
       args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = memory,
       pools = pools, exclusive = false, after = after, judge = failLines} : Run.command Test.tree
  fun job x = jobIn [] x

  (* a driver that stays, run as a job: it exits 0 when it passed; the
     drivers of a pool write one directory of tests/out, one at a time *)
  fun driverIn pools (path, script) =
    Test.it path
      {program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = SOME ".", stdin = NONE,
       timeout = Time.fromSeconds 1800, cap = 0, cpus = 1, memory = 1500, pools = pools, exclusive = false, after = [],
       judge = Run.exitZero} : Run.command Test.tree
  fun driver x = driverIn [] x

  fun command args =
    case args of
      ["repl", suffix] => SOME (fn () => repl (if suffix = "-" then "" else suffix))
    | ["diagnostics-one", n] => SOME (fn () => diagnosticsOne n)
    | ["diagnostics-latin1"] => SOME diagnosticsLatin1
    | ["diagnostics-names"] => SOME diagnosticsNames
    | ["serve"] => SOME serve
    | _ => NONE

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  (* Stable scenario labels are part of the SML inventory. *)
  val scenarios = IncrementalExtra.cases

  val tree =
    Test.describe ""
      [(* the ways one at a time: reload.in writes its files to
          tests/out/repl, whose names its transcript shows, and a way that
          ran beside another read the other's (make check, 2026-10-18) *)
       tagged ["check", "test-repl", "covers:tests/repl/*"]
         (Test.describe "repl"
            (List.map (fn (s, _) => jobIn ["repl-files"]
                                          (if s = "" then "default" else String.extract (s, 1, NONE), ["repl", if s = "" then "-" else s],
                                           [], 1000, 1800))
                      replWays)),
       tagged ["check", "test-diagnostics", "covers:tests/diagnostics/*"]
         (Test.describe "diagnostics" (List.map (fn f => job (basename f, ["diagnostics-one", basename f], [], 300, 600))
                                                (glob ("tests/diagnostics", ".sml"))
                                       @ [job ("latin1-name", ["diagnostics-latin1"], [], 300, 600),
                                          job ("escaped-names", ["diagnostics-names"], [], 300, 600)])),
       tagged ["check", "test-serve", "covers:tests/serve/*"] (Test.describe "serve" [job ("rune", ["serve"], [], 500, 600)]),
       tagged ["check", "test-repl-protocol", "covers:tests/repl-protocol/*", "covers:tests/runner/protocol*.sml", "covers:tests/runner/replprotocolchecks.sml"]
         (Test.describe "repl-protocol"
            (driver ("@faults", "exec bin/rune-protocol-check faults") :: List.map (fn f => let val n = basename (String.substring (f, 0, size f - 7) ^ ".sml")
                               in driver (n, "exec bin/rune-protocol-check repl " ^ quote n) end)
                      (glob ("tests/repl-protocol", ".script")))),
       tagged ["check", "test-dap", "covers:tests/dap/*", "covers:tests/runner/protocol*.sml", "covers:tests/runner/dapchecks.sml"]
         (Test.describe "dap" [driver ("pipe", "exec bin/rune-protocol-check dap"),
                               driver ("connection", "RUNE_ENGINE_CONNECT=1 exec bin/rune-protocol-check dap")]),
       tagged ["check", "test-kernel", "covers:tests/kernel/*", "covers:tests/runner/protocol*.sml", "covers:tests/runner/kernelchecks.sml"]
         (Test.describe "kernel" [driverIn ["kernel"] ("pipe", "exec bin/rune-protocol-check kernel"),
                                  driverIn ["kernel"] ("connection", "RUNE_ENGINE_CONNECT=1 exec bin/rune-protocol-check kernel"),
             Test.requires ["jupyter-client"] (driverIn ["kernel"] ("notebook-pipe", "exec bin/rune-protocol-check notebook")),
             Test.requires ["jupyter-client"] (driverIn ["kernel"] ("notebook-connection", "RUNE_ENGINE_CONNECT=1 exec bin/rune-protocol-check notebook"))]),
       tagged ["check", "test-incremental", "covers:tests/incremental/*", "covers:examples/hello.sml"]
         (Test.describe "incremental"
            (List.map (fn s => driver (s, "exec bin/rune-incremental one " ^ s ^ " bin/rune")) scenarios
             @ [driver ("@mutate", "exec bin/rune-incremental mutate --rune bin/rune --steps 30 tests/incremental/functors tests/incremental/project"),
                driver ("@mutate-v1", "exec bin/rune-incremental mutate --replay-v1 --out \"$RUNE_TEST_RUN/mutation-replay\""),
                driver ("@faults", "exec bin/rune-incremental faults"),
                (* the soundness check of fingerprints (functors-units M4) holds a
                   compiler to itself, and catches a weak hash *)
                driver ("@soundness", "exec bin/rune-incremental soundness --old bin/rune --new bin/rune --probes --steps 10 --out \"$RUNE_TEST_RUN/soundness\" tests/incremental/project"),
                driver ("@soundness-weak", "exec bin/rune-incremental soundness --old bin/rune --new bin/rune --weaken 0 --expect-violations --probes --out \"$RUNE_TEST_RUN/soundness-weak\"")]))]
end
