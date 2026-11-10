(* rhc's oracles (D52; tests/hs/oracles/README.md): GHC 9.4.7 with the
   strict shim and Hugs +98 the judges, nhc98 -98 the third, MicroHs a smoke
   oracle. With no rhc they reproduce the evidence the roadmap rests on: E7's
   82 conformance tests, built and run, each against what its suite expects;
   and E8's verdicts on the corpus, accept or reject in each variant and the
   run set's output, each against what E8 recorded (tests/hs/corpus). An
   outcome that differs is a failure unless a line of tests/hs/oracles.txt
   explains it, whose reason begins with the outcome it explains; a line that
   explains no failure of a job that ran is stale. Nightly, by capability:
   an oracle that is absent skips its jobs with how to build it. *)
structure HsOracles =
struct
  open Sh

  fun out () = fromRoot (env ("RUNE_HS_OUT", run ^ "/hs-oracles"))
  fun oraclesFile () = env ("RUNE_HS_ORACLES_TXT", fromRoot "tests/hs/oracles.txt")
  val oracles = ["ghc", "hugs", "nhc98", "mhs"]
  val shims = "tests/hs/oracles"
  fun ghc () = env ("RUNE_HS_GHC", "ghc")
  fun ghcPkg () = env ("RUNE_HS_GHC_PKG", "ghc-pkg")
  fun hugsDir () = env ("RUNE_HS_HUGS", "")
  fun nhcDir () = env ("RUNE_HS_NHC98", "")
  fun mhsDir () = env ("RUNE_HS_MICROHS", "")
  fun shimDir () = out () ^ "/ghc-shim"
  fun strictDb () = shimDir () ^ "/db"
  fun compatDb () = shimDir () ^ "/cdb"
  fun mhsShim () = out () ^ "/mhs-shim"
  fun mhsCache () = out () ^ "/mhs-shim.cache"

  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))
  exception Failed of string

  (* ---- Running an oracle ---- *)

  (* every child takes at most 6 GiB of address space, as E7's did, and is
     ended with its group at its time *)
  val gib = 1024 * 1024 * 1024
  val limits = {addressSpace = SOME (6 * gib), cpuTime = NONE, fileSize = SOME gib, core = SOME 0}
  type ran = {status : int, output : string, errors : string}
  (* `cmd` in `dir`, its streams in the files `log`.out and `log`.err *)
  fun call log {cmd, dir, stdin, timeout, changes} =
    let
      val () = mkdirs (OS.Path.dir log)
      fun envf e = List.foldl (fn ((k, v), e) => setEnv (k, v) e) (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"] e) changes
      val status = execProcess false limits envf {cmd = cmd, dir = SOME dir, stdin = stdin, stdout = log ^ ".out",
                                                   stderr = log ^ ".err", timeout = timeout}
    in {status = status, output = read (log ^ ".out"), errors = read (log ^ ".err")} : ran end
  fun ok (r : ran) = #status r = 0
  fun note (file, text) = (mkdirs (OS.Path.dir file); write (file, text))

  (* an exit status as E8 recorded it: a number, a signal negated, or
     timeout *)
  fun statusWord 124 = "timeout"
    | statusWord s = if s > 128 andalso s <= 192 then "-" ^ Int.toString (s - 128) else Int.toString s

  fun strict () = ["-hide-all-packages", "-package-db", strictDb (), "-package", "haskell98-shim"]
  fun compat () = ["-package-db", compatDb (), "-package", "haskell98-compat"]
  fun ghcBuild log (dir, main, timeout) =
    ok (call log {cmd = [ghc (), "-XHaskell98"] @ strict () @ ["-outputdir", ".ghc", "-o", "Main.ghc", "-w", main],
                  dir = dir, stdin = "", timeout = timeout, changes = []})
  fun ghcCheck log (dir, main, timeout) =
    ok (call log {cmd = [ghc (), "-XHaskell98"] @ strict () @ ["-fno-code", "-w", main], dir = dir, stdin = "",
                  timeout = timeout, changes = []})
  fun ghcRun log (dir, stdin, args, timeout) =
    call log {cmd = (dir ^ "/Main.ghc") :: args, dir = dir, stdin = stdin, timeout = timeout, changes = []}
  fun hugsEnv () = [("HUGSDIR", hugsDir () ^ "/hugsdir"), ("HUGSFLAGS", "")]
  (* Hugs loads and checks a program at its prompt, and an ERROR says it
     refused *)
  fun hugsCheck log (dir, main, flags, timeout) =
    let
      val q = dir ^ "/.hugsq"
      val () = write (q, ":q\n")
      val r = call log {cmd = [hugsDir () ^ "/src/hugs"] @ flags @ ["-h16M", main], dir = dir, stdin = q,
                        timeout = timeout, changes = hugsEnv ()}
      val () = OS.FileSys.remove q handle OS.SysErr _ => ()
    in not (String.isSubstring "ERROR" (#output r ^ #errors r)) andalso #status r <> 124 end
  fun hugsRun log (dir, main, stdin, args, timeout) =
    call log {cmd = [hugsDir () ^ "/src/runhugs", "+98", "-h64M", main] @ args, dir = dir, stdin = stdin,
              timeout = timeout, changes = hugsEnv ()}
  fun nhcEnv () = [("PATH", nhcDir () ^ "/script:" ^ env ("PATH", "/usr/bin:/bin"))]
  fun hmake log (dir, target, extra, timeout) =
    call log {cmd = [nhcDir () ^ "/script/hmake", "-HC=" ^ nhcDir () ^ "/script/nhc98"] @ extra @ [target], dir = dir,
              stdin = "", timeout = timeout, changes = nhcEnv ()}
  (* hmake can exit 0 having built nothing: what was built is there *)
  fun nhcBuild log (dir, extra, timeout) = ok (hmake log (dir, "Main", extra, timeout)) andalso exists (dir ^ "/Main")
  fun nhcRun log (dir, stdin, args, timeout) =
    call log {cmd = (dir ^ "/Main") :: args @ ["+RTS", "-H64M", "-RTS"], dir = dir, stdin = stdin, timeout = timeout,
              changes = []}
  fun mhsBuild log (dir, main, lib, timeout) =
    ok (call log {cmd = [mhsDir () ^ "/bin/mhs", "-i.", "-i" ^ mhsShim (), "-i" ^ mhsDir () ^ "/lib", "-CR" ^ mhsCache ()]
                         @ (if lib then ["-c"] else ["-oMain.comb"]) @ [main],
                  dir = dir, stdin = "", timeout = timeout, changes = []})
  fun mhsRun log (dir, stdin, timeout) =
    call log {cmd = [mhsDir () ^ "/bin/mhseval", "+RTS", "-rMain.comb", "-RTS"], dir = dir, stdin = stdin,
              timeout = timeout, changes = []}

  (* ---- The shims ---- *)

  val strictModules = ["Prelude", "Char", "List", "Monad", "Maybe", "Ratio", "Complex", "Numeric", "Ix", "Array", "CPUTime",
                       "System", "IO", "Directory", "Locale", "Time", "Random"]
  val compatModules = List.filter (fn m => m <> "Prelude" andalso m <> "Numeric") strictModules

  (* a package of the Report's modules for GHC, in a database of its own:
     the strict one exposes those and nothing else, Prelude included, so
     that a hierarchical import is an error; the compat one puts the
     library's modules over GHC's own Prelude *)
  fun package {name, src, modules, flags, db} =
    let
      val build = db ^ "-build"
      val log = build ^ "/log"
      val () = (rmTree build; rmTree db; mkdirs build)
      val unit = name ^ "-1.0"
      fun run' (what, cmd) =
        let val r = call log {cmd = cmd, dir = src, stdin = "", timeout = 1800, changes = []}
        in if ok r then r else raise Failed (what ^ " failed: " ^ String.concatWith " / " (List.take (lines (#errors r ^ #output r),
                                                    Int.min (8, length (lines (#errors r ^ #output r)))))) end
      val _ = run' ("ghc --make " ^ name,
                    [ghc (), "--make", "-this-unit-id", unit, "-hide-all-packages", "-package", "base", "-package", "array",
                     "-package", "directory", "-package", "process", "-package", "time"] @ flags
                    @ ["-cpp", "-O0", "-odir", build, "-hidir", build, "-w"] @ List.map (fn m => m ^ ".hs") (modules @ ["ShimTime"]))
      val _ = run' ("ar", ["ar", "rcs", build ^ "/libHS" ^ unit ^ ".a"] @ glob (build, ".o"))
      val _ = run' ("ghc-pkg init", [ghcPkg (), "init", db])
      fun id p = trim (#output (run' ("ghc-pkg field " ^ p, [ghcPkg (), "field", p, "id", "--simple-output"])))
      val conf = build ^ "/pkg.conf"
      val () = write (conf, String.concat
        ["name: ", name, "\nversion: 1.0\nid: ", unit, "\nkey: ", unit, "\nexposed: True\nexposed-modules: ",
         String.concatWith " " modules, "\nhidden-modules: ShimTime\nimport-dirs: ", build, "\nlibrary-dirs: ", build,
         "\nhs-libraries: HS", unit, "\ndepends: ", String.concatWith " " (List.map id ["base", "array", "directory", "process", "time"]),
         "\n"])
      val _ = run' ("ghc-pkg register", [ghcPkg (), "--package-db", db, "register", conf, "--force", "-v0"])
    in () end

  fun ghcShim () =
    let
      val src = fromRoot (shims ^ "/ghc-shim")
      val csrc = shimDir () ^ "/compat-src"
      val () = (rmTree csrc; mkdirs csrc)
      (* the compat package's sources: the strict one's, but those of its
         own, which take GHC's Prelude as it is *)
      val () = List.app (fn m => HsCorpus.copyFile (src ^ "/" ^ m ^ ".hs", csrc ^ "/" ^ m ^ ".hs")) (compatModules @ ["ShimTime"])
      val () = List.app (fn f => HsCorpus.copyFile (f, csrc ^ "/" ^ OS.Path.file f)) (glob (src ^ "/compat", ".hs"))
    in
      package {name = "haskell98-shim", src = src, modules = strictModules, flags = ["-XPackageImports", "-XHaskell2010"],
               db = strictDb ()};
      package {name = "haskell98-compat", src = csrc, modules = compatModules, flags = ["-XHaskell2010"], db = compatDb ()};
      say ("PASS the GHC shim: " ^ strictDb () ^ ", " ^ compatDb () ^ "\n")
    end
    handle Failed m => say ("FAIL the GHC shim: " ^ m ^ "\n")

  (* MicroHs's shim: its own modules, and the GHC shim's where they are the
     same *)
  fun assembleMhsShim () =
    let
      val d = mhsShim ()
      val () = (rmTree d; mkdirs d)
      val own = fromRoot (shims ^ "/mhs-shim")
      val () = List.app (fn m => HsCorpus.copyFile (fromRoot (shims ^ "/ghc-shim/" ^ m ^ ".hs"), d ^ "/" ^ m ^ ".hs"))
                 ["CPUTime", "Complex", "Ix", "Locale", "Maybe", "Ratio"]
      val () = List.app (fn f => HsCorpus.copyFile (f, d ^ "/" ^ OS.Path.file f)) (glob (own, ".hs"))
      (* the cache every test reads, of the library and the shim, written once
         by a program that imports each module of the shim, as E7's was *)
      val c = out () ^ "/mhs-cache"
      val () = (rmTree c; mkdirs c; (OS.FileSys.remove (mhsCache ()) handle OS.SysErr _ => ()))
      val mods = List.map (fn f => OS.Path.base (OS.Path.file f)) (glob (d, ".hs"))
      val () = write (c ^ "/Main.hs", String.concat (List.map (fn m => "import " ^ m ^ "\n") mods) ^ "main = return ()\n")
      val r = call (c ^ "/log") {cmd = [mhsDir () ^ "/bin/mhs", "-i.", "-i" ^ d, "-i" ^ mhsDir () ^ "/lib", "-C" ^ mhsCache (),
                                       "-oMain.comb", "Main.hs"], dir = c, stdin = "", timeout = 1800, changes = []}
    in if ok r then () else raise Failed ("MicroHs does not build its shim: " ^ firstNonEmpty (c ^ "/log.err") ^ firstNonEmpty (c ^ "/log.out")) end

  (* ---- What is expected ---- *)

  (* the outcome of an oracle on a program, of a label: conformance (built
     and run), judge (accepted in some variant), open, ext or run; and
     whether it is what was expected *)
  type outcome = {oracle : string, id : string, label : string, got : string, want : string, passed : bool}
  datatype verdict = Pass | Explained of string | Failure of string

  (* a line by what it says, not where it is, so that a job's results name
     the lines it used whatever was edited above them *)
  fun key (l : Expectations.line) =
    String.concatWith " | " [#way l, #path l ^ (case #label l of SOME x => "::" ^ x | NONE => ""), #category l, #reason l]

  (* the programs a job judges: RUNE_HS_ONLY, a glob of their names, to
     judge some again *)
  fun only id = Expectations.glob (env ("RUNE_HS_ONLY", "*"), id)

  fun firstWord r = trim (hd (String.fields (fn c => c = #":") r))
  fun place (l : Expectations.line) = OS.Path.file (#file l) ^ ":" ^ Int.toString (#number l)
  fun named ({oracle, id, label, ...} : outcome) = oracle ^ " " ^ id ^ "::" ^ label

  fun decide ls (x as {oracle, id, label, got, want, passed} : outcome) =
    let val expected = if label = "conformance" then "the test expects " ^ want else "E8 recorded " ^ want
    in
      case Expectations.find (ls, {way = oracle, path = id, label = SOME label}) of
        NONE => if passed then Pass else Failure (named x ^ ": " ^ got ^ ", where " ^ expected)
      | SOME l =>
          case Expectations.meaning (#category l) of
            SOME Expectations.Strict =>
              if passed then Failure (named x ^ ": " ^ got ^ " as expected, where " ^ place l ^ " says " ^ firstWord (#reason l))
              else if firstWord (#reason l) = got then Explained (key l)
              else Failure (named x ^ ": " ^ got ^ ", where " ^ place l ^ " says " ^ firstWord (#reason l) ^ " and " ^ expected)
          | SOME Expectations.Lenient => Explained (key l)
          | _ => if passed then Pass else Failure (named x ^ ": " ^ got ^ ", where " ^ expected)
    end

  (* a job's results: each outcome's verdict, for the stale lines; and its
     failures said *)
  fun results oracle = out () ^ "/" ^ oracle ^ "/results"
  fun report (oracle, job, os : outcome list) =
    let
      val ls = Expectations.read (oraclesFile ())
      val vs = List.map (fn x => (x, decide ls x)) os
      val file = results oracle ^ "/" ^ job ^ ".tsv"
      val () = mkdirs (results oracle)
      val () = write (file, String.concat (List.map (fn (x : outcome, v) =>
                 String.concatWith "\t" [case v of Pass => "PASS" | Explained _ => "EXPLAINED" | Failure _ => "FAIL",
                                         #id x, #label x, case v of Explained k => k | _ => "-"] ^ "\n") vs))
      val failures = List.mapPartial (fn (_, Failure m) => SOME m | _ => NONE) vs
      val explained = List.length (List.filter (fn (_, Explained _) => true | _ => false) vs)
    in
      List.app (fn m => say ("FAIL " ^ m ^ "\n")) failures;
      if null os then say ("FAIL " ^ oracle ^ " " ^ job ^ ": nothing was judged\n")
      else say ((if null failures then "PASS " else "SUMMARY ") ^ oracle ^ " " ^ job ^ ": " ^ Int.toString (length os)
                ^ " outcomes, " ^ Int.toString explained ^ " explained by " ^ oraclesFile () ^ ", "
                ^ Int.toString (length failures) ^ " failures\n")
    end

  (* the strict lines of an oracle that explain no failure of a job that
     ran: a result that one matches, and none it explained *)
  fun stale oracle =
    let
      val ls = Expectations.read (oraclesFile ())
      val rs = List.concat (List.map (fn f => List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                                                                          [v, id, label, n] => SOME (v, id, label, n) | _ => NONE)
                                                              (lines (read f))) (glob (results oracle, ".tsv")))
      fun ran (l : Expectations.line) =
        List.exists (fn (_, id, label, _) => isSome (Expectations.find ([l], {way = oracle, path = id, label = SOME label}))) rs
      fun used (l : Expectations.line) = List.exists (fn (v, _, _, k) => v = "EXPLAINED" andalso k = key l) rs
      val bad = List.filter (fn l => Expectations.meaning (#category l) = SOME Expectations.Strict
                                     andalso Expectations.glob (#way l, oracle) andalso ran l andalso not (used l)) ls
    in
      if null rs then say ("FAIL " ^ oracle ^ ": no job of it left results\n") else ();
      List.app (fn l => say ("FAIL stale " ^ oracle ^ ": " ^ Expectations.describe l ^ "\n")) bad;
      if null bad andalso not (null rs) then say ("PASS " ^ oracle ^ ": no line of " ^ oraclesFile () ^ " is stale\n") else ()
    end

  (* ---- Each oracle holds to a known output first ---- *)

  (* nothing ran is no pass: an oracle that cannot build and run hello is
     not judging anything *)
  fun pid () = SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  fun probe oracle =
    let
      (* a directory of this process's own: an oracle's jobs run at once *)
      val d = out () ^ "/" ^ oracle ^ "/probe-" ^ pid ()
      val () = (rmTree d; mkdirs d)
      val () = write (d ^ "/Main.hs", "main = putStrLn \"hello\"\n")
      val log = d ^ "/log"
      val r =
        case oracle of
          "ghc" => if ghcBuild log (d, "Main.hs", 300) then SOME (ghcRun log (d, "", [], 60)) else NONE
        | "hugs" => if hugsCheck log (d, "Main.hs", ["+98"], 120) then SOME (hugsRun log (d, "Main.hs", "", [], 60)) else NONE
        | "nhc98" => if nhcBuild log (d, ["-98"], 300) then SOME (nhcRun log (d, "", [], 60)) else NONE
        | "mhs" => if mhsBuild log (d, "Main.hs", false, 600) then SOME (mhsRun log (d, "", 60)) else NONE
        | _ => raise Failed ("no oracle " ^ oracle)
    in
      case r of
        SOME {status = 0, output = "hello\n", ...} => true
      | SOME r => (say ("FAIL " ^ oracle ^ " does not run hello: exit " ^ Int.toString (#status r) ^ ", printed "
                        ^ Int.toString (size (#output r)) ^ " bytes (" ^ d ^ ")\n"); false)
      | NONE => (say ("FAIL " ^ oracle ^ " does not build hello: " ^ firstNonEmpty (log ^ ".err") ^ firstNonEmpty (log ^ ".out")
                      ^ " (" ^ d ^ ")\n"); false)
    end

  (* the trees a job reads are the commits the evidence names *)
  fun pinned set =
    case List.find (fn r => HsCorpus.field r "set" = set) (HsCorpus.rows "trees.tsv") of
      NONE => raise Failed ("no tree for the set " ^ set)
    | SOME r =>
        let
          val t = HsCorpus.tree (HsCorpus.field r "tree")
          val log = out () ^ "/git/" ^ set ^ "." ^ pid ()
        in
          if not (isDir t) then raise Failed ("the tree " ^ t ^ " is not there (RUNE_HS_CORPUS)")
          else if not (isDir (t ^ "/.git")) then ()
          else
            let val g = call log {cmd = ["git", "-C", t, "rev-parse", "HEAD"], dir = t, stdin = "", timeout = 60, changes = []}
            in if trim (#output g) = HsCorpus.field r "commit" then ()
               else raise Failed (t ^ " is at " ^ trim (#output g) ^ ", where the evidence is of " ^ HsCorpus.field r "commit") end
        end

  (* ---- E7's conformance tests ---- *)

  (* a test's directory, its own sub-tests left out, links followed *)
  fun cleanCopy (src, dst) =
    (mkdirs dst;
     List.app (fn n =>
       let val s = src ^ "/" ^ n and d = dst ^ "/" ^ n
       in if isDir s then (if exists (s ^ "/Main.hs") then () else cleanCopy (s, d)) else HsCorpus.copyFile (s, d) end)
       (sort (entries src)))

  fun first (dir, suffix) = case glob (dir, suffix) of f :: _ => SOME f | [] => NONE

  (* the name a Main.hs declares at a line's start, which a test that is a
     module of its own has in place of Main *)
  fun declared t =
    case List.find (fn s => s + 6 <= size t andalso String.substring (t, s, 6) = "module") (HsSource.lineStarts t) of
      NONE => NONE
    | SOME s =>
        let val i = HsSource.skip HsSource.isWhite t (s + 6)
        in if i > s + 6 then Option.map (fn e => String.substring (t, i, e - i)) (HsSource.modidNoQuote t i) else NONE end

  fun conformanceOne oracle row =
    let
      val id = HsCorpus.field row "id"
      val w = out () ^ "/" ^ oracle ^ "/conformance/" ^ id
      val () = rmTree w
      val () = cleanCopy (HsCorpus.tree (HsCorpus.field row "path"), w)
      val log = out () ^ "/" ^ oracle ^ "/logs/" ^ id
      val stdin = getOpt (first (w, ".stdin"), "")
      val expected = Option.map (HsSource.universal o read) (first (w, ".stdout"))
      val libmod = case declared (HsSource.universal (read (w ^ "/Main.hs"))) of SOME m => m <> "Main" | NONE => false
      val (built, runIt) =
        case oracle of
          "ghc" => (if libmod then ghcCheck log (w, "Main.hs", 300) else ghcBuild log (w, "Main.hs", 300),
                    fn () => ghcRun log (w, stdin, [], 60))
        | "hugs" => (hugsCheck log (w, "Main.hs", ["+98"], 120), fn () => hugsRun log (w, "Main.hs", stdin, [], 60))
        | "nhc98" => (nhcBuild log (w, ["-98"], 300), fn () => nhcRun log (w, stdin, [], 60))
        | _ => (mhsBuild log (w, "Main.hs", libmod, 300), fn () => mhsRun log (w, stdin, 60))
      val got =
        if not built then "reject"
        else if libmod then "accept"
        else
          let val r = runIt ()
          in if #status r = 124 then "timeout"
             else case expected of
                    SOME e => if #output r = e then "ok" else if #status r = 0 then "diff" else "rtfail"
                  | NONE => if #status r = 0 then "ok?" else "rtfail" end
      val want = if String.isPrefix "accept" (HsCorpus.field row "expected") then "accept" else "reject"
      val passed = if want = "accept" then List.exists (fn v => v = got) ["ok", "ok?", "accept"] else got = "reject"
    in {oracle = oracle, id = id, label = "conformance", got = got, want = want, passed = passed} : outcome end

  fun conformance oracle =
    (List.app pinned ["conformance98", "yhc-conformance"];
     if oracle = "mhs" then assembleMhsShim () else ();
     if probe oracle then report (oracle, "conformance", List.map (conformanceOne oracle) (HsCorpus.rows "conformance.tsv"))
     else ())
    handle Failed m => say ("FAIL " ^ oracle ^ " conformance: " ^ m ^ "\n")

  (* ---- E8's verdicts ---- *)

  (* E8's record of a candidate: its row of accept.tsv or reject.tsv *)
  fun records () =
    List.map (fn r => (HsCorpus.field r "id", r)) (HsCorpus.rows "accept.tsv" @ HsCorpus.rows "reject.tsv")
  fun recorded (r, k) = case List.find (fn (h, _) => h = k) r of SOME (_, v) => v | NONE => ""

  fun accepts true = "accept" | accepts false = "reject"

  (* the oracle's check of a prepared program, as E8 asked it: Hugs at its
     prompt, GHC with no code, nhc98 compiling the main without linking *)
  fun check log oracle (p, m) =
    case oracle of
      "hugs" => hugsCheck log (p, m, ["+98"], 120)
    | "ghc" => ghcCheck log (p, m, 180)
    | _ =>
        let val obj = if String.isSuffix ".lhs" m then String.substring (m, 0, size m - 4) ^ ".o"
                      else if String.isSuffix ".hs" m then String.substring (m, 0, size m - 3) ^ ".o" else m
        in ok (hmake log (p, m, ["-98", "-H64M"], 600)) andalso exists (p ^ "/" ^ obj) end

  fun baseModules log =
    let val r = call log {cmd = [ghcPkg (), "field", "base", "exposed-modules", "--simple-output"], dir = out (), stdin = "",
                          timeout = 60, changes = []}
    in List.filter (fn m => m <> "Prelude" andalso m <> "Numeric" andalso size m > 0 andalso Char.isUpper (String.sub (m, 0))
                            andalso CharVector.all (fn c => HsSource.isWord c orelse c = #".") m)
                   (String.tokens (fn c => Char.isSpace c orelse c = #",") (#output r)) end
  (* GHC with the Report's Prelude and every installed module in sight: a
     program of Haskell 98's language on libraries outside the Report *)
  fun openFlags log =
    ["-hide-all-packages", "-package-db", strictDb (), "-package", "haskell98-shim",
     "-package", "base (" ^ String.concatWith ", " (baseModules log) ^ ")"]
    @ List.concat (List.map (fn p => ["-package", p]) ["containers", "mtl", "transformers", "directory", "process", "time",
                                                       "bytestring", "deepseq", "stm", "text", "parsec", "unix", "filepath"])
    @ ["-package", "array"]

  fun noHarness id = String.isPrefix "nofib/parallel/" id orelse String.isPrefix "nofib/smp/" id

  fun judgeOne (oracle, records, openf) (c : HsCorpus.candidate) =
    let
      val id = #id c
      val r = case List.find (fn (i, _) => i = id) records of SOME (_, r) => r | NONE => raise Failed ("no record of " ^ id)
      val work = out () ^ "/" ^ oracle ^ "/judge/" ^ id
      val log = out () ^ "/" ^ oracle ^ "/logs/" ^ id
      val {files, rewritable, ...} = HsCorpus.closureOf c
      val variants = ["h98"] @ (if null rewritable then [] else ["rewrite"])
                     @ (if #set c = "nofib-2019" andalso not (noHarness id) then ["harness"] else [])
      fun inVariant v = check (log ^ "." ^ v) oracle (HsCorpus.prepare (c, v, files, work ^ "/" ^ v))
      val best = List.exists inVariant variants
      fun outcome (label, got, want) = {oracle = oracle, id = id, label = label, got = got, want = want, passed = got = want} : outcome
      val main = outcome ("judge", accepts best, recorded (r, "v_" ^ oracle))
      val opened =
        if oracle = "ghc" andalso recorded (r, "v_ghc_open") <> "" then
          let val (p, m) = HsCorpus.prepare (c, "h98", files, work ^ "/open")
              val got = ok (call (log ^ ".open") {cmd = [ghc (), "-XHaskell98"] @ openf () @ ["-fno-code", "-w", m], dir = p,
                                                  stdin = "", timeout = 180, changes = []})
          in [outcome ("open", accepts got, recorded (r, "v_ghc_open"))] end
        else []
      val ext =
        if (oracle = "ghc" orelse oracle = "hugs") andalso recorded (r, "v_" ^ oracle ^ "_ext") <> "" then
          let val (p, m) = HsCorpus.prepare (c, "ext", files, work ^ "/ext")
              val got = if oracle = "hugs" then hugsCheck (log ^ ".ext") (p, m, ["-98"], 120)
                        else ok (call (log ^ ".ext") {cmd = [ghc ()] @ compat () @ ["-fno-code", "-w", m], dir = p, stdin = "",
                                                      timeout = 180, changes = []})
          in [outcome ("ext", accepts got, recorded (r, "v_" ^ oracle ^ "_ext"))] end
        else []
    in rmTree work; main :: opened @ ext end
    handle e as Failed _ => raise e
         | e => (note (out () ^ "/" ^ oracle ^ "/logs/" ^ #id c ^ ".exn", exnMessage e ^ "\n");
                 [{oracle = oracle, id = #id c, label = "judge", got = "harness-error", want = "", passed = false}])

  fun judge (oracle, set) =
    (pinned set;
     if probe oracle then
       let
         val records = records ()
         val modules = ref NONE
         fun openf () = case !modules of SOME f => f
                                       | NONE => let val f = openFlags (out () ^ "/" ^ oracle ^ "/base-" ^ pid ()) in modules := SOME f; f end
         val cs = List.filter (fn c => #set c = set andalso only (#id c)) (HsCorpus.candidates ())
       in report (oracle, "judge-" ^ set, List.concat (List.map (judgeOne (oracle, records, openf)) cs)) end
     else ())
    handle Failed m => say ("FAIL " ^ oracle ^ " judge " ^ set ^ ": " ^ m ^ "\n")

  (* ---- The run set ---- *)

  (* two outputs as E8 compared them: the same, the same words, the same
     words but for numbers equal to about five digits, or different *)
  fun words t = String.tokens HsSource.isWhite t
  fun numeric x =
    let
      val n = size x
      fun lead i = if i < n andalso Char.contains "-+([" (String.sub (x, i)) then lead (i + 1) else i
      fun digits i = HsSource.skip Char.isDigit x i
      val i = lead 0
      val j = digits i
    in
      j > i andalso
      let
        val k = if j < n andalso String.sub (x, j) = #"." then digits (j + 1) else j
        val k = if k < n andalso Char.toLower (String.sub (x, k)) = #"e" then
                  let val s = if k + 1 < n andalso Char.contains "-+" (String.sub (x, k + 1)) then k + 2 else k + 1
                      val e = digits s
                  in if e > s then e else k end
                else k
        val k = HsSource.skip (fn c => Char.contains ")]," c) x k
      in k = n end
    end
  fun number x = Real.fromString (HsSource.stripChars "()[],+" x)
  fun close (a, b) =
    let val (xs, ys) = (words a, words b)
    in length xs = length ys andalso
       ListPair.all (fn (x, y) =>
         x = y orelse
         (numeric x andalso numeric y andalso
          case (number x, number y) of
            (SOME fx, SOME fy) => let val d = Real.abs (fx - fy)
                                  in not (d > 1E~4 * Real.max (Real.max (Real.abs fx, Real.abs fy), 1E~30) andalso d > 1E~4) end
          | _ => false)) (xs, ys) end
  fun same (expected, output) =
    if expected = output then "same" else if words expected = words output then "same-ws"
    else if close (expected, output) then "close" else "diff"

  fun runOne (oracle, candidates) row =
    let
      val id = HsCorpus.field row "id"
      val c = case List.find (fn (c : HsCorpus.candidate) => #id c = id) candidates of
                SOME c => c | NONE => raise Failed ("no candidate " ^ id)
      val work = out () ^ "/" ^ oracle ^ "/run/" ^ id
      val log = out () ^ "/" ^ oracle ^ "/logs/" ^ id ^ ".run"
      val variant = case HsCorpus.field row "variant" of "" => "h98" | v => v
      val {files, ...} = HsCorpus.closureOf c
      val (p, m) = HsCorpus.prepare (c, variant, files, work)
      fun beside f = if f = "" then "" else
                       let val q = p ^ "/" ^ OS.Path.file f
                       in (if exists q then () else HsCorpus.copyFile (HsCorpus.tree f, q)); q end
      val expectedFile = HsCorpus.field row "expected"
      val stdin = beside (HsCorpus.field row "stdin")
      val _ = beside expectedFile
      val expected = HsSource.universal (read (HsCorpus.tree expectedFile))
      val args = String.tokens Char.isSpace (HsCorpus.field row "args")
      fun ran (build, r : ran) = build ^ "/" ^ statusWord (#status r) ^ "/" ^ same (expected, #output r)
      val got =
        case oracle of
          "ghc" =>
            let
              val how = if ghcBuild log (p, m, 900) then SOME "strict"
                        else
                          List.foldl (fn (flags, SOME h) => SOME h
                                       | (flags, NONE) =>
                                           (rmTree (p ^ "/.ghc");
                                            if ok (call log {cmd = [ghc (), "-O0"] @ compat () @ flags
                                                                   @ ["-outputdir", ".ghc", "-o", "Main.ghc", "-w", m],
                                                             dir = p, stdin = "", timeout = 900, changes = []})
                                               andalso exists (p ^ "/Main.ghc") then SOME "compat" else NONE))
                            NONE [["-XHaskell98"], ["-XHaskell2010", "-fglasgow-exts"]]
            in case how of SOME h => ran (h, ghcRun log (p, stdin, args, 600)) | NONE => "fail" end
        | "nhc98" =>
            if (m = "Main.hs" orelse m = "Main.lhs") andalso nhcBuild log (p, ["-98", "-H64M"], 300)
            then ran ("ok", nhcRun log (p, stdin, args, 300)) else "fail"
        | _ =>
            if hugsCheck log (p, m, ["+98"], 120) then ran ("ok", hugsRun log (p, m, stdin, args, 120)) else "fail"
      val want = case HsCorpus.field row (oracle ^ "_build") of
                   "fail" => "fail"
                 | b => b ^ "/" ^ HsCorpus.field row (oracle ^ "_rc") ^ "/" ^ HsCorpus.field row (oracle ^ "_out")
    in rmTree work; {oracle = oracle, id = id, label = "run", got = got, want = want, passed = got = want} : outcome end
    handle e as Failed _ => raise e
         | e => (note (out () ^ "/" ^ oracle ^ "/logs/" ^ HsCorpus.field row "id" ^ ".exn", exnMessage e ^ "\n");
                 {oracle = oracle, id = HsCorpus.field row "id", label = "run", got = "harness-error", want = "", passed = false})

  fun runSet (oracle, set) =
    (pinned set;
     if probe oracle then
       let val cs = HsCorpus.candidates ()
           val rows = List.filter (fn r => HsCorpus.field r "set" = set andalso HsCorpus.field r "expected" <> "" andalso only (HsCorpus.field r "id"))
                                  (HsCorpus.rows "run.tsv")
       in report (oracle, "run-" ^ set, List.map (runOne (oracle, cs)) rows) end
     else ())
    handle Failed m => say ("FAIL " ^ oracle ^ " run " ^ set ^ ": " ^ m ^ "\n")

  (* ---- The inventory ---- *)

  val judgeSets = ["conformance98", "yhc-conformance", "nhc98-nofib", "nofib-2019", "ghc-legacy", "jhc", "helium", "uhc-99", "hse"]
  val runSets = ["conformance98", "yhc-conformance", "nhc98-nofib", "nofib-2019", "ghc-legacy", "jhc"]
  val needs = [("ghc", "hs-ghc"), ("hugs", "hs-hugs"), ("nhc98", "hs-nhc98"), ("mhs", "hs-microhs")]

  fun job (name, args, after, seconds, memory) =
    Test.it name {program = "/bin/sh",
                  args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
                  env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds seconds, cap = 0, cpus = 1,
                  memory = memory, pools = [], exclusive = false, after = after, judge = failLines} : Run.command Test.tree

  fun oracleTree oracle =
    let
      val capability = #2 (valOf (List.find (fn (x, _) => x = oracle) needs))
      val shim = if oracle = "ghc" then ["hs-oracles/@ghc-shim"] else []
      val conf = job ("conformance", ["hs-oracle", "conformance", oracle], shim, 3600, 2000)
      val judges = if oracle = "mhs" then []
                   else List.map (fn s => job ("judge-" ^ s, ["hs-oracle", "judge", oracle, s], shim, 14400, 2000)) judgeSets
      val runs = if oracle = "mhs" then []
                 else List.map (fn s => job ("run-" ^ s, ["hs-oracle", "run", oracle, s], shim, 14400, 2000)) runSets
      val names = "conformance" :: List.map (fn s => "judge-" ^ s) (if oracle = "mhs" then [] else judgeSets)
                  @ List.map (fn s => "run-" ^ s) (if oracle = "mhs" then [] else runSets)
    in
      Test.requires [capability, "hs-corpus"]
        (Test.describe oracle (conf :: judges @ runs
                               @ [job ("@stale", ["hs-oracle", "stale", oracle], List.map (fn n => "hs-oracles/" ^ oracle ^ "/" ^ n) names,
                                       300, 100)]))
    end

  fun inProcess (name, args, tags) =
    List.foldl (fn (t, tree) => Test.tag t tree) (job (name, args, [], 600, 500)) tags

  val tree =
    Test.tag "covers:tests/hs/*" (Test.tag "covers:tests/runner/hs*.sml"
      (Test.describe ""
        [Test.tag "nightly" (Test.describe "hs-oracles"
           (Test.requires ["hs-ghc"] (job ("@ghc-shim", ["hs-oracle", "ghc-shim"], [], 3600, 3000))
            :: List.map oracleTree oracles)),
         Test.describe "hs-corpus"
           [inProcess ("data", ["hs-corpus-data"], ["check", "quick"]),
            inProcess ("source", ["hs-source"], ["check", "quick"]),
            inProcess ("faults", ["hs-faults"], ["check"])]]))

  val capabilities =
    [{name = "hs-ghc",
      probe = "test \"$(\"${RUNE_HS_GHC:-ghc}\" --numeric-version)\" = 9.4.7 && \"${RUNE_HS_GHC_PKG:-ghc-pkg}\" --version | grep -q ' 9\\.4\\.7$'",
      hint = "install GHC 9.4.7 (Ubuntu 24.04: apt install ghc; or ghcup install ghc 9.4.7) and set RUNE_HS_GHC and RUNE_HS_GHC_PKG where it is not ghc on PATH; tests/hs/oracles/README.md"},
     {name = "hs-hugs", probe = "test -x \"$RUNE_HS_HUGS/src/hugs\" && test -x \"$RUNE_HS_HUGS/src/runhugs\" && test -d \"$RUNE_HS_HUGS/hugsdir\"",
      hint = "build Hugs from github.com/augustss/Hugs 2719ab8 (./configure, make all in src and in libraries) and set RUNE_HS_HUGS to its tree; tests/hs/oracles/README.md"},
     {name = "hs-nhc98", probe = "test -x \"$RUNE_HS_NHC98/script/hmake\" && test -x \"$RUNE_HS_NHC98/script/nhc98\"",
      hint = "build nhc98 1.22 from github.com/8l/nhc98 b4d4152, 32-bit with -O1 -m32 -fno-pie -no-pie -fno-strict-aliasing -fcommon, and set RUNE_HS_NHC98 to its tree; tests/hs/oracles/README.md"},
     {name = "hs-microhs", probe = "test -x \"$RUNE_HS_MICROHS/bin/mhs\" && test -x \"$RUNE_HS_MICROHS/bin/mhseval\" && test -d \"$RUNE_HS_MICROHS/lib\"",
      hint = "build MicroHs from github.com/augustss/MicroHs f17be7f (make bin/mhs bin/mhseval) and set RUNE_HS_MICROHS to its tree; tests/hs/oracles/README.md"},
     {name = "hs-corpus",
      probe = "for t in nhc98 yhc nofib ghc jhc helium uhc haskell-src-exts; do test -d \"$RUNE_HS_CORPUS/$t\" || exit 1; done",
      hint = "clone the trees of tests/hs/corpus/trees.tsv at their commits into one directory, each under its tree's name, and set RUNE_HS_CORPUS to it"}]

  fun command ["hs-oracle", "ghc-shim"] = SOME ghcShim
    | command ["hs-oracle", "conformance", oracle] = SOME (fn () => conformance oracle)
    | command ["hs-oracle", "judge", oracle, set] = SOME (fn () => judge (oracle, set))
    | command ["hs-oracle", "run", oracle, set] = SOME (fn () => runSet (oracle, set))
    | command ["hs-oracle", "stale", oracle] = SOME (fn () => stale oracle)
    | command _ = NONE
end
