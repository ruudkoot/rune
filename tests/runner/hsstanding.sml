(* 98 mode held (the haskell2010 roadmap's M3, Holding 98 mode
   byte-identical; docs/testing.md, 98 mode held): one rhc against
   another, both in Haskell 98 mode, on the same programs, so that a change
   that moves what 98 mode makes is seen whether or not a 98 test's output
   moves: the suites hold what a program prints, this holds its code too.

   The two rhcs are the sides `old` and `new`. RUNE_HS_OLD and RUNE_HS_NEW
   (this tree where it is unset) each name a tree, a directory whose
   bin/rhc.rbc, bin/runevm and share/rhc are taken as they stand (so make
   bin/rhc there first), or else a commit, whose rhc is built from its own
   sources by this tree's bin/rune, as make builds bin/rhc.rbc, into
   build/hs-standing/COMMIT, where the next check finds it, and run on this
   tree's VM; RUNE_HS_VM puts both sides on one VM. @prepare copies each
   side into OUT/old and OUT/new (OUT is RUNE_HS_STANDING_OUT, or the run's
   directory's hs-standing), its rhc run as bin/rhc runs it, and makes each
   its snapshot there as make makes bin/rhc.layer, from the modules its rhc
   lists (`--library-modules`) or, before M4, its Makefile names, through
   OUT/SIDE/bin/../share/rhc: two paths that differ
   by the side's name alone, which is put out of what is compared.

   What is compared are items, each the same run of rhc on both sides, and
   an item differs by the parts that do: `status`, `stdout`, `stderr`,
   `bytes`, or `fingerprint` where two bytecode files differ only in the
   instruction set's fingerprint (docs/bytecode.md). The sets:
   - lang: each program of tests/hs/lang compiled as hs/compile compiles
     it, to register and to stack bytecode, at -O1 (the default) and -O2;
   - run-set: D56's 188 through their own harness (HsCorpusRun.runWith:
     its preparation, its tries, its targets), compiled and run in no way,
     each bytecode it makes (part `bytes`) and its compiles' logs (`status`
     where the tries made differ, `stdout`, `stderr`);
   - errors: each program of tests/hs/errors compiled as hs/errors does;
     accept: each of tests/hs/accept checked as hs/accept does;
   - views: --dump-ast, --print, --print-layout and --print-exact of each
     file of tests/hs/lang and tests/hs/accept;
   - snapshot: the two snapshots' configurations, paired by their settings
     but rhc's identity and the fingerprint, entry by entry, key and bytes
     (`entries`), their settings (`settings`, or `fingerprint` where it
     alone differs), and a configuration on one side alone (`config`); not
     units/, the memo of the sources' stat (times, inodes) a store keeps;
   - pragmas: each vendored file of the corpus whose LANGUAGE or OPTIONS
     pragmas the corpus's copy blanks (HsSource.blankPragmas: 11), in a
     program of the run set that holds it, prepared as the harness prepares
     it but with its pragmas as written (HsCorpus.keepPragmas), the file
     checked and its program compiled to both targets in each try the
     harness makes: old against new, and on each side against the copy with
     the pragmas blanked (`.../blanked-SIDE`), which D6's rule holds it to
     (a 98 module reads no name of a pragma but an edition's).

   A difference fails its job unless a line of RUNE_HS_EXPECT explains it:
   `DECISION | ITEM-GLOB | PARTS | reason`, DECISION one of the decided
   exceptions (`decisions` below, each with the parts it may move at all),
   PARTS the parts the line lets move, by commas, or `*` for all its
   decision may. @summary counts each set and fails a line that explained
   nothing. Each run of rhc is cold (RHC_STORE empty), at RUNE_LINT=2, in
   the time zone of Lang's compiles, from this tree's root but where the
   harness runs it. What differs is kept in OUT/items/SIDE/ITEM.*.

   @faults (nightly) holds the check to its work: it builds rhc from this
   tree's sources with a 98 change planted -- `foreign` reserved, an n+k
   pattern refused, a LANGUAGE pragma refused in a 98 module -- and wants
   each caught by the items that meet it, and from the sources unedited,
   which must give those items unmoved. *)
