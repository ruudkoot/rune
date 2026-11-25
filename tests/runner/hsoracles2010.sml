(* The judges of rhc's Haskell 2010 mode (the haskell2010 roadmap's D39 and
   M2; tests/hs/oracles/README.md, The 2010 oracles): GHC 9.4.7 with the
   Report's library (g10, the shim of tests/hs/oracles/ghc2010-shim, its
   defaulting plugin among it), GHC's own Haskell2010 over base (gbase),
   GHC's default language with each file's own pragmas (gext, for the
   extension corpus), MicroHs for acceptance only, Hugs +98 and nhc98. With
   no rhc they reproduce the evidence of E8 (tests/hs2010/corpus): each
   candidate's verdict in each oracle that E8 asked, after the untrusted-
   code filter (tests/runner/hsfilter.sml), which runs before any of them;
   the 23 probes of what g10 reproduces of the Report, held to the Report;
   and the run tier, built and run, held to E8's record. An outcome that
   differs is a failure unless a line of tests/hs/oracles.txt explains it,
   its label one of h10, h10ext, h10probe and h10run and its reason
   beginning with the outcome it explains; a line that explains no failure
   of a job that ran is stale (tests/runner/hsoracles.sml's machinery,
   which these jobs share). Nightly, by capability: an oracle or a tree
   that is absent skips its jobs with how to get it. What make check holds
   without either is here too: the data whole and agreeing with itself and
   with the oracle file, the filter on planted text, and the filter
   running before a fake oracle. *)