structure HsStanding =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why

  (* ---- Where, and how rhc runs *)

  val outOverride = ref (NONE : string option)
  fun out () = case !outOverride of SOME d => d | NONE => fromRoot (env ("RUNE_HS_STANDING_OUT", run ^ "/hs-standing"))
  fun sideDir s = out () ^ "/" ^ s
  val sides = ["old", "new"]
  fun specOf "old" = env ("RUNE_HS_OLD", "")
    | specOf _ = env ("RUNE_HS_NEW", root)

  val gib = 1024 * 1024 * 1024
  val limits = {addressSpace = SOME (6 * gib), cpuTime = NONE, fileSize = SOME gib, core = SOME 0}
  (* cold, at level 2, in the time zone of Lang's compiles *)
  fun environment e = setEnv ("TZ", "NST3:30NDT,M3.2.0,M11.1.0") (setEnv ("RUNE_LINT", "2") (setEnv ("RHC_STORE", "") e))

  (* a side's rhc, as bin/rhc runs it *)
  fun rhcOf s =
    let val d = sideDir s
    in [d ^ "/bin/runevm", d ^ "/bin/rhc.rbc", "--share", d ^ "/bin/../share/rhc", "--snapshot", d ^ "/bin/rhc.layer"] end

  fun commas xs = String.concatWith "," xs
  fun member x xs = List.exists (fn y => y = x) xs

  (* `text` with every `from` replaced by `to` *)
  fun replaceAll (text, from, to) =
    let
      val n = size from
      fun at i = let fun eq k = k = n orelse (String.sub (text, i + k) = String.sub (from, k) andalso eq (k + 1)) in eq 0 end
      fun go (i, start, acc) =
        if i > size text - n then String.concat (rev (String.extract (text, start, NONE) :: acc))
        else if at i then go (i + n, i + n, to :: String.substring (text, start, i - start) :: acc)
        else go (i + 1, start, acc)
    in if n = 0 then text else go (0, 0, []) end

  fun bytes f = (let val i = BinIO.openIn f in SOME (BinIO.inputAll i) before BinIO.closeIn i end) handle IO.Io _ => NONE
  (* two bytecode files alike but for the fingerprint, bytes 8 to 11 *)
  fun butFingerprint (a, b) =
    let val n = Word8Vector.length a
        fun go i = i = n orelse ((i >= 8 andalso i < 12 orelse Word8Vector.sub (a, i) = Word8Vector.sub (b, i)) andalso go (i + 1))
    in n = Word8Vector.length b andalso n >= 12 andalso go 0 end
  fun productParts (NONE, NONE) = []
    | productParts (SOME p, SOME q) =
        (case (bytes p, bytes q) of
           (NONE, NONE) => []
         | (SOME x, SOME y) => if x = y then [] else if butFingerprint (x, y) then ["fingerprint"] else ["bytes"]
         | _ => ["bytes"])
    | productParts _ = ["bytes"]

  (* ---- One run of rhc on each side, and what differs *)

  (* a run of a side's rhc: its status, where its streams are (BASE.out,
     BASE.err), what it made, and what its text is read with: each pair
     (from, to) replaced, the side's directory first *)
  type took = {side : string, status : int, base : string, product : string option, subst : (string * string) list}

  fun clear base = List.app (fn e => (OS.FileSys.remove (base ^ e) handle OS.SysErr _ => ())) [".out", ".err", ".rbc"]
  fun call (s, args, dir, base, product, subst) : took =
    let
      val () = (mkdirs (OS.Path.dir base); clear base)
      val status = execProcess false limits environment
                     {cmd = rhcOf s @ args, dir = SOME dir, stdin = "", stdout = base ^ ".out", stderr = base ^ ".err",
                      timeout = 900}
    in {side = s, status = status, base = base, product = if product then SOME (base ^ ".rbc") else NONE,
        subst = (sideDir s, "<side>") :: subst} end

  fun textOf (t : took, ext) = List.foldl (fn ((a, b), x) => replaceAll (x, a, b)) (read (#base t ^ ext)) (#subst t)
  fun differ (a : took, b : took) =
    (if #status a <> #status b then ["status"] else [])
    @ (if textOf (a, ".out") <> textOf (b, ".out") then ["stdout"] else [])
    @ (if textOf (a, ".err") <> textOf (b, ".err") then ["stderr"] else [])
    @ productParts (#product a, #product b)

  fun itemBase (s, item) = out () ^ "/items/" ^ s ^ "/" ^ item
  (* the item `item`: `args` given the path of what it makes, run in `dir`
     on each side; what is the same is not kept *)
  fun pair (item, args, dir, product) =
    let
      fun one s = let val b = itemBase (s, item) in call (s, args (b ^ ".rbc"), dir, b, product, []) end
      val a = one "old"
      val b = one "new"
      val ps = differ (a, b)
    in if null ps then (clear (#base a); clear (#base b)) else (); (item, ps) end

  (* ---- What may move: the decided exceptions, and the lines that name them *)

  val allParts = ["status", "stdout", "stderr", "bytes", "fingerprint", "entries", "settings", "config"]
  (* each decided exception (the roadmap's *Constraints* and M3), the parts
     it may move, and what it is; a move no decision names is the owner's *)
  val decisions =
    [("D6", ["stdout"], "the printers print a module's header pragmas (M5)"),
     ("D8", allParts, "--names=greatest no longer reaches the library (M4)"),
     ("D11", ["stderr"], "a refusal in a 98 module gains the hint line, its verdict and code held (M5)"),
     ("D13a", allParts, "genericLength :: Num i => [b] -> i in 98 mode (M18)"),
     ("D21", allParts, "Int wraps modulo 2^63 over wrapping int primitives, which cheap eagerness takes (M11)"),
     ("D22", ["fingerprint"], "the int bit primitives in Rune, with D21's (M11)"),
     ("D26", allParts, "98 mode's lexer reads White_Space: U+0085, U+2028 and U+2029 separate tokens (M7)"),
     ("D29", ["fingerprint"], "Ptr's address primitives in Rune (M16)"),
     ("M18", allParts, "the two checker defects fixed, their programs refused in 98 mode (the owner's answer 2)")]

  type line = {decision : string, glob : string, parts : string list, reason : string, place : string}
  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))

  (* the lines of RUNE_HS_EXPECT, each checked against its decision *)
  val ignoreExpect = ref false
  fun expectations () : line list =
    case (if !ignoreExpect then "" else env ("RUNE_HS_EXPECT", "")) of
      "" => []
    | f =>
        let
          val file = fromRoot f
          val () = need (exists file, "RUNE_HS_EXPECT names no file: " ^ file)
          fun one (n, l) =
            let
              val place = OS.Path.file file ^ ":" ^ Int.toString n
              val t = trim l
            in
              if t = "" orelse String.isPrefix "#" t then NONE
              else
                case List.map trim (String.fields (fn c => c = #"|") t) of
                  d :: g :: ps :: reason =>
                    let
                      val allowed = case List.find (fn (x, _, _) => x = d) decisions of
                                      SOME (_, a, _) => a
                                    | NONE => raise Failed (place ^ ": " ^ d ^ " is no decided exception ("
                                                            ^ commas (List.map #1 decisions) ^ ")")
                      val parts = if ps = "*" then allowed else List.map trim (String.fields (fn c => c = #",") ps)
                      val () = List.app (fn p => need (member p allowed, place ^ ": " ^ d ^ " may not move the part " ^ p
                                                                        ^ " (it may move " ^ commas allowed ^ ")")) parts
                      val reason = String.concatWith "|" reason
                      val () = need (g <> "" andalso trim reason <> "", place ^ ": an item's glob and a reason are wanted")
                    in SOME {decision = d, glob = g, parts = parts, reason = trim reason, place = place} end
                | _ => raise Failed (place ^ ": not DECISION | ITEM-GLOB | PARTS | reason")
            end
          val ls = String.fields (fn c => c = #"\n") (read file)
        in List.mapPartial one (ListPair.zip (List.tabulate (length ls, fn i => i + 1), ls)) end

  datatype verdict = Same | Moved of line | Unexplained of string
  fun judge ls (_, []) = Same
    | judge ls (item, ps) =
        case List.find (fn (l : line) => Expectations.glob (#glob l, item) andalso List.all (fn p => member p (#parts l)) ps) ls of
          SOME l => Moved l
        | NONE =>
            Unexplained (case List.find (fn (l : line) => Expectations.glob (#glob l, item)) ls of
                           SOME l => commas ps ^ " moved, beyond the " ^ commas (#parts l) ^ " of " ^ #place l
                         | NONE => commas ps ^ " moved, which no line of RUNE_HS_EXPECT explains")

  (* a job's items judged: a line each in OUT/results/JOB.tsv (ITEM, the
     parts that differ, its verdict, the line that explains it), a FAIL for
     each difference unexplained *)
  fun report (job, items) =
    let
      val ls = expectations ()
      val vs = List.map (fn x => (x, judge ls x)) items
      val () = mkdirs (out () ^ "/results")
      fun row ((item, ps), v) =
        String.concatWith "\t" [item, if null ps then "-" else commas ps,
                                case v of Same => "same" | Moved _ => "moved" | Unexplained _ => "FAIL",
                                case v of Moved l => #place l | _ => "-"] ^ "\n"
      val () = write (out () ^ "/results/" ^ job ^ ".tsv", String.concat (List.map row vs))
      val fails = List.mapPartial (fn ((item, _), Unexplained why) => SOME (item, why) | _ => NONE) vs
      fun count p = Int.toString (length (List.filter p vs))
    in
      List.app (fn (item, why) => say ("FAIL hs-standing " ^ item ^ ": " ^ why ^ " (kept in " ^ out () ^ "/items/{old,new}/"
                                       ^ item ^ ".*, or the run set's in " ^ out () ^ "/{old,new}/run-set)\n")) fails;
      if null items then say ("FAIL hs-standing " ^ job ^ ": no item\n")
      else say ((if null fails then "PASS" else "SUMMARY") ^ " hs-standing " ^ job ^ ": " ^ Int.toString (length items)
                ^ " items, " ^ count (fn (_, v) => v = Same) ^ " the same, "
                ^ count (fn (_, v) => case v of Moved _ => true | _ => false) ^ " moved as decided, "
                ^ Int.toString (length fails) ^ " moved otherwise\n")
    end

  (* ---- The sides *)

  type source = {rbc : string, vm : string, share : string, makefile : string, what : string}

  fun vmFor vm = case env ("RUNE_HS_VM", "") of "" => vm | v => fromRoot v
  fun ofTree t : source =
    (need (exists (t ^ "/bin/rhc.rbc"), t ^ " has no bin/rhc.rbc: make bin/rhc there");
     need (isDir (t ^ "/share/rhc"), t ^ " has no share/rhc");
     {rbc = t ^ "/bin/rhc.rbc", vm = vmFor (t ^ "/bin/runevm"), share = t ^ "/share/rhc", makefile = t ^ "/Makefile",
      what = "the tree " ^ t})

  fun run1 (what, cmd, dir, log) =
    let val status = execProcess false Subprocess.unlimited (fn e => e)
                       {cmd = cmd, dir = SOME dir, stdin = "", stdout = log, stderr = log, timeout = 3600}
    in need (status = 0, what ^ " failed (" ^ Int.toString status ^ "): " ^ firstNonEmpty log ^ " (" ^ log ^ ")") end
  fun gitOut args =
    let val f = out () ^ "/git.out"
        val () = mkdirs (out ())
        val status = execProcess false Subprocess.unlimited (fn e => e)
                       {cmd = "git" :: args, dir = SOME root, stdin = "", stdout = f, stderr = f ^ ".err", timeout = 600}
    in need (status = 0, "git " ^ String.concatWith " " args ^ ": " ^ firstNonEmpty (f ^ ".err")); trim (read f) end

  (* a commit's rhc, built from its sources as make builds bin/rhc.rbc, by
     this tree's compiler with the commit's library (--lib), its Config
     written by the commit's gen-version.sh, its version the commit's;
     kept in build/hs-standing/COMMIT, which `built` marks done *)
  fun ofCommit spec : source =
    let
      val sha = gitOut ["rev-parse", "--verify", spec ^ "^{commit}"]
      val short = gitOut ["rev-parse", "--short", sha]
      val c = fromRoot ("build/hs-standing/" ^ sha)
      val log = c ^ ".log"
      fun build () =
        let
          val () = (if isDir c then rmTree c else (); mkdirs c)
          val tar = c ^ ".tar"
          val () = run1 ("git archive " ^ short,
                         ["git", "archive", "--format=tar", "-o", tar, sha, "--", "lib", "src", "rhc.build", "rhc.plan",
                          "share/rhc", "scripts", "Makefile"], root, log)
          val () = run1 ("tar", ["tar", "-xf", tar, "-C", c], root, log)
          val () = OS.FileSys.remove tar
          val config = "src/rhc/config.sml"
          val () = run1 ("gen-version.sh", ["sh", "scripts/gen-version.sh", "--config", "rhc.plan", config], c, log)
          val () = write (c ^ "/" ^ config,
                          String.concat (List.map (fn l => (if String.isPrefix "  val version = " l
                                                            then "  val version = \"" ^ short ^ "\"" else l) ^ "\n")
                                                  (lines (read (c ^ "/" ^ config)))))
          val () = mkdirs (c ^ "/bin")
          val () = run1 ("building rhc of " ^ short,
                         [fromRoot "bin/runevm", "--heap-size", "67108864", fromRoot "bin/rune.rbc", "--lib", c ^ "/lib",
                          "--build", "rhc.build", "-o", c ^ "/bin/rhc.rbc"], c, log)
        in write (c ^ "/built", sha ^ "\n") end
    in
      if exists (c ^ "/built") then () else build ();
      {rbc = c ^ "/bin/rhc.rbc", vm = vmFor (fromRoot "bin/runevm"), share = c ^ "/share/rhc", makefile = c ^ "/Makefile",
       what = "the commit " ^ short ^ " (" ^ spec ^ "), built in " ^ c}
    end

  fun sourceOf spec = let val t = fromRoot spec in if isDir t then ofTree t else ofCommit spec end

  (* the modules a side's snapshot imports, as make finds them: from its rhc,
     `--library-modules` (the haskell2010 roadmap's M4 on), or else from its
     Makefile's RHC_LIBRARY_MODULES, as before *)
  fun modulesOf (s, makefile) =
    let
      val d = sideDir s
      val f = d ^ "/library-modules"
      val status = execProcess false limits (fn e => e)
                     {cmd = [d ^ "/bin/runevm", d ^ "/bin/rhc.rbc", "--library-modules"], dir = SOME d, stdin = "", stdout = f,
                      stderr = f ^ ".err", timeout = 300}
      val ms = String.tokens Char.isSpace (read f)
    in
      if status = 0 andalso not (null ms) then ms
      else
        case List.find (String.isPrefix "RHC_LIBRARY_MODULES") (lines (read makefile)) of
          SOME l => (case String.fields (fn c => c = #"=") l of
                       _ :: rest => String.tokens Char.isSpace (String.concatWith "=" rest)
                     | [] => [])
        | NONE => raise Failed (s ^ "'s rhc lists no --library-modules, and " ^ makefile
                                ^ " names no RHC_LIBRARY_MODULES: the modules of the snapshot")
    end

  (* a side's snapshot, as make makes bin/rhc.layer: a Main importing each
     module, compiled into the store once in each order of a match, at
     level 2, then the configurations of other rhcs pruned *)
  fun snapshot (s, mods) =
    let
      val d = sideDir s
      val m = d ^ "/layer-main"
      val () = mkdirs m
      val () = write (m ^ "/Main.hs", String.concat (List.map (fn x => "import " ^ x ^ "\n") mods)
                                      ^ "main :: IO ()\nmain = return ()\n")
      val base = [d ^ "/bin/runevm", d ^ "/bin/rhc.rbc", "--share", d ^ "/bin/../share/rhc"]
      fun step args =
        let val status = execProcess false limits (fn e => setEnv ("RUNE_LINT", "2") (unsetEnv ["RHC_STORE"] e))
                           {cmd = base @ args, dir = SOME m, stdin = "", stdout = m ^ "/log", stderr = m ^ "/log", timeout = 1800}
        in need (status = 0, "the snapshot of " ^ s ^ ", " ^ String.concatWith " " args ^ ": " ^ firstNonEmpty (m ^ "/log")) end
    in
      step ["--store", d ^ "/bin/rhc.layer", "--match=report", "Main.hs", "-o", "main.rbc"];
      step ["--store", d ^ "/bin/rhc.layer", "--match=sestoft", "Main.hs", "-o", "main.rbc"];
      step ["--prune-store", d ^ "/bin/rhc.layer"]
    end

  fun copyExecutable (src, dst) = (HsCorpus.copyFile (src, dst); Posix.FileSys.chmod (dst, Posix.FileSys.S.irwxu))

  (* a side made from its source: its VM, rhc and library copied, a wrapper
     bin/rhc for the harness, its snapshot, and `ready` *)
  fun materialize (s, src : source) =
    let
      val d = sideDir s
      val () = (if isDir d then rmTree d else (); mkdirs (d ^ "/bin"); mkdirs (d ^ "/share"))
      val () = need (exists (#vm src), "no VM " ^ #vm src)
      val () = copyExecutable (#vm src, d ^ "/bin/runevm")
      val () = HsCorpus.copyFile (#rbc src, d ^ "/bin/rhc.rbc")
      val () = HsCorpus.copyTree (#share src, d ^ "/share/rhc")
      val () = write (d ^ "/bin/rhc", "#!/bin/sh\nexec " ^ String.concatWith " " (List.map quote (rhcOf s)) ^ " \"$@\"\n")
      val () = Posix.FileSys.chmod (d ^ "/bin/rhc", Posix.FileSys.S.irwxu)
      val () = snapshot (s, modulesOf (s, #makefile src))
      val what = #what src ^ "; rhc.rbc " ^ CompilerMutants.hash (d ^ "/bin/rhc.rbc") ^ ", runevm "
                 ^ CompilerMutants.hash (d ^ "/bin/runevm")
    in write (d ^ "/ready", what ^ "\n"); say ("hs-standing: " ^ s ^ " is " ^ what ^ "\n") end

  fun ready () = List.app (fn s => need (exists (sideDir s ^ "/ready"), "the side " ^ s ^ " is not prepared: run hs-standing/@prepare"))
                          sides

  fun prepare () =
    (need (specOf "old" <> "", "RUNE_HS_OLD names no side: a tree or a commit (make check-hs98 OLD=...)");
     ignore (expectations ());
     List.app (fn s => materialize (s, sourceOf (specOf s))) sides;
     say "PASS hs-standing: both sides prepared\n")

  (* ---- The sets *)

  val suffixes = [".hs", ".lhs"]
  val mains = ["Main.hs", "Main.lhs"]
  fun programs dir = Lang.programsOf (fromRoot dir, suffixes, mains)
  fun relative p = if String.isPrefix (root ^ "/") p then String.extract (p, size root + 1, NONE) else p
  fun cargs (p : Lang.program) = words (#base p ^ ".cargs")
  fun srcOf (p : Lang.program) = relative (#src p)

  (* lang: to both targets at both levels, as hs/compile does, from the root *)
  val levels = [("O1", []), ("O2", ["-O2"])]
  val targets = [("register", []), ("stack", ["--target=stack"])]
  fun langOne ts ls (p : Lang.program) =
    List.concat (List.map (fn (l, lf) =>
      List.map (fn (t, tf) => pair ("lang/" ^ #name p ^ "/" ^ t ^ "-" ^ l, fn dst => lf @ tf @ cargs p @ [srcOf p, "-o", dst], root, true))
               ts) ls)
  fun errorsOne (p : Lang.program) = pair ("errors/" ^ #name p, fn dst => cargs p @ [srcOf p, "-o", dst], root, true)
  fun acceptOne (p : Lang.program) = pair ("accept/" ^ #name p, fn _ => ["--typecheck-only"] @ cargs p @ [srcOf p], root, false)

  (* views: each file of tests/hs/lang and tests/hs/accept, a program's or
     the modules of a program's directory *)
  val views = ["dump-ast", "print", "print-layout", "print-exact"]
  fun viewFiles () =
    List.concat (List.map (fn dir =>
      List.concat (List.map (fn (p : Lang.program) =>
        if isDir (#base p) then List.map relative (glob (#base p, ".hs") @ glob (#base p, ".lhs"))
        else [srcOf p]) (programs dir)))
      ["tests/hs/lang", "tests/hs/accept"])
  fun viewOne (file, v) =
    pair ("views/" ^ String.extract (file, size "tests/hs/", NONE) ^ "/" ^ v, fn _ => ["--" ^ v, file], root, false)

  (* run-set: a program through its harness on each side, compiled for
     both targets and run in no way; what the harness made kept, and its
     logs, each side in its own directory *)
  val label = "standing"
  fun harness (s, id) =
    let
      val d = sideDir s ^ "/run-set"
      val () = (HsRhcCorpus.rhcOverride := SOME (sideDir s ^ "/bin/rhc"); HsRhcCorpus.outOverride := SOME d;
                HsCorpusRun.outOverride := SOME d; HsCorpusRun.keep := SOME (d ^ "/keep"); HsRhcCorpus.sink := (fn _ => ()))
      val go = fn () => HsCorpusRun.runWith (id, label, [], HsCorpusRun.targets, "", fn _ => false)
    in
      (if HsCorpusRun.isVendored id then HsCorpusRun.fromVendored go else go ())
      before (HsRhcCorpus.rhcOverride := NONE; HsRhcCorpus.outOverride := NONE; HsCorpusRun.outOverride := NONE;
              HsCorpusRun.keep := NONE; HsRhcCorpus.sink := say)
    end
  (* the logs of a program's compiles on a side: each try's streams, by name *)
  fun logsOf (s, id) =
    let val log = sideDir s ^ "/run-set/logs/" ^ label ^ "/" ^ id
        val pre = OS.Path.file log ^ "."
    in List.map (fn n => (n, OS.Path.dir log ^ "/" ^ n))
                (sort (List.filter (fn n => String.isPrefix pre n andalso not (String.isSuffix ".times" n)
                                            andalso length (String.fields (fn c => c = #".") (String.extract (n, size pre, NONE))) >= 2)
                                   (entries (OS.Path.dir log))))
    end
  fun runSetOne id =
    let
      val () = List.app (fn s => harness (s, id)) sides
      fun kept (s, t) = sideDir s ^ "/run-set/keep/" ^ id ^ "/" ^ t ^ ".rbc"
      val codes = List.map (fn (t, _) => ("run-set/" ^ id ^ "/" ^ t, productParts (SOME (kept ("old", t)), SOME (kept ("new", t)))))
                           HsCorpusRun.targets
      val (a, b) = (logsOf ("old", id), logsOf ("new", id))
      fun norm (s, f) = replaceAll (read f, sideDir s, "<side>")
      fun streams ext = List.exists (fn ((n, f), (_, g)) => String.isSuffix ext n andalso norm ("old", f) <> norm ("new", g))
                                    (ListPair.zip (a, b))
      val logs = if List.map #1 a <> List.map #1 b then ["status"]
                 else (if streams ".out" then ["stdout"] else []) @ (if streams ".err" then ["stderr"] else [])
      val () = List.app (fn ((t, _), (_, ps)) => if null ps then List.app (fn s => OS.FileSys.remove (kept (s, t)) handle OS.SysErr _ => ()) sides
                                                 else ())
                        (ListPair.zip (HsCorpusRun.targets, codes))
    in codes @ [("run-set/" ^ id ^ "/logs", logs)] end
  fun runSetIds () = List.map (fn r => HsCorpus.field r "id") (HsCorpusRun.d56 ())

  (* snapshot: the configurations of each side's store, by their settings
     but rhc's identity and the fingerprint; of units/, its settings alone,
     `about`, since the rest is a memo of the sources' stat *)
  fun configsOf s =
    let
      val layer = sideDir s ^ "/bin/rhc.layer"
      fun files (dir, rel) =
        List.concat (List.map (fn n => let val p = dir ^ "/" ^ n and r = if rel = "" then n else rel ^ "/" ^ n
                                       in if isDir p then files (p, r) else [(r, p)] end) (sort (entries dir)))
      fun one c =
        let
          val about = List.map (fn l => case String.tokens (fn ch => ch = #" ") l of k :: v => (k, String.concatWith " " v) | [] => ("", ""))
                               (lines (read (layer ^ "/" ^ c ^ "/units/about")))
          val key = commas (List.map (fn (k, v) => k ^ "=" ^ v) (List.filter (fn (k, _) => k <> "identity" andalso k <> "isa") about))
          val es = List.filter (fn (r, _) => not (String.isPrefix "units/" r)) (files (layer ^ "/" ^ c, ""))
        in {key = key, about = List.filter (fn (k, _) => k <> "identity") about, entries = es} end
    in List.map one (List.filter (fn c => c <> "memo" andalso isDir (layer ^ "/" ^ c)) (entries layer)) end
  fun snapshotItems () =
    let
      val (a, b) = (configsOf "old", configsOf "new")
      fun slug k = String.translate (fn #"/" => "_" | #" " => "_" | c => str c) k
      fun sameFiles (fa, fb) =
        List.map #1 fa = List.map #1 fb andalso ListPair.all (fn ((_, p), (_, q)) => bytes p = bytes q) (fa, fb)
      fun pairOne x =
        case List.find (fn y => #key y = #key x) b of
          NONE => [("snapshot/" ^ slug (#key x), ["config"])]
        | SOME y =>
            let val settings = List.filter (fn (k, v) => List.find (fn (k', _) => k' = k) (#about y) <> SOME (k, v)) (#about x)
                               @ List.filter (fn (k, _) => not (List.exists (fn (k', _) => k' = k) (#about x))) (#about y)
            in
              [("snapshot/" ^ slug (#key x) ^ "/entries", if sameFiles (#entries x, #entries y) then [] else ["entries"]),
               ("snapshot/" ^ slug (#key x) ^ "/settings",
                case settings of [] => [] | _ => if List.all (fn (k, _) => k = "isa") settings then ["fingerprint"] else ["settings"])]
            end
      val unpaired = List.filter (fn y => not (List.exists (fn x => #key x = #key y) a)) b
    in
      need (not (null a) andalso not (null b), "a snapshot holds no configuration");
      List.concat (List.map pairOne a) @ List.map (fn y => ("snapshot/" ^ slug (#key y), ["config"])) unpaired
    end

  (* pragmas: the vendored files whose pragmas the corpus's copy blanks *)
  fun pragmaFiles () =
    HsCorpusRun.fromVendored (fn () =>
      List.filter (fn rel => let val t = HsSource.universal (read (HsCorpus.tree rel)) in HsSource.blankPragmas t <> t end)
                  (List.map (fn f => String.extract (f, size (HsCorpus.root ()) + 1, NONE))
                            (List.filter (fn f => String.isSuffix ".hs" f orelse String.isSuffix ".lhs" f)
                                         (HsCorpus.allFiles (HsCorpus.root ())))))
  (* the program of the run set that holds a file: the one whose main it is,
     else the first whose closure has it, or whose parent's directory has it
     and one of whose files names it (an import, or nofib's `#include`) *)
  fun holder rel =
    let
      val ids = HsCorpusRun.vendored ()
      val cs = List.filter (fn (c : HsCorpus.candidate) => member (#id c) ids) (HsCorpus.candidates ())
      val f = OS.Path.file rel
      val m = hd (String.fields (fn c => c = #".") f)
      fun holds (c : HsCorpus.candidate) =
        let
          val inParent = #parent c = HsCorpus.dirname rel
          val inCommon = HsCorpus.dirname rel = HsCorpus.common
        in
          (inParent orelse inCommon orelse String.isPrefix (HsCorpus.dirname (#path c) ^ "/") rel)
          andalso
          (let val {files, ...} = HsCorpus.closureOf c
           in List.exists (fn (g, _) => g = HsCorpus.tree rel) files
              orelse (inParent andalso List.exists (fn (g, s : HsSource.scan) => member m (#imports s)
                                                                               orelse String.isSubstring f (read g)) files) end)
        end
    in
      case List.find (fn (c : HsCorpus.candidate) => #path c = rel) cs of
        SOME c => SOME c
      | NONE => List.find holds cs
    end

  (* the items of a pair of runs on each side, `plain` and `blank`, where
     `go (s, copy)` runs one: old against new on the plain copy, and on each
     side the plain against the blank; what is the same is not kept *)
  fun pragmaPair (item, go) =
    let
      val plain = List.map (fn s => (s, go (s, "plain"))) sides
      val blank = List.map (fn s => (s, go (s, "blank"))) sides
      fun pick (xs, s) = #2 (valOf (List.find (fn (x, _) => x = s) xs))
      val results = (item, differ (pick (plain, "old"), pick (plain, "new")))
                    :: List.map (fn s => (item ^ "/blanked-" ^ s, differ (pick (plain, s), pick (blank, s)))) sides
      val () = if List.all (null o #2) results then List.app (fn (_, t) => clear (#base t)) (plain @ blank) else ()
    in (results, #status (pick (blank, "old")) = 0) end

  (* a file no program of the run set reaches (hartel's Fast2haskell2.hs,
     which none includes): the file alone, checked in a copy of its own,
     as Haskell 98 and under --dotted-names *)
  fun pragmaAlone (w, rel) =
    let
      val f = OS.Path.file rel
      val text = HsSource.universal (read (HsCorpus.tree rel))
      fun dir copy = w ^ "/" ^ copy ^ "/alone/" ^ HsCorpus.dirname rel
      val () = (mkdirs (dir "plain"); mkdirs (dir "blank");
                write (dir "plain" ^ "/" ^ f, text); write (dir "blank" ^ "/" ^ f, HsSource.blankPragmas text))
      val subst = [(w ^ "/plain/", w ^ "/blank/")]
      fun one flags =
        let val item = "pragmas/" ^ rel ^ "/alone" ^ (if null flags then "" else ".dotted") ^ "/check"
        in #1 (pragmaPair (item, fn (s, copy) => call (s, ["--typecheck-only"] @ flags @ [f], dir copy,
                                                       itemBase (s, item) ^ "." ^ copy, false, subst))) end
    in one [] @ one ["--dotted-names"] end

  (* a file with pragmas in its program, each try the harness makes up to
     the first in which the old rhc compiles the copy with them blanked; in
     each, the program compiled to both targets and, where the file is not
     its main, the file checked *)
  fun pragmaOne rel =
    HsCorpusRun.fromVendored (fn () =>
      case holder rel of
        NONE => pragmaAlone (out () ^ "/pragmas", rel)
      | SOME c =>
      let
        val isMain = #path c = rel
        val row = List.find (fn r => HsCorpus.field r "id" = #id c) (HsCorpus.rows "run.tsv")
        (* the harness's variant, but h98 for its compat layer, which
           replaces the file NofibUtils that has pragmas *)
        val variant = case Option.map (fn r => HsCorpus.field r "variant") row of
                        SOME "" => "h98" | SOME "harness" => "h98" | SOME v => v | NONE => "h98"
        val {files, rewritable, ...} = HsCorpus.closureOf c
        val vs = [variant] @ (if variant <> "rewrite" andalso not (null rewritable) then ["rewrite"] else [])
        val tries = List.map (fn v => (v, [])) vs @ [(List.last vs, ["--dotted-names"])]
        val w = out () ^ "/pragmas"
        val f = OS.Path.file rel
        (* a copy, its pragmas as written (plain) or blanked (blank); a file
           of the parent's directory, which the harness copies as it is,
           blanked by hand in the blank copy *)
        fun prepared (copy, v) =
          let
            val () = HsCorpus.keepPragmas := (copy = "plain")
            val work = w ^ "/" ^ copy ^ "/" ^ #id c ^ "/" ^ v
            val (p, mainName) = HsCorpus.prepare (c, v, files, work)
            val () = HsCorpus.keepPragmas := false
            val beside = work ^ "/" ^ f
            val () = if copy = "blank" andalso exists beside
                     then write (beside, HsSource.blankPragmas (HsSource.universal (read beside))) else ()
          in (p, mainName) end
          handle e => (HsCorpus.keepPragmas := false; raise e)
        (* where the file is in a prepared copy, from its program's directory *)
        fun inCopy (p, mainName) =
          let val r = HsCorpus.dirname (#path c)
          in
            if isMain then mainName
            else if exists (p ^ "/" ^ HsCorpus.relative (r, rel)) then HsCorpus.relative (r, rel)
            else if exists (p ^ "/" ^ f) then f
            else "../" ^ f
          end
        fun oneTry (v, flags) =
          let
            val tag = v ^ (if null flags then "" else ".dotted")
            val (pb, mb) = prepared ("blank", v)
            val (pu, mu) = prepared ("plain", v)
            val () = need (mb = mu, rel ^ ": the copies' mains differ")
            val subst = [(w ^ "/plain/", w ^ "/blank/")]
            val kinds = [("register", fn dst => flags @ [mu, "-o", dst], true),
                         ("stack", fn dst => flags @ [mu, "--target=stack", "-o", dst], true)]
                        @ (if isMain then [] else [("check", fn _ => ["--typecheck-only"] @ flags @ [inCopy (pu, mu)], false)])
            fun kind (k, args, product) =
              let val item = "pragmas/" ^ rel ^ "/" ^ tag ^ "/" ^ k
              in pragmaPair (item, fn (s, copy) => let val b = itemBase (s, item) ^ "." ^ copy
                                                   in call (s, args (b ^ ".rbc"), if copy = "plain" then pu else pb, b, product,
                                                            subst) end) end
            val done = List.map kind kinds
          in (List.concat (List.map #1 done), #2 (hd done)) end
        (* the tries in order, up to the first the old rhc compiles *)
        fun go [] = []
          | go (t :: ts) = let val (items, compiled) = oneTry t in items @ (if compiled then [] else go ts) end
      in go tries end)

  (* ---- The jobs *)

  val shardsOf = [("lang", 24), ("run-set", 8), ("errors", 4), ("accept", 2), ("views", 6)]
  fun shard (k, n) xs = List.map #2 (List.filter (fn (i, _) => i mod n = k - 1) (ListPair.zip (List.tabulate (length xs, fn i => i), xs)))
  fun jobName (set, k, n) = set ^ "-" ^ Int.toString k ^ "-of-" ^ Int.toString n

  fun runSet (set, k, n) =
    let
      val () = ready ()
      val items =
        case set of
          "lang" => List.concat (List.map (langOne targets levels) (shard (k, n) (programs "tests/hs/lang")))
        | "run-set" => List.concat (List.map runSetOne (shard (k, n) (runSetIds ())))
        | "errors" => List.map errorsOne (shard (k, n) (programs "tests/hs/errors"))
        | "accept" => List.map acceptOne (shard (k, n) (programs "tests/hs/accept"))
        | "views" => List.concat (List.map (fn f => List.map (fn v => viewOne (f, v)) views) (shard (k, n) (viewFiles ())))
        | _ => raise Failed ("no set " ^ set)
    in report (jobName (set, k, n), items) end

  fun snapshotJob () = (ready (); report ("snapshot", snapshotItems ()))
  fun pragmasJob () =
    let val () = ready ()
        val fs = pragmaFiles ()
        val () = say ("hs-standing: " ^ Int.toString (length fs) ^ " vendored files with pragmas: " ^ String.concatWith " " fs ^ "\n")
    in report ("pragmas", List.concat (List.map pragmaOne fs)) end

  fun allJobs () = List.concat (List.map (fn (s, n) => List.tabulate (n, fn i => jobName (s, i + 1, n))) shardsOf) @ ["snapshot", "pragmas"]

  (* the sets' counts, and the lines of RUNE_HS_EXPECT that explained nothing *)
  fun summary () =
    let
      val ls = expectations ()
      val dir = out () ^ "/results"
      val missing = List.filter (fn j => not (exists (dir ^ "/" ^ j ^ ".tsv"))) (allJobs ())
      val rows = List.concat (List.map (fn j => List.map (String.fields (fn c => c = #"\t")) (lines (read (dir ^ "/" ^ j ^ ".tsv"))))
                                       (allJobs ()))
      fun setOf (item :: _) = hd (String.fields (fn c => c = #"/") item) | setOf [] = ""
      val sets = ["lang", "run-set", "errors", "accept", "views", "snapshot", "pragmas"]
      fun count (set, v) = length (List.filter (fn r => setOf r = set andalso (case r of [_, _, x, _] => x = v | _ => false)) rows)
      val used = List.mapPartial (fn [_, _, "moved", place] => SOME place | _ => NONE) rows
      val stale = List.filter (fn (l : line) => not (member (#place l) used)) ls
      val table = String.concat (List.map (fn s => s ^ "\t" ^ Int.toString (length (List.filter (fn r => setOf r = s) rows)) ^ "\t"
                                                    ^ Int.toString (count (s, "same")) ^ "\t" ^ Int.toString (count (s, "moved")) ^ "\t"
                                                    ^ Int.toString (count (s, "FAIL")) ^ "\n") sets)
      val () = write (out () ^ "/summary.tsv", "set\titems\tsame\tmoved\tfailed\n" ^ table)
      val what = String.concatWith "; " (List.map (fn s => s ^ ": " ^ firstNonEmpty (sideDir s ^ "/ready")) sides)
    in
      List.app (fn j => say ("FAIL hs-standing @summary: no results of " ^ j ^ "\n")) missing;
      List.app (fn (l : line) => say ("FAIL hs-standing @summary: " ^ #place l ^ " (" ^ #decision l ^ " | " ^ #glob l
                                      ^ ") explains no difference\n")) stale;
      say ("hs-standing: " ^ what ^ "\nset\titems\tsame\tmoved\tfailed\n" ^ table);
      say ((if null missing andalso null stale then "PASS" else "SUMMARY") ^ " hs-standing: "
           ^ Int.toString (length rows) ^ " items, " ^ Int.toString (length (List.filter (fn r => case r of [_, _, "FAIL", _] => true | _ => false) rows))
           ^ " moved otherwise (" ^ out () ^ "/summary.tsv)\n")
    end

  (* ---- The faults: three 98 changes planted, each to be caught *)

  val h = "lib/language/haskell/"
  type plant = {id : string, note : string, edits : CompilerMutantList.edit list}
  val plants : plant list =
    [{id = "foreign", note = "`foreign` reserved in 98 mode, as Haskell 2010 reserves it (8.3)",
      edits = [{file = h ^ "lexer.sml", old = "          | NONE => emit (T.VARID s, a, sl, sc, b)",
                new = "          | NONE => if s = \"foreign\" then failAt (a, !i, \"`foreign` is reserved\") else emit (T.VARID s, a, sl, sc, b)"}]},
     {id = "npk", note = "an n+k pattern refused in 98 mode, as Haskell 2010 removed it",
      edits = [{file = h ^ "parser.sml", old = "if not nk then failAt (sp, \"an n+k pattern where only",
                new = "if true then failAt (sp, \"an n+k pattern, which Haskell 2010 removed, where only"}]},
     {id = "pragma", note = "a LANGUAGE or OPTIONS pragma refused in a 98 module, which D6 forbids",
      edits = [{file = h ^ "lexer.sml", old = "      val n = size src\n      val i = ref 0\n",
                new = "      val n = size src\n      val () = if String.isSubstring \"{-# LANGUAGE\" src orelse String.isSubstring \"{-# OPTIONS\" src\n"
                      ^ "               then raise HsSource.Error ({file = file, start = 0, stop = 1}, \"a pragma names an unknown extension\") else ()\n"
                      ^ "      val i = ref 0\n"}]}]
  (* the items that meet each: the programs E3's flips name (its
     flips/attribution.tsv), and two of the vendored files with pragmas *)
  fun named (dir, ns) = List.filter (fn (p : Lang.program) => member (#name p) ns) (programs dir)
  fun faultItems "foreign" = List.map acceptOne (named ("tests/hs/accept", ["lex.reserved.notspecial"]))
                             @ [viewOne ("tests/hs/accept/lex.reserved.notspecial.hs", "dump-ast")]
    | faultItems "npk" = List.concat (List.map (langOne [("register", [])] [("O1", [])])
                                               (named ("tests/hs/lang", ["dec.note.funbind.plus", "exp.free.eq", "pat.m.npk.succeed"])))
    | faultItems _ = List.concat (List.map pragmaOne ["ghc/testsuite/tests/typecheck/should_run/tcrun006.hs",
                                                      "ghc/testsuite/tests/rename/should_compile/rn039.hs"])

  fun faults () =
    let
      val base = out () ^ "/faults"
      val () = (ignoreExpect := true; if isDir base then rmTree base else (); mkdirs base)
      val good = ofTree root
      (* an rhc of this tree's sources with `edits`, as hs-mutants builds one,
         against this tree's: the items of `items`, each run on both *)
      fun against (id, edits, items) =
        let
          val () = outOverride := SOME (base ^ "/" ^ id)
          val (rbc, status) = CompilerMutants.buildFrom {id = id, edits = edits, srcs = HsMutants.sources ("standing-" ^ id),
                                                         dir = base ^ "/build-" ^ id, out = "rhc.rbc"}
          val () = need (isSome rbc, id ^ " does not build: " ^ status)
          val () = materialize ("old", good)
          val () = materialize ("new", {rbc = valOf rbc, vm = fromRoot "bin/runevm", share = fromRoot "share/rhc",
                                        makefile = fromRoot "Makefile", what = id ^ " built from this tree's sources"})
        in List.filter (not o null o #2) (List.concat (List.map faultItems items)) end
      val ids = List.map #id plants
      val control = against ("unedited", [], ids)
      val () = if null control then say ("PASS hs-standing @faults: rhc built from the sources unedited moves none of the items\n")
               else List.app (fn (i, ps) => say ("FAIL hs-standing @faults: rhc built unedited moves " ^ i ^ " (" ^ commas ps ^ ")\n"))
                             control
    in
      List.app (fn (p : plant) =>
                  case against (#id p, #edits p, [#id p]) of
                    [] => say ("FAIL hs-standing @faults: " ^ #id p ^ " (" ^ #note p ^ ") is not caught\n")
                  | caught => say ("PASS hs-standing @faults: " ^ #id p ^ " (" ^ #note p ^ ") caught by "
                                   ^ String.concatWith ", " (List.map (fn (i, ps) => i ^ " (" ^ commas ps ^ ")") caught) ^ "\n"))
               plants;
      outOverride := NONE
    end

  (* ---- The manifest (the roadmap's M3, Holding 98 mode byte-identical,
     nightly; the lead's ruling of 2026-11-25, which takes hashes for the
     texts, 180 MB of Core): tests/hs/manifest.tsv, a line an item, what this
     tree's rhc says of each in 98 mode, by its status and the hashes of its
     standard output and error (SHA-256, 16 hex digits, the tree's root read
     as <root>): each program of tests/hs/lang and accept's canonical Core
     (`--desugar-only --dump-after=desugar --canonical-core`,
     core/DIR/NAME), each refusal of tests/hs/errors as hs/errors compiles
     it (errors/NAME) and the four views of each file of lang and accept
     (views/DIR/FILE/VIEW), as the per-change check names them. Core is
     rhc's own, so a change to Rune moves none of it [inferred]. Nightly,
     hs-standing/manifest/K-of-N fails an item whose line is not what rhc
     says now, and @stale a line that names no item; the texts are the
     per-change check's (make check-hs98 OLD=<the commit that last wrote
     the manifest>). A commit that moves an item writes the manifest again
     (make hs-manifest: the shards, then `hs-standing manifest-write`,
     which joins what they found) and names its decision. @faults holds the
     job to its work: rhc's mutant HM01 (a match's clauses tried last first)
     must move items of it, and this tree's rhc none *)
  val manifestFile = "tests/hs/manifest.tsv"
  val manifestHeader = "item\tstatus\tstdout\tstderr"
  val manifestShards = 8
  fun hash16 text = String.substring (Hex.fromBytes (Sha256.digest text), 0, 16)

  (* the items: a name and rhc's arguments, run from the root; an item that
     writes bytecode writes it to `scratch` *)
  fun manifestItems scratch =
    List.concat (List.map (fn d =>
      List.map (fn (p : Lang.program) =>
                  ("core/" ^ d ^ "/" ^ #name p, ["--desugar-only", "--dump-after=desugar", "--canonical-core"] @ cargs p @ [srcOf p]))
               (programs ("tests/hs/" ^ d))) ["lang", "accept"])
    @ List.map (fn (p : Lang.program) => ("errors/" ^ #name p, cargs p @ [srcOf p, "-o", scratch ^ "/prog.rbc"]))
               (programs "tests/hs/errors")
    @ List.concat (List.map (fn f => List.map (fn v => ("views/" ^ String.extract (f, size "tests/hs/", NONE) ^ "/" ^ v,
                                                        ["--" ^ v, f])) views)
                            (viewFiles ()))

  (* an item's line, by the rhc `cmd` *)
  fun manifestLine (cmd, scratch) (item, args) =
    let
      val () = mkdirs scratch
      val base = scratch ^ "/run"
      val status = execProcess false limits environment
                     {cmd = cmd @ args, dir = SOME root, stdin = "", stdout = base ^ ".out", stderr = base ^ ".err",
                      timeout = 900}
      fun normal f = replaceAll (replaceAll (read f, scratch, "<scratch>"), root, "<root>")
    in String.concatWith "\t" [item, Int.toString status, hash16 (normal (base ^ ".out")), hash16 (normal (base ^ ".err"))] end

  (* the manifest's lines, by item; none where there is no manifest yet,
     which @stale fails *)
  fun manifestLines () =
    case lines (read (fromRoot manifestFile)) of
      h :: rest => if h = manifestHeader then List.map (fn l => (hd (String.fields (fn c => c = #"\t") l), l)) rest
                   else raise Failed (manifestFile ^ " does not begin with its header: " ^ manifestHeader)
    | [] => []
  (* the commit that last wrote the manifest, whose rhc the per-change check
     takes as OLD to show the texts *)
  fun manifestCommit () =
    let val f = out () ^ "/manifest-commit"
        val () = mkdirs (out ())
        val status = execProcess false Subprocess.unlimited (fn e => e)
                       {cmd = ["git", "log", "-1", "--format=%h", "--", manifestFile], dir = SOME root, stdin = "", stdout = f,
                        stderr = f ^ ".err", timeout = 60}
    in if status = 0 andalso trim (read f) <> "" then trim (read f) else "<the commit that last wrote it>" end

  (* the parts of an item's line that differ from the manifest's *)
  fun movedParts (was, now) =
    let val (a, b) = (String.fields (fn c => c = #"\t") was, String.fields (fn c => c = #"\t") now)
    in List.mapPartial (fn (i, name) => if List.nth (a, i) <> List.nth (b, i) then SOME name else NONE)
                       [(1, "status"), (2, "stdout"), (3, "stderr")]
       handle Subscript => ["the line's form"] end

  (* a shard: each item's line now, kept in OUT/manifest/now-K-of-N.tsv for
     manifest-write, and a FAIL for each that is not the manifest's *)
  fun manifestShard (k, n) =
    let
      val dir = out () ^ "/manifest"
      val scratch = dir ^ "/scratch-" ^ Int.toString k
      val known = manifestLines ()
      val items = shard (k, n) (manifestItems scratch)
      val now = List.map (manifestLine ([fromRoot "bin/rhc"], scratch)) items
      val () = (mkdirs dir; write (dir ^ "/now-" ^ Int.toString k ^ "-of-" ^ Int.toString n ^ ".tsv",
                                   String.concat (List.map (fn l => l ^ "\n") now)))
      val commit = manifestCommit ()
      val fails =
        List.mapPartial (fn l =>
                           let val item = hd (String.fields (fn c => c = #"\t") l)
                           in case List.find (fn (i, _) => i = item) known of
                                NONE => SOME (item ^ ": no line in " ^ manifestFile)
                              | SOME (_, was) => if was = l then NONE
                                                 else SOME (item ^ ": " ^ commas (movedParts (was, l)) ^ " moved since " ^ commit)
                           end) now
    in
      List.app (fn m => say ("FAIL hs-standing manifest " ^ m ^ "\n")) fails;
      if null fails then
        say ("PASS hs-standing manifest " ^ Int.toString k ^ "-of-" ^ Int.toString n ^ ": " ^ Int.toString (length now)
             ^ " items as " ^ manifestFile ^ " has them\n")
      else
        say ("SUMMARY hs-standing manifest " ^ Int.toString k ^ "-of-" ^ Int.toString n ^ ": " ^ Int.toString (length fails)
             ^ " of " ^ Int.toString (length now) ^ " items moved: make check-hs98 OLD=" ^ commit ^ " shows the texts; "
             ^ "a commit that moves them names its decision and writes the manifest again (make hs-manifest)\n")
    end

  (* the lines that name no item, and the manifest's form *)
  fun manifestStale () =
    let
      val known = manifestLines ()
      val () = need (not (null known), "no " ^ manifestFile ^ ", or no line in it: make hs-manifest writes it")
      val items = List.map #1 (manifestItems (out () ^ "/manifest/scratch"))
      val sorted = sort (List.map #1 known)
      val twice = List.filter (fn (a, b) => a = b) (ListPair.zip (sorted, tl sorted)) handle Empty => []
      val stale = List.filter (fn (i, _) => not (member i items)) known
    in
      List.app (fn (i, _) => say ("FAIL hs-standing manifest: " ^ i ^ " is twice in " ^ manifestFile ^ "\n")) twice;
      List.app (fn (i, _) => say ("FAIL hs-standing manifest: " ^ manifestFile ^ " names " ^ i ^ ", which is no item\n")) stale;
      List.app (fn (_, l) => if length (String.fields (fn c => c = #"\t") l) <> 4
                             then say ("FAIL hs-standing manifest: not item, status and two hashes: " ^ l ^ "\n") else ()) known;
      say ("hs-standing manifest: " ^ Int.toString (length known) ^ " lines, " ^ Int.toString (length items) ^ " items\n")
    end

  (* the manifest written again from the shards' lines of a run of them *)
  fun manifestWrite () =
    let
      val dir = out () ^ "/manifest"
      val parts = List.tabulate (manifestShards, fn i => dir ^ "/now-" ^ Int.toString (i + 1) ^ "-of-" ^ Int.toString manifestShards ^ ".tsv")
      val () = List.app (fn f => need (exists f, "no " ^ f ^ ": run the shards first, with RUNE_HS_STANDING_OUT set as here "
                                                ^ "(make hs-manifest does both)")) parts
      val ls = sort (List.concat (List.map (fn f => lines (read f)) parts))
    in
      write (fromRoot manifestFile, manifestHeader ^ "\n" ^ String.concat (List.map (fn l => l ^ "\n") ls));
      say ("hs-standing manifest: wrote " ^ Int.toString (length ls) ^ " lines to " ^ manifestFile ^ "\n")
    end

  (* the manifest's job held to its work: a Core change planted (HM01) moves
     items, and this tree's rhc moves none, on the first items of Core *)
  fun manifestFaults () =
    let
      val base = out () ^ "/manifest-faults"
      val () = (if isDir base then rmTree base else (); mkdirs base)
      val m = case List.find (fn (m : HsMutantList.mutant) => #id m = "HM01") HsMutantList.mutants of
                SOME m => m | NONE => raise Failed "no mutant HM01 in tests/runner/hsmutantlist.sml"
      val known = manifestLines ()
      val items = List.take (manifestItems (base ^ "/scratch"), 24)
      fun moved cmd = List.filter (fn l => case List.find (fn (i, _) => i = hd (String.fields (fn c => c = #"\t") l)) known of
                                             SOME (_, was) => was <> l | NONE => true)
                                  (List.map (manifestLine (cmd, base ^ "/scratch")) items)
      val good = moved [fromRoot "bin/rhc"]
      val () = outOverride := SOME base
      val (rbc, status) = CompilerMutants.buildFrom {id = "HM01", edits = #edits m, srcs = HsMutants.sources "manifest-HM01",
                                                     dir = base ^ "/build", out = "rhc.rbc"}
      val () = need (isSome rbc, "HM01 does not build: " ^ status)
      val () = materialize ("new", {rbc = valOf rbc, vm = fromRoot "bin/runevm", share = fromRoot "share/rhc",
                                    makefile = fromRoot "Makefile", what = "HM01 built from this tree's sources"})
      val planted = moved (rhcOf "new")
      val () = outOverride := NONE
    in
      if null good then say ("PASS hs-standing manifest @faults: this tree's rhc moves none of the first 24 items\n")
      else List.app (fn l => say ("FAIL hs-standing manifest @faults: this tree's rhc moves " ^ l ^ "\n")) good;
      if null planted then say ("FAIL hs-standing manifest @faults: HM01 (" ^ #note m ^ ") moves none of the first 24 items\n")
      else say ("PASS hs-standing manifest @faults: HM01 (" ^ #note m ^ ") moves " ^ Int.toString (length planted)
                ^ " of the first 24 items\n")
    end

  fun protect f () = f () handle Failed why => say ("FAIL hs-standing: " ^ why ^ "\n")
                               | e => say ("FAIL hs-standing: " ^ exnText e ^ "\n")
  fun number s = case Int.fromString s of SOME n => n | NONE => 0
  fun command args =
    case args of
      ["hs-standing", "prepare"] => SOME (protect prepare)
    | ["hs-standing", "snapshot"] => SOME (protect snapshotJob)
    | ["hs-standing", "pragmas"] => SOME (protect pragmasJob)
    | ["hs-standing", "summary"] => SOME (protect summary)
    | ["hs-standing", "faults"] => SOME (protect faults)
    | ["hs-standing", "manifest", k, n] => SOME (protect (fn () => manifestShard (number k, number n)))
    | ["hs-standing", "manifest-stale"] => SOME (protect manifestStale)
    | ["hs-standing", "manifest-write"] => SOME (protect manifestWrite)
    | ["hs-standing", "manifest-faults"] => SOME (protect manifestFaults)
    | ["hs-standing", set, k, n] =>
        if List.exists (fn (s, _) => s = set) shardsOf then SOME (protect (fn () => runSet (set, number k, number n))) else NONE
    | _ => NONE

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*", "covers:rhc.build",
                "covers:tests/runner/hsstanding.sml"]
  fun tree () =
    let
      val job = HsOracles.job
      val prep = "hs-standing/@prepare"
      val sets = List.concat (List.map (fn (s, n) =>
                   List.tabulate (n, fn i => job (s ^ "/" ^ Int.toString (i + 1) ^ "-of-" ^ Int.toString n,
                                                  ["hs-standing", s, Int.toString (i + 1), Int.toString n], [prep], 7200, 2000)))
                   shardsOf)
                 @ [job ("snapshot", ["hs-standing", "snapshot"], [prep], 600, 1000),
                    job ("pragmas", ["hs-standing", "pragmas"], [prep], 3600, 2000)]
      val names = List.concat (List.map (fn (s, n) => List.tabulate (n, fn i => "hs-standing/" ^ s ^ "/" ^ Int.toString (i + 1)
                                                                               ^ "-of-" ^ Int.toString n)) shardsOf)
                  @ ["hs-standing/snapshot", "hs-standing/pragmas"]
      val check = Test.tag "check-hs98"
                    (Test.describe "" (job ("@prepare", ["hs-standing", "prepare"], [], 7200, 2000) :: sets
                                       @ [job ("@summary", ["hs-standing", "summary"], names, 600, 500)]))
      val check = if env ("RUNE_HS_OLD", "") = "" then Test.pending "RUNE_HS_OLD names no side (make check-hs98 OLD=...)" check
                  else check
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.requires ["rhc"]
          (Test.describe "hs-standing"
             [check, Test.tag "nightly" (Test.tag "check-hs98-faults" (job ("@faults", ["hs-standing", "faults"], [], 7200, 2000))),
              Test.tag "nightly" (Test.tag "covers:tests/hs/manifest.tsv"
                (Test.describe "manifest"
                   (List.tabulate (manifestShards, fn i => job (Int.toString (i + 1) ^ "-of-" ^ Int.toString manifestShards,
                                                                ["hs-standing", "manifest", Int.toString (i + 1),
                                                                 Int.toString manifestShards], [], 7200, 2000))
                    @ [job ("@stale", ["hs-standing", "manifest-stale"], [], 600, 500),
                       Test.tag "check-hs98-faults" (job ("@faults", ["hs-standing", "manifest-faults"], [], 7200, 2000))])))]))
        covers
    end
end