structure HsOracles2010 =
struct
  open Sh

  (* where the jobs read and write, by the environment, or set by a check
     of the harness that runs them in its own process *)
  val outOverride = ref (NONE : string option)
  val dataOverride = ref (NONE : string option)
  val rootOverride = ref (NONE : string option)
  val hackageOverride = ref (NONE : string option)
  (* D40's switch as the jobs see it: the filter's, or a check's *)
  val cpp = ref HsFilter.cppAdmitted
  fun out () = case !outOverride of SOME d => d | NONE => fromRoot (env ("RUNE_HS2010_OUT", run ^ "/hs-oracles2010"))
  fun data () = case !dataOverride of SOME d => d | NONE => env ("RUNE_HS2010_DATA", fromRoot "tests/hs2010/corpus")
  fun root () = case !rootOverride of SOME r => r | NONE => fromRoot (env ("RUNE_HS_CORPUS", ""))
  fun hackage () = case !hackageOverride of SOME r => r | NONE => fromRoot (env ("RUNE_HS_HACKAGE", ""))
  fun tell s = HsOracles.tell s
  exception Failed = HsOracles.Failed
  fun member x xs = List.exists (fn y => y = x) xs

  (* a path of the data: hackage/PACKAGE/... under RUNE_HS_HACKAGE, every
     other under the trees' root *)
  fun place p = if String.isPrefix "hackage/" p then hackage () ^ "/" ^ String.extract (p, 8, NONE) else root () ^ "/" ^ p

  (* ---- The data ---- *)

  exception Bad of string
  fun table file =
    let
      val path = data () ^ "/" ^ file
      val () = if exists path then () else raise Bad ("missing " ^ path)
      val ls = List.filter (fn l => l <> "") (String.fields (fn c => c = #"\n") (read path))
      val header = case ls of h :: _ => String.fields (fn c => c = #"\t") h | [] => raise Bad (file ^ " is empty")
      fun one r =
        let val fs = String.fields (fn c => c = #"\t") r
        in if length fs = length header then ListPair.zip (header, fs)
           else raise Bad (file ^ ": a row of " ^ Int.toString (length fs) ^ " fields, not " ^ Int.toString (length header)
                           ^ ": " ^ String.substring (r, 0, Int.min (80, size r))) end
    in List.map one (tl ls) end
  fun field (row : (string * string) list) k =
    case List.find (fn (h, _) => h = k) row of SOME (_, v) => v | NONE => raise Bad ("no column " ^ k)
  fun byId rows = List.map (fn r => (field r "id", r)) rows
  fun lookup (rs, id) = case List.find (fn (i, _) => i = id) rs of SOME (_, r) => SOME r | NONE => NONE

  type candidate = {id : string, set : string, root : string, mains : string list, tflags : string list, args : string,
                    stdin : string, stdout : string, parent : string, expect : string}
  fun candidate r =
    {id = field r "id", set = field r "set", root = field r "root", mains = String.tokens Char.isSpace (field r "main"),
     tflags = String.tokens Char.isSpace (field r "tflags"), args = field r "args", stdin = field r "stdin",
     stdout = field r "stdout", parent = field r "parent", expect = field r "expect"} : candidate
  fun candidates () = List.map candidate (table "candidates.tsv")

  (* the oracles, and which of them E8 asked of a set's candidates *)
  val oracles = ["g10", "gbase", "gext", "mhs", "hugs", "nhc98"]
  val sets = ["ghc-h2010", "nofib-2025", "mhs-tests", "mhs-src", "h98-corpus", "h98-accept", "hackage"]
  fun perSet "hackage" = ["g10", "gbase", "hugs", "gext"]
    | perSet "mhs-src" = ["g10", "gbase", "gext", "mhs"]
    | perSet "h98-accept" = ["g10", "gbase"]
    | perSet _ = oracles
  (* the labels of the 2010 lines of tests/hs/oracles.txt *)
  val labels = ["h10", "h10ext", "h10probe", "h10run"]
  fun owns (l : Expectations.line) = case #label l of SOME x => member x labels | NONE => false
  fun labelOf oracle = if oracle = "gext" then "h10ext" else "h10"

  (* ---- A candidate's files ---- *)

  (* a path without its . parts and with each .. taken back *)
  fun normal p =
    let
      val abs = String.isPrefix "/" p
      fun go ([], acc) = rev acc
        | go ("" :: xs, acc) = go (xs, acc)
        | go ("." :: xs, acc) = go (xs, acc)
        | go (".." :: xs, _ :: acc) = go (xs, acc)
        | go (x :: xs, acc) = go (xs, x :: acc)
    in (if abs then "/" else "") ^ String.concatWith "/" (go (String.fields (fn c => c = #"/") p, [])) end

  (* the directories a candidate's imports are looked for in: its root;
     Hackage's source directories of the component (the parent, `:`
     between them) before it; another set's parent after it; nofib's
     common directory *)
  fun dirsOf (c : candidate) =
    let val r = normal (place (#root c))
    in
      (if #set c = "hackage" then List.map (fn x => normal (r ^ "/" ^ x)) (String.fields (fn ch => ch = #":") (#parent c)) @ [r]
       else [r] @ (if #parent c <> "-" then [normal (place (#parent c))] else []))
      @ (if #set c = "nofib-2025" then [normal (place "ghc/nofib/common")] else [])
    end
  fun mainsOf (c : candidate) = List.map (fn m => normal (place (#root c) ^ "/" ^ m)) (#mains c)

  fun findLocal (m, dirs) =
    let val p = String.map (fn #"." => #"/" | ch => ch) m
    in List.foldl (fn (d, SOME f) => SOME f
                    | (d, NONE) => List.foldl (fn (e, SOME f) => SOME f
                                                | (e, NONE) => let val f = d ^ "/" ^ p ^ e in if exists f then SOME f else NONE end)
                                              NONE [".hs", ".lhs"]) NONE dirs end

  (* the modules reachable from the mains, each with what it says of
     itself, in the order found; and the imports from elsewhere *)
  fun gather (c : candidate) =
    let
      val dirs = dirsOf c
      fun go ([], seen, ext) = (seen, ext)
        | go (f :: stack, seen, ext) =
            if List.exists (fn (g, _) => g = f) seen then go (stack, seen, ext)
            else
              let
                val s = HsFilter.scan f
                val (local', ext') = List.foldl (fn (m, (l, e)) => case findLocal (m, dirs) of
                                                                     SOME p => (p :: l, e) | NONE => (l, m :: e))
                                                 ([], ext) (#imports s)
              in go (local' @ stack, seen @ [(f, s)], ext') end
      val (seen, ext) = List.foldl (fn (m, (seen, ext)) => go ([m], seen, ext)) ([], []) (mainsOf c)
    in (seen, List.filter (fn m => not (List.exists (fn (_, s : HsFilter.scan) => #module s = m) seen)) (HsSource.dedup ext)) end

  (* the words a candidate is compiled with: its suite's, and with CPP
     admitted a Hackage component's cabal flags *)
  fun flagsOf (c : candidate) =
    #tflags c @ (if !cpp andalso #set c = "hackage" then
                   List.concat (List.map (fn f => HsFilter.cabalFlags (read f)) (glob (place (#root c), ".cabal")))
                 else [])

  (* where a module goes in a copy: a main module at its file's name, any
     other at its module's path *)
  fun placeOf (f, s : HsFilter.scan) =
    if #module s = "Main" then OS.Path.file f
    else String.map (fn #"." => #"/" | ch => ch) (#module s) ^ (if String.isSuffix ".lhs" f then ".lhs" else ".hs")

  (* the copy of a candidate in `work`: each module with its pragmas
     blanked (LANGUAGE too, but in the extension variant), the boot files
     its SOURCE imports name, and for g10 `import RebindableH2010` where a
     module's Prelude import needs it; the mains' paths in it *)
  fun prepare (c : candidate, seen : (string * HsFilter.scan) list, {ext, rebind}, work) =
    let
      val () = (rmTree work; mkdirs work)
      val blank = if ext then HsFilter.blankOptions else HsFilter.blankPragmas
      fun copy (src, dst) = (mkdirs (OS.Path.dir dst); write (dst, blank (HsSource.universal (read src))))
      fun one (f, s : HsFilter.scan) =
        let
          val q = work ^ "/" ^ placeOf (f, s)
          val t = blank (HsSource.universal (read f))
          val code = HsFilter.stripComments (if #lhs s then HsSource.unlit t else t)
          val t = if rebind andalso HsFilter.needsRebind code then HsFilter.inject t else t
        in
          mkdirs (OS.Path.dir q); write (q, t);
          List.app (fn b =>
            List.app (fn d => List.app (fn e =>
              let val p = String.map (fn #"." => #"/" | ch => ch) b ^ e
              in if exists (d ^ "/" ^ p) then copy (d ^ "/" ^ p, work ^ "/" ^ p) else () end) [".hs-boot", ".lhs-boot"])
              (OS.Path.dir f :: dirsOf c)) (#boot s)
        end
      val () = List.app one seen
    in
      List.map (fn m => case List.find (fn (f, _) => f = m) seen of
                          SOME x => placeOf x
                        | NONE => raise Failed ("no module " ^ m)) (mainsOf c)
    end

  (* ---- The oracles ---- *)

  val openPackages = ["base", "array", "containers", "mtl", "transformers", "directory", "process", "time", "bytestring",
                      "deepseq", "stm", "text", "parsec", "unix", "filepath"]
  fun shimDir () = out () ^ "/ghc2010-shim"
  fun mhsShim () = fromRoot "tests/hs/oracles/mhs2010-shim"
  fun mhsCache () = out () ^ "/mhs2010.cache"
  fun flags "g10" = ["-XHaskell2010", "-XRebindableSyntax", "-XImplicitPrelude", "-hide-all-packages",
                     "-package-db", shimDir () ^ "/db", "-package", "haskell2010-report",
                     "-package-db", shimDir () ^ "/pdb", "-plugin-package", "h2010-default", "-fplugin=H2010Default"]
    | flags "gbase" = ["-XHaskell2010", "-hide-all-packages"] @ List.concat (List.map (fn p => ["-package", p]) openPackages)
    | flags _ = []
  val cLocale = [("LC_ALL", "C")]
  fun ghcCheck log oracle (dir, mains, extra) =
    HsOracles.ok (HsOracles.call log {cmd = [HsOracles.ghc ()] @ flags oracle @ extra @ tl mains
                                             @ ["-fno-code", "-w", "-outputdir", ".ghcnc", hd mains],
                                      dir = dir, stdin = "", timeout = 300, changes = cLocale})
  fun ghcBuild log oracle (dir, mains, extra, timeout) =
    HsOracles.ok (HsOracles.call log {cmd = [HsOracles.ghc ()] @ flags oracle @ extra @ tl mains
                                             @ ["-O0", "-w", "-outputdir", ".ghc", "-o", "Main.ghc", hd mains],
                                      dir = dir, stdin = "", timeout = timeout, changes = cLocale})
    andalso exists (dir ^ "/Main.ghc")
  fun mhsCheck log (dir, main, lib) =
    HsOracles.ok (HsOracles.call log {cmd = [HsOracles.mhsDir () ^ "/bin/mhs", "-i.", "-i" ^ mhsShim (), "-i" ^ HsOracles.mhsDir () ^ "/lib",
                                             "-CR" ^ mhsCache ()] @ (if lib then ["-c"] else ["-oMain.comb"]) @ [main],
                                      dir = dir, stdin = "", timeout = 300, changes = []})
  (* Hugs at its prompt, one main or several *)
  fun hugsCheck log (dir, mains) =
    case mains of
      [m] => HsOracles.hugsCheck log (dir, m, ["+98"], 120)
    | _ =>
        let
          val q = dir ^ "/.hugsq"
          val () = write (q, ":q\n")
          val r = HsOracles.call log {cmd = [HsOracles.hugsDir () ^ "/src/hugs", "+98", "-h16M"] @ mains, dir = dir, stdin = q,
                                      timeout = 300, changes = HsOracles.hugsEnv ()}
        in not (String.isSubstring "ERROR" (#output r ^ #errors r)) andalso #status r <> 124 end
  (* nhc98 compiles the main without linking: what it made is there *)
  fun nhcCheck log (dir, main) =
    let val obj = (if String.isSuffix ".lhs" main then String.substring (main, 0, size main - 4)
                   else if String.isSuffix ".hs" main then String.substring (main, 0, size main - 3) else main) ^ ".o"
    in HsOracles.ok (HsOracles.hmake log (dir, main, ["-H64M"], 600)) andalso exists (dir ^ "/" ^ obj) end

  (* an oracle prints hello first, or judges nothing *)
  fun probe oracle =
    if member oracle ["hugs", "nhc98"] then HsOracles.probe oracle
    else
      let
        val d = out () ^ "/" ^ oracle ^ "/probe-" ^ HsOracles.pid ()
        val () = (rmTree d; mkdirs d)
        val () = write (d ^ "/Main.hs", "main = putStrLn \"hello\"\n")
        val log = d ^ "/log"
        val r = if oracle = "mhs" then
                  if mhsCheck log (d, "Main.hs", false) then
                    SOME (HsOracles.call log {cmd = [HsOracles.mhsDir () ^ "/bin/mhseval", "+RTS", "-rMain.comb", "-RTS"], dir = d,
                                              stdin = "", timeout = 60, changes = []})
                  else NONE
                else if ghcBuild log oracle (d, ["Main.hs"], [], 300) then
                  SOME (HsOracles.call log {cmd = [d ^ "/Main.ghc"], dir = d, stdin = "", timeout = 60, changes = []})
                else NONE
      in
        case r of
          SOME {status = 0, output = "hello\n", ...} => true
        | SOME r => (tell ("FAIL " ^ oracle ^ " does not run hello: exit " ^ Int.toString (#status r) ^ " (" ^ d ^ ")\n"); false)
        | NONE => (tell ("FAIL " ^ oracle ^ " does not build hello: " ^ firstNonEmpty (log ^ ".err") ^ firstNonEmpty (log ^ ".out")
                        ^ " (" ^ d ^ ")\n"); false)
      end

  (* the trees a job reads are at the commits trees.tsv pins; a Hackage
     package is there *)
  fun pinned (cs : candidate list) =
    let
      val trees = table "trees.tsv"
      fun treeOf p =
        List.foldl (fn (r, best) => let val t = field r "tree"
                                    in if String.isPrefix (t ^ "/") p andalso size t > (case best of SOME b => size (field b "tree") | NONE => 0)
                                       then SOME r else best end) NONE trees
      val used = HsSource.dedup (List.map #root cs)
      fun check r =
        let val t = field r "tree"
        in
          if t = "hackage" then ()
          else
            let val d = place t
            in
              if not (isDir d) then raise Failed ("the tree " ^ d ^ " is not there (RUNE_HS_CORPUS)")
              else if not (exists (d ^ "/.git")) then ()
              else
                let val g = HsOracles.call (out () ^ "/git/" ^ String.map (fn #"/" => #"_" | ch => ch) t ^ "." ^ HsOracles.pid ())
                                           {cmd = ["git", "-C", d, "rev-parse", "HEAD"], dir = d, stdin = "", timeout = 60, changes = []}
                in if HsOracles.trim (#output g) = field r "commit" then ()
                   else raise Failed (d ^ " is at " ^ HsOracles.trim (#output g) ^ ", where the evidence is of " ^ field r "commit") end
            end
        end
      val rs = List.map (fn p => case treeOf p of SOME r => r | NONE => raise Failed ("no tree for " ^ p)) used
    in
      List.app check (List.foldl (fn (r, acc) => if List.exists (fn x => field x "tree" = field r "tree") acc then acc else acc @ [r]) [] rs);
      List.app (fn p => if String.isPrefix "hackage/" p andalso not (isDir (place p))
                        then raise Failed ("the package " ^ place p ^ " is not there (RUNE_HS_HACKAGE)") else ()) used
    end

  (* ---- E8's verdicts ---- *)

  fun safe id = String.map (fn ch => if HsSource.isWord ch orelse Char.contains ".+-" ch then ch else #"_") id

  (* what E8 recorded of a candidate in an oracle: filtered, accept,
     reject, or nothing where it did not ask *)
  fun recorded (r, oracle) = if field r "untrusted" <> "" then "filtered" else field r oracle

  fun judgeOne (oracle, judged) (c : candidate) =
    let
      val id = #id c
      val r = case lookup (judged, id) of SOME r => r | NONE => raise Failed ("no record of " ^ id)
      val want = recorded (r, oracle)
      val work = out () ^ "/" ^ oracle ^ "/judge/" ^ safe id
      val log = out () ^ "/" ^ oracle ^ "/logs/" ^ safe id
      val (seen, _) = gather c
      val why = HsFilter.untrustedWith {cpp = !cpp} (List.map #2 seen, flagsOf c)
      val mains = #mains c
      val asked = member oracle (perSet (#set c)) andalso (length mains = 1 orelse not (member oracle ["mhs", "nhc98"]))
      fun outcome got = SOME {oracle = oracle, id = id, label = labelOf oracle, got = got, want = want, passed = got = want}
                        : HsOracles.outcome option
      val result =
        if why <> "" then outcome "filtered"
        else if not asked then (if want = "" then NONE else outcome "unasked")
        else
          let
            val ms = prepare (c, seen, {ext = oracle = "gext", rebind = oracle = "g10"}, work)
            val mainScan = #2 (valOf (List.find (fn (f, _) => f = hd (mainsOf c)) seen))
            val ok =
              case oracle of
                "mhs" => mhsCheck log (work, hd ms, #module mainScan <> "Main")
              | "hugs" => hugsCheck log (work, ms)
              | "nhc98" => nhcCheck log (work, hd ms)
              | "gext" => ghcCheck log oracle (work, ms, List.filter (fn w => String.isPrefix "-X" w) (#tflags c))
              | _ => ghcCheck log oracle (work, ms, [])
          in outcome (if ok then "accept" else "reject") end
    in rmTree work; result end
    handle e as HsOracles.Failed _ => raise e
         | e => (HsOracles.note (out () ^ "/" ^ oracle ^ "/logs/" ^ safe (#id c) ^ ".exn", exnText e ^ "\n");
                 SOME {oracle = oracle, id = #id c, label = labelOf oracle, got = "harness-error", want = "", passed = false})

  fun withOut f = (HsOracles.outOverride := SOME (out ()); f ())

  fun judge (oracle, set) =
    withOut (fn () =>
      let
        val cs = List.filter (fn (c : candidate) => #set c = set andalso HsOracles.only (#id c)) (candidates ())
        val () = pinned cs
      in
        if probe oracle then
          let val judged = byId (table "judged.tsv")
          in HsOracles.report (oracle, "judge-" ^ set, List.mapPartial (judgeOne (oracle, judged)) cs) end
        else ()
      end)
    handle HsOracles.Failed m => tell ("FAIL " ^ oracle ^ " judge " ^ set ^ ": " ^ m ^ "\n")
         | Bad m => tell ("FAIL " ^ oracle ^ " judge " ^ set ^ ": " ^ m ^ "\n")

  (* ---- The probes of the shim's limits, held to the Report ---- *)

  (* a program's output as E8 recorded it: stripped, a failing status and
     the start of what it said after it, each newline " / " *)
  fun shown (r : HsOracles.ran) =
    let val text = HsOracles.trim (#output r)
                   ^ (if #status r <> 0 then " [rc " ^ HsOracles.statusWord (#status r) ^ ": "
                                             ^ (let val e = HsOracles.trim (#errors r) in String.substring (e, 0, Int.min (80, size e)) end) ^ "]"
                      else "")
    in String.concatWith " / " (String.fields (fn ch => ch = #"\n") text) end

  fun probeOne oracle r =
    let
      val name = field r "probe"
      val d = out () ^ "/" ^ oracle ^ "/probes/" ^ name
      val () = (rmTree d; mkdirs d)
      val () = HsCorpus.copyFile (data () ^ "/limits/" ^ name ^ ".hs", d ^ "/Main.hs")
      val log = out () ^ "/" ^ oracle ^ "/logs/probe-" ^ name
      val report = field r "report"
      val got =
        case oracle of
          "hugs" => if HsOracles.hugsCheck log (d, "Main.hs", ["+98"], 120) then "accept" else "reject"
        | "nhc98" => if nhcCheck log (d, "Main.hs") then "accept" else "reject"
        | "mhs" => if mhsCheck log (d, "Main.hs", false) then "accept" else "reject"
        | _ =>
            if not (ghcBuild log oracle (d, ["Main.hs"], [], 300)) then "reject"
            else if report = "reject" then "accept"
            else
              let val ran = HsOracles.call log {cmd = [d ^ "/Main.ghc"], dir = d, stdin = "", timeout = 60, changes = [("LC_ALL", "C.UTF-8")]}
              in if shown ran = field r "report_out" then "accept" else "output" end
    in {oracle = oracle, id = "limits/" ^ name, label = "h10probe", got = got, want = report, passed = got = report} : HsOracles.outcome end

  fun probes oracle =
    withOut (fn () => if probe oracle then HsOracles.report (oracle, "probes", List.map (probeOne oracle) (table "limits.tsv")) else ())
    handle HsOracles.Failed m => tell ("FAIL " ^ oracle ^ " probes: " ^ m ^ "\n")
         | Bad m => tell ("FAIL " ^ oracle ^ " probes: " ^ m ^ "\n")

  (* ---- The run tier, held to E8's record ---- *)

  fun runOne oracle (r, c : candidate) =
    let
      val id = #id c
      val work = out () ^ "/" ^ oracle ^ "/run/" ^ safe id
      val log = out () ^ "/" ^ oracle ^ "/logs/" ^ safe id ^ ".run"
      val (seen, _) = gather c
      val ms = prepare (c, seen, {ext = false, rebind = oracle = "g10"}, work)
      val src = place (#root c)
      (* the data beside it: a nofib program's whole directory, else the
         files named after its main; its input and its expected output *)
      val stem = OS.Path.base (hd (#mains c))
      val names = List.filter (fn n => not (isDir (src ^ "/" ^ n)) andalso exists (src ^ "/" ^ n)) (sort (entries src))
      val extra = if #set c = "nofib-2025" then List.filter (fn n => not (String.isSuffix ".hs" n orelse String.isSuffix ".lhs" n)) names
                  else List.filter (fn n => String.isPrefix (stem ^ ".") n) names
      val () = List.app (fn f => if f <> "" andalso not (exists (work ^ "/" ^ f)) andalso exists (src ^ "/" ^ f) andalso not (isDir (src ^ "/" ^ f))
                                 then HsCorpus.copyFile (src ^ "/" ^ f, work ^ "/" ^ OS.Path.file f) else ())
                        (extra @ [#stdin c, #stdout c])
      val () = if #set c = "nofib-2025" then
                 List.app (fn n => if isDir (src ^ "/" ^ n) andalso not (exists (work ^ "/" ^ n)) then HsCorpus.copyTree (src ^ "/" ^ n, work ^ "/" ^ n) else ())
                          (sort (entries src))
               else ()
      val mainScan = #2 (valOf (List.find (fn (f, _) => f = hd (mainsOf c)) seen))
      val mainIs = if #module mainScan <> "Main" then ["-main-is", #module mainScan] else []
      val expected = HsSource.universal (read (src ^ "/" ^ #stdout c))
      val got =
        if not (ghcBuild log oracle (work, ms, mainIs, 1200)) then "fail"
        else
          let val ran = HsOracles.call log {cmd = (work ^ "/Main.ghc") :: String.tokens Char.isSpace (#args c), dir = work,
                                            stdin = if #stdin c = "" then "" else work ^ "/" ^ #stdin c, timeout = 600,
                                            changes = [("LC_ALL", "C.UTF-8")]}
          in "ok/" ^ HsOracles.statusWord (#status ran) ^ "/" ^ HsOracles.same (expected, #output ran) end
      val want = if field r "build" = "fail" then "fail" else "ok/" ^ field r "rc" ^ "/" ^ field r "out"
    in rmTree work; {oracle = oracle, id = id, label = "h10run", got = got, want = want, passed = got = want} : HsOracles.outcome end
    handle e as HsOracles.Failed _ => raise e
         | e => (HsOracles.note (out () ^ "/" ^ oracle ^ "/logs/" ^ safe (#id c) ^ ".exn", exnText e ^ "\n");
                 {oracle = oracle, id = #id c, label = "h10run", got = "harness-error", want = "", passed = false})

  fun runTier oracle =
    withOut (fn () =>
      let
        val cs = byId (table "candidates.tsv")
        val rows = List.filter (fn r => field r "variant" = oracle andalso HsOracles.only (field r "id")) (table "run.tsv")
        val pairs = List.map (fn r => (r, candidate (case lookup (cs, field r "id") of SOME c => c
                                                                                     | NONE => raise Failed ("no candidate " ^ field r "id")))) rows
        val () = pinned (List.map #2 pairs)
      in if probe oracle then HsOracles.report (oracle, "run", List.map (runOne oracle) pairs) else () end)
    handle HsOracles.Failed m => tell ("FAIL " ^ oracle ^ " run: " ^ m ^ "\n")
         | Bad m => tell ("FAIL " ^ oracle ^ " run: " ^ m ^ "\n")

  fun stale oracle = withOut (fn () => HsOracles.stale oracle)

  (* ---- The shim, and MicroHs's cache ---- *)

  val reportModules =
    ["Prelude", "Control.Monad", "Data.Array", "Data.Bits", "Data.Char", "Data.Complex", "Data.Int", "Data.Ix", "Data.List",
     "Data.Maybe", "Data.Ratio", "Data.Word", "Foreign", "Foreign.C", "Foreign.C.Error", "Foreign.C.String", "Foreign.C.Types",
     "Foreign.ForeignPtr", "Foreign.Marshal", "Foreign.Marshal.Alloc", "Foreign.Marshal.Array", "Foreign.Marshal.Error",
     "Foreign.Marshal.Utils", "Foreign.Ptr", "Foreign.StablePtr", "Foreign.Storable", "Numeric", "System.Environment",
     "System.Exit", "System.IO", "System.IO.Error"]
  val hiddenModules = ["H2010.Classes", "H2010.Bits", "H2010.Instances"]

  (* two package databases, as E8's build.sh made them: pdb, the defaulting
     plugin h2010-default, static and shared; db, haskell2010-report, the
     Prelude and the Report's 30 modules over base and array *)
  fun ghcShim () =
    withOut (fn () =>
      let
        val s = fromRoot "tests/hs/oracles/ghc2010-shim"
        val d = shimDir ()
        val log = d ^ "/log"
        val () = (rmTree d; mkdirs d)
        fun run' (what, cmd, dir) =
          let val r = HsOracles.call log {cmd = cmd, dir = dir, stdin = "", timeout = 1800, changes = []}
          in if HsOracles.ok r then r
             else raise Failed (what ^ " failed: " ^ String.concatWith " / " (List.take (lines (#errors r ^ #output r),
                                                     Int.min (8, length (lines (#errors r ^ #output r)))))) end
        val ghc = HsOracles.ghc ()
        val pkg = HsOracles.ghcPkg ()
        fun id p = HsOracles.trim (#output (run' ("ghc-pkg field " ^ p, [pkg, "field", p, "id", "--simple-output"], d)))
        val version = HsOracles.trim (#output (run' ("ghc --numeric-version", [ghc, "--numeric-version"], d)))
        val p = d ^ "/pbuild"
        val () = mkdirs p
        val _ = run' ("the plugin", [ghc, "-c", "-O", "-package", "ghc", "-package", "containers", "-dynamic-too", "-this-unit-id",
                                     "h2010-default-1.0", "-odir", p, "-hidir", p, "-i" ^ s ^ "/plugin", s ^ "/plugin/H2010Default.hs"], d)
        val _ = run' ("ar", ["ar", "rcs", p ^ "/libHSh2010-default-1.0.a", p ^ "/H2010Default.o"], d)
        val _ = run' ("the plugin's shared library", [ghc, "-shared", "-dynamic", "-o", p ^ "/libHSh2010-default-1.0-ghc" ^ version ^ ".so",
                                                      p ^ "/H2010Default.dyn_o", "-package", "ghc", "-package", "containers"], d)
        val _ = run' ("ghc-pkg init", [pkg, "init", d ^ "/pdb"], d)
        val () = write (p ^ "/pkg.conf", String.concat
          ["name: h2010-default\nversion: 1.0\nid: h2010-default-1.0\nkey: h2010-default-1.0\nexposed: True\n",
           "exposed-modules: H2010Default\nimport-dirs: ", p, "\nlibrary-dirs: ", p, "\ndynamic-library-dirs: ", p,
           "\nhs-libraries: HSh2010-default-1.0\ndepends: ", String.concatWith " " (List.map id ["ghc", "containers", "base"]), "\n"])
        val _ = run' ("ghc-pkg register", [pkg, "--package-db", d ^ "/pdb", "register", p ^ "/pkg.conf", "--force", "-v0"], d)
        val b = d ^ "/build"
        val () = mkdirs b
        fun file m = String.map (fn #"." => #"/" | ch => ch) m ^ ".hs"
        val mods = reportModules @ ["RebindableH2010"]
        val _ = run' ("ghc --make haskell2010-report",
                      [ghc, "--make", "-this-unit-id", "haskell2010-report-1.0", "-hide-all-packages", "-package", "base", "-package",
                       "array", "-XHaskell2010", "-O0", "-odir", b, "-hidir", b, "-w"] @ List.map file (mods @ hiddenModules), s ^ "/src")
        val _ = run' ("ar", ["ar", "rcs", b ^ "/libHShaskell2010-report-1.0.a"]
                            @ List.filter (fn f => String.isSuffix ".o" f) (HsCorpus.allFiles b), d)
        val _ = run' ("ghc-pkg init", [pkg, "init", d ^ "/db"], d)
        val () = write (b ^ "/pkg.conf", String.concat
          ["name: haskell2010-report\nversion: 1.0\nid: haskell2010-report-1.0\nkey: haskell2010-report-1.0\nexposed: True\n",
           "exposed-modules: ", String.concatWith " " mods, "\nhidden-modules: ", String.concatWith " " hiddenModules,
           "\nimport-dirs: ", b, "\nlibrary-dirs: ", b, "\nhs-libraries: HShaskell2010-report-1.0\ndepends: ",
           String.concatWith " " (List.map id ["base", "array"]), "\n"])
        val _ = run' ("ghc-pkg register", [pkg, "--package-db", d ^ "/db", "register", b ^ "/pkg.conf", "--force", "-v0"], d)
      in tell ("PASS the 2010 shim: " ^ d ^ "/db, plugin " ^ d ^ "/pdb\n") end)
    handle HsOracles.Failed m => tell ("FAIL the 2010 shim: " ^ m ^ "\n")

  (* MicroHs's cache of its library and the shim's Data.Array, warmed by a
     program that imports every module of the Report *)
  fun mhsCacheJob () =
    withOut (fn () =>
      let
        val d = out () ^ "/mhs2010-build"
        val () = (rmTree d; mkdirs d; (OS.FileSys.remove (mhsCache ()) handle OS.SysErr _ => ()))
        val () = write (d ^ "/All2010.hs", "module Main where\n" ^ String.concat (List.map (fn m => "import " ^ m ^ "\n") (tl reportModules))
                                           ^ "main :: IO ()\nmain = print (listArray (0, 2) \"abc\" ! (1 :: Int))\n")
        val log = d ^ "/log"
        val m = HsOracles.mhsDir ()
        val r = HsOracles.call log {cmd = [m ^ "/bin/mhs", "-i.", "-i" ^ mhsShim (), "-i" ^ m ^ "/lib", "-C" ^ mhsCache (), "-oAll2010.comb", "All2010.hs"],
                                    dir = d, stdin = "", timeout = 1800, changes = []}
        val ran = if HsOracles.ok r then SOME (HsOracles.call log {cmd = [m ^ "/bin/mhseval", "+RTS", "-rAll2010.comb", "-RTS"], dir = d,
                                                                 stdin = "", timeout = 300, changes = []})
                  else NONE
      in
        case ran of
          SOME {status = 0, output = "'b'\n", ...} => tell ("PASS MicroHs's 2010 cache: " ^ mhsCache () ^ "\n")
        | _ => tell ("FAIL MicroHs's 2010 cache: " ^ firstNonEmpty (log ^ ".err") ^ firstNonEmpty (log ^ ".out") ^ " (" ^ d ^ ")\n")
      end)

  (* ---- The filter over the trees ---- *)

  (* hs2010-corpus/filter: the filter, run on every candidate before any
     oracle, refuses exactly what E8's did, for E8's reasons; and how many
     of the CPP candidates include a file, which D40's B keeps out for good *)
  val errors = ref [] : string list ref
  fun need (ok, why) = if ok then () else errors := why :: !errors
  fun finish what =
    (List.app (fn m => tell ("FAIL " ^ what ^ ": " ^ m ^ "\n")) (rev (!errors));
     if null (!errors) then tell ("PASS " ^ what ^ "\n") else ();
     errors := [])

  fun filterTrees () =
    let
      val judged = byId (table "judged.tsv")
      val cs = candidates ()
      val () = pinned cs
      val counts = ref (0, 0, 0)
      fun one (c : candidate) =
        let
          val (seen, _) = gather c
          val scans = List.map #2 seen
          val why = HsFilter.untrustedWith {cpp = false} (scans, #tflags c)
          val admitted = HsFilter.untrustedWith {cpp = true} (scans, #tflags c @ List.concat (List.map (fn f => HsFilter.cabalFlags (read f))
                                                                                                         (if #set c = "hackage" then glob (place (#root c), ".cabal") else [])))
          val want = case lookup (judged, #id c) of SOME r => field r "untrusted" | NONE => "?"
          val (n, inc, adm) = !counts
          val cppish = String.isSubstring "CPP" why
        in
          counts := (if cppish then n + 1 else n, if cppish andalso List.exists #includes scans then inc + 1 else inc,
                     if cppish andalso admitted = "" then adm + 1 else adm);
          need (why = want, #id c ^ ": the filter says " ^ (if why = "" then "nothing" else why) ^ ", where E8's said "
                            ^ (if want = "" then "nothing" else want))
        end
        handle e => need (false, #id c ^ ": " ^ exnText e)
    in
      List.app one cs;
      let val (n, inc, adm) = !counts
      in tell ("filter: " ^ Int.toString n ^ " candidates kept out for CPP, " ^ Int.toString inc ^ " of them including a file; "
               ^ Int.toString adm ^ " would be admitted with D40's switch on\n") end;
      finish "the 2010 filter on the trees"
    end
    handle Bad m => (need (false, m); finish "the 2010 filter on the trees")
         | HsOracles.Failed m => (need (false, m); finish "the 2010 filter on the trees")

  (* ---- The data (make check) ---- *)

  fun vendoredRoot () = data () ^ "/vendored"
  fun licenceRows () = table "licences.tsv"
  (* a vendored program's files, by their paths under the trees' root *)
  fun vendoredFiles (c : candidate) =
    List.map (fn m => #root c ^ "/" ^ m) (#mains c) @ (if #stdout c <> "" then [#root c ^ "/" ^ #stdout c] else [])
    @ (if #stdin c <> "" then [#root c ^ "/" ^ #stdin c] else [])
  fun walk d = List.concat (List.map (fn n => let val p = d ^ "/" ^ n in if isDir p then walk p else [p] end) (sort (entries d)))
  fun relative (base, p) = if String.isPrefix (base ^ "/") p then String.extract (p, size base + 1, NONE) else p
  fun noticeOf (rootDir, f) =
    let fun up d = if d = "" orelse d = "." then NONE
                   else case List.find (fn n => exists (rootDir ^ "/" ^ d ^ "/" ^ n)) ["PROVENANCE", "LICENSE"] of
                          SOME n => SOME (d ^ "/" ^ n)
                        | NONE => up (OS.Path.dir d)
    in up (OS.Path.dir f) end

  fun count p xs = List.length (List.filter p xs)
  fun distinct xs = length (HsSource.dedup xs) = length xs

  fun dataCheck () =
    let
      val cands = table "candidates.tsv"
      val judged = table "judged.tsv"
      val accept = table "accept.tsv"
      val reject = table "reject.tsv"
      val runs = table "run.tsv"
      val filtered = table "filtered.tsv"
      val extc = table "extcorpus.tsv"
      val limits = table "limits.tsv"
      val lic = licenceRows ()
      val trees = table "trees.tsv"
      val hk = table "hackage.tsv"
      val ids = List.map (fn r => field r "id")
      val cids = ids cands
      val jd = byId judged
      val () = need (length cands = 3217 andalso distinct cids, "candidates.tsv is not E8's 3,217 candidates, each once")
      val () = need (length judged = 3217 andalso sort (ids judged) = sort cids, "judged.tsv is not a row for each candidate")
      val () = List.app (fn r => need (member (field r "set") sets, field r "id" ^ ": no set " ^ field r "set")) cands
      (* each candidate in a tree that lists its set *)
      val () = List.app (fn r =>
                 need (List.exists (fn t => String.isPrefix (field t "tree" ^ "/") (field r "root")
                                            andalso member (field r "set") (String.tokens Char.isSpace (field t "sets"))) trees,
                       field r "id" ^ ": its root " ^ field r "root" ^ " is in no tree of trees.tsv that lists its set")) cands
      (* the verdicts: an oracle E8 asked accepts or refuses; a filtered
         candidate goes to none, but the two the filter caught late, after
         GHC had judged them with CPP off (untrusted_late) *)
      val () = List.app (fn r =>
                 let val f = field r "untrusted" <> ""
                 in List.app (fn o' => need (if f andalso field r "untrusted_late" = "" then field r o' = ""
                                             else member (field r o') ["", "accept", "reject"],
                                             field r "id" ^ ": " ^ o' ^ " says " ^ field r o')) oracles;
                    need (f = (field r "class" = "filtered"), field r "id" ^ ": filtered, or its class says it is")
                 end) judged
      val fids = ids (List.filter (fn r => field r "untrusted" <> "") judged)
      val () = need (length filtered = 167 andalso ids filtered = fids
                     andalso List.all (fn r => case lookup (jd, field r "id") of SOME j => field j "untrusted" = field r "untrusted" | NONE => false) filtered,
                     "filtered.tsv is not judged.tsv's 167 filtered candidates and their reasons")
      fun agrees (r, cols) = case lookup (jd, field r "id") of
                               SOME j => List.all (fn (c, k) => field r c = field j k) cols
                             | NONE => false
      val () = need (length accept = 1279, "accept.tsv has " ^ Int.toString (length accept) ^ " rows, not E8's 1,279")
      val () = List.app (fn r => need (agrees (r, [("set", "set"), ("gbase", "gbase"), ("mhs", "mhs"), ("hugs", "hugs"), ("nhc98", "nhc98")])
                                       andalso (case lookup (jd, field r "id") of SOME j => field j "g10" = "accept" andalso field j "plain" = "yes" | NONE => false),
                                       "accept.tsv: " ^ field r "id" ^ " is not a plain candidate g10 accepts, as judged.tsv has it")) accept
      val bySet = List.map (fn s => (s, count (fn r => field r "set" = s) accept)) ["ghc-h2010", "h98-accept", "hackage", "mhs-tests", "nofib-2025"]
      val () = need (bySet = [("ghc-h2010", 32), ("h98-accept", 816), ("hackage", 355), ("mhs-tests", 27), ("nofib-2025", 49)],
                     "accept.tsv's sets are not E8's: ghc-h2010 32, h98-accept 816, hackage 355, mhs-tests 27, nofib-2025 49")
      val () = need (length reject = 882, "reject.tsv has " ^ Int.toString (length reject) ^ " rows, not E8's 882")
      val () = List.app (fn r => need (agrees (r, [("set", "set"), ("class", "class"), ("gbase", "gbase")])
                                       andalso (case lookup (jd, field r "id") of SOME j => field j "g10" = "reject" andalso field j "plain" = "yes" | NONE => false),
                                       "reject.tsv: " ^ field r "id" ^ " is not a plain candidate g10 refuses, as judged.tsv has it")) reject
      val () = need (distinct (ids accept @ ids reject), "a candidate is in accept.tsv and reject.tsv")
      (* the run tier: a run candidate, built with g10 where g10 accepts it *)
      val () = need (length runs = 90 andalso distinct (ids runs), "run.tsv is not E8's 90 programs, each once")
      val () = List.app (fn r =>
                 need (case (lookup (byId cands, field r "id"), lookup (jd, field r "id")) of
                         (SOME c, SOME j) => field c "expect" = "run" andalso field c "stdout" = field r "stdout"
                                             andalso field r "variant" = (if field j "g10" = "accept" then "g10" else "gbase")
                       | _ => false,
                       "run.tsv: " ^ field r "id" ^ " is not a run candidate built with g10 where g10 accepts it, else gbase")) runs
      val () = need (length extc = 1198 andalso List.all (fn r => member (field r "id") cids) extc,
                     "extcorpus.tsv is not E8's 1,198 rows, each of a candidate")
      (* the probes, each a program of limits/ *)
      val probeNames = List.map (fn r => field r "probe") limits
      val () = need (length limits = 23 andalso distinct probeNames, "limits.tsv is not E8's 23 probes")
      val () = List.app (fn n => need (exists (data () ^ "/limits/" ^ n ^ ".hs"), "limits/" ^ n ^ ".hs is missing")) probeNames
      (* the recipe of the Hackage set: every package its components name *)
      val pkgs = HsSource.dedup (List.mapPartial (fn r => if field r "set" = "hackage"
                                                          then SOME (hd (String.tokens (fn ch => ch = #"/") (String.extract (field r "root", 8, NONE))))
                                                          else NONE) cands)
      val () = need (List.map (fn r => field r "package") hk = pkgs
                     andalso List.all (fn r => size (field r "sha256") = 64 andalso CharVector.all Char.isHexDigit (field r "sha256")) hk,
                     "hackage.tsv is not the Hackage components' packages, each with its tarball's sha256")
      (* the survey: a row a program of the run tier; vendored, the new 2010
         programs (g10, right, at most 1 s, not nofib's), under the LICENSE
         it names, the nearest above each of its files *)
      val () = need (ids lic = ids runs, "licences.tsv is not a row for each program of run.tsv, in its order")
      fun newRun r = field r "variant" = "g10" andalso field r "set" <> "nofib-2025" andalso field r "rc" = "0"
                     andalso member (field r "out") ["same", "same-ws", "close"]
                     andalso (case Real.fromString (field r "cpu_s") of SOME s => s <= 1.0 | NONE => false)
      val vend = List.filter (fn r => field r "vendor" = "vendored") lic
      val () = need (ids vend = ids (List.filter newRun runs) andalso length vend = 25,
                     "licences.tsv's vendored rows are not the 25 new 2010 run programs")
      val () = List.app (fn r => need (member (field r "vendor") ["vendored", "outside"] andalso field r "note" <> "",
                                       "licences.tsv: " ^ field r "id" ^ " is vendored or outside, with why")) lic
      val vroot = vendoredRoot ()
      val vfiles = List.concat (List.map (fn r =>
                     let val c = candidate (valOf (lookup (byId cands, field r "id")))
                         val fs = vendoredFiles c
                     in List.app (fn f => need (noticeOf (vroot, f) = SOME (field r "notice"),
                                                "vendored/" ^ f ^ ": not under its notice " ^ field r "notice")) fs;
                        fs end) vend)
      val notices = HsSource.dedup (List.map (fn r => field r "notice") vend)
      val () = List.app (fn n => need (OS.Path.file n = "LICENSE", "vendored/" ^ n ^ ": a 2010 run program lands under its tree's LICENSE")) notices
      val expected = List.map (fn f => "vendored/" ^ f) (vfiles @ notices)
      val () = List.app (fn f => need (exists (data () ^ "/" ^ f), f ^ " is missing")) expected
      (* nothing lands here but this data, the probes and the vendored
         programs with their notices *)
      val own = ["README.md", "trees.tsv", "candidates.tsv", "judged.tsv", "accept.tsv", "reject.tsv", "run.tsv", "filtered.tsv",
                 "extcorpus.tsv", "limits.tsv", "licences.tsv", "hackage.tsv"] @ List.map (fn n => "limits/" ^ n ^ ".hs") probeNames
      val () = List.app (fn p => let val r = relative (data (), p)
                                 in need (member r own orelse member r expected,
                                          r ^ " is under tests/hs2010/corpus, and is neither its data, a probe nor a vendored program's file or notice") end)
                        (walk (data ()))
    in finish "the 2010 corpus data" end
    handle Bad m => (need (false, m); finish "the 2010 corpus data")

  (* the 2010 lines of tests/hs/oracles.txt against the record: each names
     an oracle and a candidate, probe or run that it has a record for, and
     an outcome other than the record's (a probe's: the Report's); and each
     probe on which E8 recorded an oracle departing from the Report has its
     line, so that g10's limits stand in the file *)
  fun oraclesText () =
    let
      val ls = List.filter owns (Expectations.read (HsOracles.oraclesFile ()))
      val judged = table "judged.tsv"
      val runs = table "run.tsv"
      val limits = table "limits.tsv"
      (* what E8 recorded of a probe in an oracle: its verdict, or output
         where it ran and printed other than the Report says *)
      fun probeRecord (r, o') =
        let val v = field r o'
        in if member o' ["g10", "gbase"] andalso v = "accept" andalso field r "report" = "accept"
              andalso field r (o' ^ "_out") <> field r "report_out" then "output"
           else v end
      fun hits (l : Expectations.line) =
        case #label l of
          SOME "h10probe" => List.mapPartial (fn r => if member (#way l) ["g10", "gbase", "mhs", "hugs", "nhc98"]
                                                         andalso Expectations.glob (#path l, "limits/" ^ field r "probe")
                                                      then SOME (field r "report") else NONE) limits
        | SOME "h10run" => List.mapPartial (fn r => if field r "variant" = #way l andalso Expectations.glob (#path l, field r "id")
                                                    then SOME (if field r "build" = "fail" then "fail"
                                                               else "ok/" ^ field r "rc" ^ "/" ^ field r "out") else NONE) runs
        | SOME x => List.mapPartial (fn r => if member (#way l) oracles andalso labelOf (#way l) = x
                                                andalso Expectations.glob (#path l, field r "id") andalso recorded (r, #way l) <> ""
                                             then SOME (recorded (r, #way l)) else NONE) judged
        | NONE => []
      val () = List.app (fn l =>
                 let val hs = hits l
                     val word = HsOracles.firstWord (#reason l)
                 in
                   need (not (null hs), Expectations.describe l ^ ": names nothing with a record of " ^ #way l ^ " under its label");
                   (* a strict line names an outcome other than what its
                      outcome is held to: the record, a probe's the Report *)
                   need (Expectations.meaning (#category l) <> SOME Expectations.Strict orelse List.all (fn v => v <> word) hs,
                         Expectations.describe l ^ ": explains the outcome it is held to, which needs no line")
                 end) ls
      (* every recorded departure of a probe is a line, naming it *)
      val () = List.app (fn r =>
                 List.app (fn o' =>
                   let val v = probeRecord (r, o')
                   in if v = field r "report" then ()
                      else need (List.exists (fn l => #way l = o' andalso #label l = SOME "h10probe"
                                                      andalso Expectations.glob (#path l, "limits/" ^ field r "probe")
                                                      andalso HsOracles.firstWord (#reason l) = v) ls,
                                 o' ^ " limits/" ^ field r "probe" ^ ": E8 recorded " ^ v ^ " where the Report says " ^ field r "report"
                                 ^ ", and tests/hs/oracles.txt has no line for it")
                   end) ["g10", "gbase", "mhs", "hugs", "nhc98"]) limits
    in finish "tests/hs/oracles.txt's 2010 lines against the record" end
    handle Bad m => (need (false, m); finish "tests/hs/oracles.txt's 2010 lines against the record")
         | Expectations.Parse m => (need (false, m); finish "tests/hs/oracles.txt's 2010 lines against the record")

  (* hs2010-corpus/vendored (nightly, with the trees): the vendored files
     and LICENSE files are the trees' bytes *)
  fun vendoredUpstream () =
    let
      val cands = byId (table "candidates.tsv")
      val vend = List.filter (fn r => field r "vendor" = "vendored") (licenceRows ())
      val () = pinned (List.map (fn r => candidate (valOf (lookup (cands, field r "id")))) vend)
      val files = List.concat (List.map (fn r => vendoredFiles (candidate (valOf (lookup (cands, field r "id"))))) vend)
                  @ HsSource.dedup (List.map (fn r => field r "notice") vend)
      val () = List.app (fn f => need (read (vendoredRoot () ^ "/" ^ f) = read (place f), "vendored/" ^ f ^ " is not the tree's")) files
    in finish "tests/hs2010/corpus/vendored against the trees" end
    handle Bad m => (need (false, m); finish "tests/hs2010/corpus/vendored against the trees")
         | HsOracles.Failed m => (need (false, m); finish "tests/hs2010/corpus/vendored against the trees")

  (* ---- The filter on planted text, and before a fake oracle ---- *)

  fun eq (what, got, want) = need (got = want, what ^ ": " ^ String.toString got ^ ", not " ^ String.toString want)
  fun why text = HsFilter.reasons (HsFilter.scanText ("M.hs", text), [])

  fun source () =
    let
      fun is (what, text, want) = eq (what, String.concatWith "," (why text), want)
      val () = is ("Template Haskell", "{-# LANGUAGE TemplateHaskell #-}\nmain = $(x)\n", "TemplateHaskell")
      val () = is ("quasi-quotes by -X", "{-# OPTIONS_GHC -XQuasiQuotes #-}\nmain = [q|x|]\n", "QuasiQuotes")
      val () = is ("-fth", "{-# OPTIONS -fth #-}\nmain = x\n", "TemplateHaskell(-fth)")
      val () = is ("#include", "module M where\n#include \"evil.h\"\n", "CPP#include")
      val () = is ("CPP's pragma", "{-# LANGUAGE CPP #-}\n#if 0\n#endif\nmain = x\n", "CPP")
      val () = is ("a directive alone", "#ifdef X\nmain = x\n#endif\n", "CPP")
      val () = eq ("a directive in a literate file", String.concatWith "," (HsFilter.reasons (HsFilter.scanText ("M.lhs", "> main = x\n#ifdef X\n#endif\n"), [])), "CPP")
      val () = is ("capi", "foreign import capi \"m.h f\" f :: Int\n", "capi")
      val () = is ("a plugin", "{-# OPTIONS_GHC -fplugin=Evil #-}\nmain = x\n", "option:-fplugin=Evil")
      val () = is ("a preprocessor", "{-# OPTIONS_GHC -F -pgmF evil #-}\nmain = x\n", "option:-F")
      val () = is ("an option of the preprocessor", "{-# OPTIONS_GHC -optP-include -optPevil.h #-}\nmain = x\n", "option:-optP-include")
      val () = is ("a plain module", "module M where\n-- #include in a comment is code's\nx = '#'\n", "")
      val () = is ("a line that is no directive", "x = 1\n#ifx\n", "")
      (* D40's switch: CPP without #include admitted, with it kept out, and
         a cabal file's flags read *)
      val cppOnly = HsFilter.scanText ("M.hs", "{-# LANGUAGE CPP #-}\n#if 0\n#endif\nmain = x\n")
      val included = HsFilter.scanText ("M.hs", "{-# LANGUAGE CPP #-}\n#include \"x.h\"\nmain = x\n")
      fun on (s, flags) = HsFilter.untrustedWith {cpp = true} ([s], flags)
      val () = eq ("CPP with the switch on", on (cppOnly, []), "")
      val () = eq ("CPP with #include, the switch on", on (included, []), "CPP")
      val cabal = "library\n  exposed-modules: M\n  cpp-options: -DX\n     -include evil.h\nexecutable e\n  GHC-Options: -O2 -optP-Ievil\n"
      val () = eq ("a cabal file's flags", String.concatWith " " (HsFilter.cabalFlags cabal), "-optP-DX -optP-include -optPevil.h -O2 -optP-Ievil")
      val () = eq ("a cabal file's -optP, the switch on", on (cppOnly, HsFilter.cabalFlags cabal), "option:-optP-DX")
      val () = eq ("an -optP pragma, the switch on",
                   on (HsFilter.scanText ("M.hs", "{-# LANGUAGE CPP #-}\n{-# OPTIONS_GHC -optP-include -optPx.h #-}\n#if 0\n#endif\n"), []),
                   "option:-optP-include")
      (* the copies: ANN, INCLUDE and OPTIONS blanked, LANGUAGE too but in
         the extension variant *)
      fun blanked s = CharVector.map (fn #"\n" => #"\n" | _ => #" ") s
      val lang = "{-# LANGUAGE X #-}\n"
      val gone = "{-# ANN module \"x\" #-}\n{-# options_ghc\n -w #-}\n{-# INCLUDE \"a.h\" #-}\n"
      val kept = "{-# OPTIONS_FOO #-}\n{-# INLINE f #-}\n"
      val () = eq ("the 2010 variant", HsFilter.blankPragmas (lang ^ gone ^ kept), blanked (lang ^ gone) ^ kept)
      val () = eq ("the extension variant", HsFilter.blankOptions (lang ^ gone ^ kept), lang ^ blanked gone ^ kept)
      (* g10's RebindableH2010 where a Prelude import needs it *)
      fun rebind text = HsFilter.needsRebind (HsFilter.stripComments text)
      val () = eq ("a Prelude import list", Bool.toString (rebind "import Prelude (map)\n"), "true")
      val () = eq ("a qualified Prelude", Bool.toString (rebind "import qualified Prelude as P\n"), "true")
      val () = eq ("a Prelude hiding a name", Bool.toString (rebind "import Prelude hiding (lookup)\n"), "false")
      val () = eq ("a Prelude as P", Bool.toString (rebind "import Prelude as P (map)\n"), "true")
      val () = eq ("no Prelude import", Bool.toString (rebind "import Data.List\n"), "false")
      val () = eq ("the injection", HsFilter.inject "module M where\n  import Prelude (map)\n", "module M where\n  import RebindableH2010\n  import Prelude (map)\n")
      val () = eq ("the injection in braces", HsFilter.inject "module M where {\nimport Prelude (map);\n", "module M where {\nimport RebindableH2010;\nimport Prelude (map);\n")
      val () = eq ("a character literal is no string", HsFilter.stripComments "x = '\"' -- c\nimport A",
                   "x = " ^ CharVector.tabulate (8, fn _ => #" ") ^ "\nimport A")
    in finish "the 2010 filter on planted text" end

  (* a fake GHC: it keeps a copy of every file it is given and accepts it,
     and a build makes a Main.ghc that prints hello *)
  fun fakeGhc seenDir =
    "#!/bin/sh\nfor a; do last=$a; done\n"
    ^ "case \" $* \" in *\" -o Main.ghc \"*) printf '#!/bin/sh\\necho hello\\n' > Main.ghc; chmod +x Main.ghc; exit 0;; esac\n"
    ^ "cat \"$last\" >> " ^ quote (seenDir ^ "/seen") ^ "\nexit 0\n"

  fun faults () =
    let
      val d = run ^ "/hs2010-faults"
      val () = (rmTree d; mkdirs d)
      val corpus = d ^ "/corpus"
      val hk = d ^ "/hackage"
      val dataDir = d ^ "/data"
      val x = corpus ^ "/ghc/testsuite/tests/x"
      val () = List.app mkdirs [x, dataDir, hk ^ "/p-1"]
      val () = List.app (fn (n, t) => write (x ^ "/" ^ n ^ ".hs", t))
                 [("A", "main = print 1 -- PLAIN\n"), ("T", "{-# LANGUAGE TemplateHaskell #-}\nmain = $(evil) -- SPLICE\n"),
                  ("I", "main = print 3\n#include \"/etc/passwd\" -- INCLUDED\n"),
                  ("N", "{-# ANN module \"evil\" #-}\nmain = print 4 -- ANNOTATED\n")]
      val () = write (hk ^ "/p-1/C.hs", "{-# LANGUAGE CPP #-}\n#if 1\n#endif\nmodule C where -- CABAL\n")
      val () = write (hk ^ "/p-1/p.cabal", "library\n  cpp-options: -include evil.h\n")
      val () = write (dataDir ^ "/trees.tsv", "tree\tupstream\tcommit\tlicence\tsets\nghc\t-\t-\t-\tghc-h2010\nhackage\t-\t-\t-\thackage\n")
      val () = write (dataDir ^ "/candidates.tsv",
                      "id\tset\troot\tmain\texpect\texpect_src\ttflags\targs\tstdin\tstdout\tparent\n"
                      ^ String.concat (List.map (fn n => "x/" ^ n ^ "\tghc-h2010\tghc/testsuite/tests/x\t" ^ n ^ ".hs\tcompile\t\t\t\t\t\t-\n")
                                                ["A", "T", "I", "N"])
                      ^ "hackage/p-1/library\thackage\thackage/p-1\tC.hs\tcompile\t\t\t\t\t\t.\n")
      fun judged (rows, t) =
        write (dataDir ^ "/judged.tsv", "id\tset\tuntrusted\tg10\tgbase\tmhs\thugs\tnhc98\tgext\tclass\n"
                                        ^ String.concat (List.map (fn (i, s, u, v) => i ^ "\t" ^ s ^ "\t" ^ u ^ "\t\t" ^ v ^ "\t\t\t\t\t" ^ t ^ "\n") rows))
      val () = judged ([("x/A", "ghc-h2010", "", "accept"), ("x/T", "ghc-h2010", "TemplateHaskell", ""),
                        ("x/I", "ghc-h2010", "CPP#include", ""), ("x/N", "ghc-h2010", "", "accept"),
                        ("hackage/p-1/library", "hackage", "CPP", "")], "-")
      val ghc = d ^ "/ghc"
      val counter = ref 0
      fun job' (runs, switch, lines) =
        let
          val () = counter := !counter + 1
          val n = Int.toString (!counter)
          val seenDir = d ^ "/seen-" ^ n
          val () = (mkdirs seenDir; write (ghc, fakeGhc seenDir); Posix.FileSys.chmod (ghc, Posix.FileSys.S.irwxu))
          val txt = d ^ "/oracles-" ^ n ^ ".txt"
          val () = write (txt, String.concatWith "\n" lines ^ "\n")
          val said = ref []
          fun set (dd, r, h, g, ou, x, s, c) =
            (dataOverride := dd; rootOverride := r; hackageOverride := h; HsOracles.ghcOverride := g; outOverride := ou;
             HsOracles.oraclesOverride := x; HsOracles.sink := s; cpp := c)
          fun reset () = (set (NONE, NONE, NONE, NONE, NONE, NONE, say, HsFilter.cppAdmitted); HsOracles.outOverride := NONE)
          val () = set (SOME dataDir, SOME corpus, SOME hk, SOME ghc, SOME (d ^ "/out-" ^ n), SOME txt, fn s => said := s :: !said, switch)
          val () = (List.app (fn f => f ()) runs; reset ()) handle e => (reset (); raise e)
        in (String.concat (rev (!said)), read (seenDir ^ "/seen")) end
      fun job (runs, switch) = job' (runs, switch, [])
      fun saw (what, text, s) = need (String.isSubstring s text, what ^ ": no " ^ String.toString s ^ " in " ^ String.toString text)
      fun not' (what, text, s) = need (not (String.isSubstring s text), what ^ ": " ^ String.toString s ^ " in " ^ String.toString text)
      val (said, seen) = job ([fn () => judge ("gbase", "ghc-h2010")], false)
      val () = saw ("the plain program reaches the oracle", seen, "PLAIN")
      val () = not' ("Template Haskell is kept from the oracle", seen, "SPLICE")
      val () = not' ("#include is kept from the oracle", seen, "INCLUDED")
      val () = saw ("an annotated program reaches the oracle", seen, "ANNOTATED")
      val () = not' ("its ANN pragma does not", seen, "ANN module")
      val () = not' ("the record agreeing", said, "FAIL")
      val () = saw ("the record agreeing", said, "PASS gbase judge-ghc-h2010: 4 outcomes")
      (* a line explains a difference; a strict line of what passes, or
         that no failure uses, fails *)
      val () = judged ([("x/A", "ghc-h2010", "", "reject"), ("x/T", "ghc-h2010", "TemplateHaskell", ""),
                        ("x/I", "ghc-h2010", "CPP#include", ""), ("x/N", "ghc-h2010", "", "accept")], "-")
      val aLine = "gbase | x/A::h10 | HOST-BUG | accept: planted"
      val (said, _) = job' ([fn () => judge ("gbase", "ghc-h2010"), fn () => stale "gbase"], false, [aLine])
      val () = not' ("a line that explains the difference", said, "FAIL")
      val () = saw ("a line that explains the difference", said, "1 explained")
      val (said, _) = job' ([fn () => judge ("gbase", "ghc-h2010"), fn () => stale "gbase"], false,
                            [aLine, "gbase | x/N::h10 | HOST-BUG | reject: planted"])
      val () = saw ("a line for what passes", said, "FAIL gbase x/N::h10: accept as expected")
      val () = saw ("a line that no failure uses", said, "FAIL stale gbase")
      val (said, _) = job' ([fn () => judge ("gbase", "ghc-h2010")], false, ["gbase | x/A::h10 | HOST-BUG | filtered: planted"])
      val () = saw ("a line of another outcome", said, "says filtered")
      (* the filter's verdict differing from E8's is a failure *)
      val () = judged ([("x/A", "ghc-h2010", "", "accept"), ("x/T", "ghc-h2010", "", "accept"),
                        ("x/I", "ghc-h2010", "CPP#include", ""), ("x/N", "ghc-h2010", "", "accept")], "-")
      val (said, _) = job ([fn () => judge ("gbase", "ghc-h2010")], false)
      val () = saw ("a filter that differs from E8's", said, "FAIL gbase x/T::h10: filtered, where E8 recorded accept")
      (* D40's switch: the Hackage component's cpp-options keep its CPP
         out as -optP; without the cabal file it is admitted *)
      val () = judged ([("hackage/p-1/library", "hackage", "CPP", "")], "-")
      val (said, seen) = job ([fn () => judge ("gbase", "hackage")], true)
      val () = not' ("a cabal file's -optP with the switch on", seen, "CABAL")
      val () = not' ("a cabal file's -optP with the switch on", said, "FAIL")
      val () = OS.FileSys.remove (hk ^ "/p-1/p.cabal")
      val (said, seen) = job ([fn () => judge ("gbase", "hackage")], true)
      val () = saw ("CPP without #include, the switch on", seen, "CABAL")
      val () = saw ("CPP without #include, the switch on", said, "FAIL gbase hackage/p-1/library::h10: accept, where E8 recorded filtered")
      val (_, seen) = job ([fn () => judge ("gbase", "hackage")], false)
      val () = not' ("CPP without #include, the switch off", seen, "CABAL")
    in finish "the 2010 harness on a fake oracle" end
    handle e => (need (false, exnText e); finish "the 2010 harness on a fake oracle")

  (* ---- The inventory ---- *)

  fun capabilityOf "hackage" = "hs-hackage"
    | capabilityOf "h98-corpus" = "hs-corpus"
    | capabilityOf "h98-accept" = "hs-corpus"
    | capabilityOf _ = "hs2010-corpus"
  fun oracleCapability "hugs" = "hs-hugs"
    | oracleCapability "nhc98" = "hs-nhc98"
    | oracleCapability "mhs" = "hs-microhs"
    | oracleCapability _ = "hs-ghc"

  val job = HsOracles.job
  fun oracleTree oracle =
    let
      val deps = if member oracle ["g10"] then ["hs-oracles2010/@ghc2010-shim"]
                   else if oracle = "mhs" then ["hs-oracles2010/@mhs2010-cache"] else []
      val judgeSets = List.filter (fn s => member oracle (perSet s)) sets
      val judges = List.map (fn s => Test.requires [capabilityOf s] (job ("judge-" ^ s, ["hs-oracle2010", "judge", oracle, s], deps, 14400, 2000)))
                            judgeSets
      val probeJobs = if oracle = "gext" then [] else [job ("probes", ["hs-oracle2010", "probes", oracle], deps, 3600, 2000)]
      val runJobs = if member oracle ["g10", "gbase"] then [Test.requires ["hs2010-corpus"] (job ("run", ["hs-oracle2010", "run", oracle], deps, 14400, 2000))]
                    else []
      val names = List.map (fn s => "judge-" ^ s) judgeSets @ (if oracle = "gext" then [] else ["probes"])
                  @ (if member oracle ["g10", "gbase"] then ["run"] else [])
    in
      Test.requires [oracleCapability oracle]
        (Test.describe oracle (judges @ probeJobs @ runJobs
                               @ [job ("@stale", ["hs-oracle2010", "stale", oracle], List.map (fn n => "hs-oracles2010/" ^ oracle ^ "/" ^ n) names,
                                       300, 100)]))
    end

  fun inProcess (name, args, tags) = List.foldl (fn (t, tree) => Test.tag t tree) (job (name, args, [], 600, 500)) tags

  fun tree () =
    Test.tag "covers:tests/hs2010/*" (Test.tag "covers:tests/hs/oracles*" (Test.tag "covers:tests/runner/hs*.sml"
      (Test.describe ""
        [Test.tag "nightly" (Test.describe "hs-oracles2010"
           (Test.requires ["hs-ghc"] (job ("@ghc2010-shim", ["hs-oracle2010", "ghc-shim"], [], 3600, 3000))
            :: Test.requires ["hs-microhs"] (job ("@mhs2010-cache", ["hs-oracle2010", "mhs-cache"], [], 3600, 2000))
            :: List.map oracleTree oracles)),
         Test.describe "hs2010-corpus"
           [inProcess ("data", ["hs2010-corpus-data"], ["check", "quick"]),
            inProcess ("faults", ["hs2010-faults"], ["check"]),
            Test.requires ["hs2010-corpus", "hs-corpus", "hs-hackage"] (inProcess ("filter", ["hs2010-filter"], ["nightly"])),
            Test.requires ["hs2010-corpus"] (inProcess ("vendored", ["hs2010-vendored"], ["nightly"]))]])))

  val capabilities =
    [{name = "hs2010-corpus",
      probe = "for t in ghc/testsuite/tests ghc/nofib/common MicroHs/tests; do test -d \"$RUNE_HS_CORPUS/$t\" || exit 1; done",
      hint = "clone the trees of tests/hs2010/corpus/trees.tsv at their commits into RUNE_HS_CORPUS, each under its tree's name (ghc with its nofib submodule, MicroHs), beside the 98 corpus's"},
     {name = "hs-hackage",
      probe = "test -n \"$RUNE_HS_HACKAGE\" && test -d \"$RUNE_HS_HACKAGE/Cabal-3.12.1.0\"",
      hint = "fetch the tarballs of tests/hs2010/corpus/hackage.tsv, check each one's sha256, unpack them into one directory and set RUNE_HS_HACKAGE to it (tests/hs2010/corpus/README.md)"}]

  fun command ["hs-oracle2010", "ghc-shim"] = SOME ghcShim
    | command ["hs-oracle2010", "mhs-cache"] = SOME mhsCacheJob
    | command ["hs-oracle2010", "judge", oracle, set] = SOME (fn () => judge (oracle, set))
    | command ["hs-oracle2010", "probes", oracle] = SOME (fn () => probes oracle)
    | command ["hs-oracle2010", "run", oracle] = SOME (fn () => runTier oracle)
    | command ["hs-oracle2010", "stale", oracle] = SOME (fn () => stale oracle)
    | command ["hs2010-corpus-data"] = SOME (fn () => (dataCheck (); oraclesText ()))
    | command ["hs2010-faults"] = SOME (fn () => (source (); faults ()))
    | command ["hs2010-filter"] = SOME (fn () => withOut filterTrees)
    | command ["hs2010-vendored"] = SOME (fn () => withOut vendoredUpstream)
    | command _ = NONE
end
