(* The command line: list, run, explain, stats. *)
structure Cli :> CLI =
struct
  fun say s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)
  exception Usage of string

  (* the value of an option, and the words that are not options *)
  fun option (name, args) =
    let fun go (a :: v :: rest) = if a = name then SOME v else go (v :: rest) | go _ = NONE in go args end
  fun flag (name, args) = List.exists (fn a => a = name) args
  val valued = ["--tier", "--profile", "-j", "--mem", "--root", "--out", "--history", "--since", "--changed"]
  fun words args =
    let
      fun go (a :: v :: rest) = if List.exists (fn x => x = a) valued then go rest
                                else if String.isPrefix "-" a then go (v :: rest) else a :: go (v :: rest)
        | go [a] = if String.isPrefix "-" a then [] else [a]
        | go [] = []
    in go args end

  fun number (name, args, default) =
    case option (name, args) of
      NONE => default
    | SOME v => (case Int.fromString v of SOME n => n | NONE => raise Usage (name ^ " wants a number"))

  (* the processors of the machine less its load from outside, at least 1 *)
  fun freeProcessors () =
    let
      val s = TextIO.openIn "/proc/loadavg"
      val load = case TextIO.inputLine s of
                   SOME l => (case String.tokens Char.isSpace l of x :: _ => getOpt (Real.fromString x, 0.0) | [] => 0.0)
                 | NONE => 0.0
      val () = TextIO.closeIn s
    in Int.max (1, Runtime.processors () - Real.round load) end
    handle IO.Io _ => Runtime.processors ()

  (* the megabytes the machine has free, or 8000 where it does not say *)
  fun freeMemory () =
    let
      val s = TextIO.openIn "/proc/meminfo"
      fun go () = case TextIO.inputLine s of
                    NONE => 8000
                  | SOME l => (case String.tokens Char.isSpace l of
                                 ["MemAvailable:", kb, _] => getOpt (Int.fromString kb, 8000000) div 1024
                               | _ => go ())
    in go () before TextIO.closeIn s end
    handle IO.Io _ => 8000

  (* the lines of a file, without empty ones *)
  fun fileLines file =
    let val s = TextIO.openIn file
    in List.filter (fn l => l <> "") (String.tokens (fn c => c = #"\n") (TextIO.inputAll s)) before TextIO.closeIn s end
    handle IO.Io _ => raise Usage ("cannot read " ^ file)

  (* the paths that changed since a revision, in the work tree and not yet
     known to git, by git *)
  fun changedSince rev =
    let
      val tmp = OS.FileSys.tmpName ()
      val ok = OS.Process.isSuccess (OS.Process.system ("{ git diff --name-only '" ^ rev ^ "' -- && git ls-files --others --exclude-standard; } > "
                                                         ^ tmp ^ " 2> /dev/null"))
      val paths = if ok then fileLines tmp else raise Usage ("git cannot say what changed since " ^ rev)
    in (OS.FileSys.remove tmp handle OS.SysErr _ => ()); paths end

  (* the tests that cover a changed path, by their tags covers:GLOB; every
     test when a path is covered by none *)
  fun affected (all : {path : string, meta : Test.meta, leaf : 'a} list, changed) =
    let
      fun covers ({meta, ...} : {path : string, meta : Test.meta, leaf : 'a}) =
        List.mapPartial (fn t => if String.isPrefix "covers:" t then SOME (String.extract (t, size "covers:", NONE)) else NONE)
                        (#tags meta)
      (* every glob once, and the globs that match a changed path *)
      val globs = List.foldl (fn (g, acc) => if List.exists (fn x => x = g) acc then acc else g :: acc) []
                             (List.concat (List.map covers all))
      val parsed = List.map (fn g => (g, TestFilter.parse g)) globs
      fun matching p = List.mapPartial (fn (g, f) => if TestFilter.matches f {path = p, tags = []} then SOME g else NONE) parsed
      val per = List.map (fn p => (p, matching p)) changed
    in
      case List.find (fn (_, gs) => null gs) per of
        SOME (p, _) => (say ("affected: " ^ p ^ " is covered by no test, so every test is\n"); all)
      | NONE =>
          let val hit = List.concat (List.map #2 per)
          in
            say ("affected: " ^ Int.toString (length changed) ^ " paths changed\n");
            List.filter (fn x => List.exists (fn g => List.exists (fn h => h = g) hit) (covers x)) all
          end
    end

  fun mainWith {tests = tree : Run.command Test.tree, capabilities} =
    let
      val args = CommandLine.arguments ()
      val (command, rest) = case args of c :: r => (c, r) | [] => ("run", [])
      (* each word a filter, and the tests of any of them *)
      val filterText = String.concatWith " | " (List.map (fn w => "(" ^ w ^ ")") (words rest))
      val filter =
        TestFilter.parse (case (case option ("--tier", rest) of NONE => option ("--profile", rest) | t => t) of
                            NONE => filterText
                          | SOME t => if filterText = "" then "tag:" ^ t else "(" ^ filterText ^ ") & tag:" ^ t)
        handle TestFilter.Parse m => raise Usage ("the filter: " ^ m)
      val root = getOpt (option ("--root", rest), ".")
      val () = Run.accept := flag ("--accept", rest)
      val history = getOpt (option ("--history", rest), "build/test-history.tsv")
      val all = Test.leaves tree
      val selected = List.filter (fn {path, meta, ...} => TestFilter.matches filter {path = path, tags = #tags meta}) all
      val selected =
        case (option ("--changed", rest), option ("--since", rest), flag ("--affected", rest)) of
          (SOME file, _, _) => affected (selected, fileLines file)
        | (NONE, SOME rev, _) => affected (selected, changedSince rev)
        | (NONE, NONE, true) => affected (selected, changedSince "HEAD")
        | (NONE, NONE, false) => selected
      val selected =
        if flag ("--failed", rest) then
          let val h = History.read history
          in List.filter (fn {path, ...} => History.failedLast (h, path)) selected end
        else selected
      (* and the tests they wait for, and those they wait for: a test runs
         with what it needs *)
      val selected =
        let
          val allV = Vector.fromList all
          val find = Run.index (Vector.map #path allV)
          val chosen = Array.array (Vector.length allV, false)
          fun choose i =
            if Array.sub (chosen, i) then ()
            else (Array.update (chosen, i, true);
                  List.app (fn p => case find p of SOME j => choose j | NONE => ())
                           (#after (#leaf (Vector.sub (allV, i)) : Run.command)))
          val () = List.app (fn {path, ...} => case find path of SOME i => choose i | NONE => ()) selected
          (* the tests that run in every run: the canaries *)
          val () = if command = "run" then
                     Vector.appi (fn (i, {meta, ...}) => if List.exists (fn t => t = "always") (#tags meta) then choose i else ())
                                 allV
                   else ()
        in Vector.foldri (fn (i, x, acc) => if Array.sub (chosen, i) then x :: acc else acc) [] allV end
    in
      case command of
        "list" =>
          (List.app (fn {path, meta, ...} =>
                       say (path ^ (case List.filter (fn t => not (String.isPrefix "covers:" t)) (#tags meta) of
                                      [] => ""
                                    | ts => "  [" ^ String.concatWith "," ts ^ "]")
                                                  ^ "\n")) selected;
           say (Int.toString (length selected) ^ " tests\n"))
      | "run" =>
          let
            val ok =
              Run.run {tests = List.map (fn {path, meta, leaf} => (path, meta, leaf)) selected, root = root,
                       out = getOpt (option ("--out", rest), "tests/out/r"), history = history,
                       cpus = number ("-j", rest, freeProcessors ()), memory = number ("--mem", rest, freeMemory ()),
                       keep = flag ("--keep", rest), reader = Report.reader (), capabilities = capabilities,
                       (* the tier check must be complete: what it lacks is an error *)
                       strict = option ("--tier", rest) = SOME "check" orelse flag ("--strict", rest)}
          in OS.Process.exit (if ok then OS.Process.success else OS.Process.failure) end
      | "explain" =>
          List.app (fn {path, meta, leaf = c : Run.command} =>
                      say (path ^ "\n  command: " ^ String.concatWith " " (#args c)
                           ^ "\n  directory: " ^ getOpt (#dir c, "(its own)")
                           ^ "\n  tags: " ^ String.concatWith "," (#tags meta)
                           ^ "\n  cpus: " ^ Int.toString (getOpt (#cpus meta, #cpus c))
                           ^ ", memory: " ^ Int.toString (getOpt (#memory meta, #memory c)) ^ " MB"
                           ^ "\n  pools: " ^ String.concatWith "," (#pools c)
                           ^ (if #exclusive c then "\n  exclusive" else "")
                           ^ "\n  after: " ^ String.concatWith "," (#after c) ^ "\n"))
                   selected
      | "stats" =>
          let
            val es = History.entries (History.read history)
            fun top (key, xs) =
              List.take (List.foldl (fn (x, acc) =>
                                       let fun ins [] = [x] | ins (y :: ys) = if key x >= key y then x :: y :: ys else y :: ins ys
                                       in ins acc end) [] xs, Int.min (10, length xs))
            fun slowest ({walls, ...} : History.entry) = List.foldl Real.max 0.0 walls
          in
            say "slowest:\n";
            List.app (fn e => say ("  " ^ #path e ^ " " ^ Real.fmt (StringCvt.FIX (SOME 1)) (slowest e) ^ " s\n"))
                     (top (slowest, es));
            say "flakiest (changes of verdict):\n";
            List.app (fn e => say ("  " ^ #path e ^ " " ^ Int.toString (#flips e) ^ "\n"))
                     (top (fn e => real (#flips e), List.filter (fn e => #flips e > 0) es))
          end
      | "doctor" =>
          let
            val needed = List.foldl (fn ({meta, ...}, acc) =>
                                       List.foldl (fn (r, acc) => if List.exists (fn x => x = r) acc then acc else acc @ [r]) acc
                                                  (#requires meta))
                                    [] selected
            val missing = Requirements.missing (capabilities, needed)
          in
            List.app (fn r => case List.find (fn (m, _) => m = r) missing of
                                SOME (_, hint) => say ("  missing  " ^ r ^ ": " ^ hint ^ "\n")
                              | NONE => say ("  ok       " ^ r ^ "\n"))
                     needed;
            say ("doctor: " ^ Int.toString (length needed) ^ " capabilities for " ^ Int.toString (length selected) ^ " tests, "
                 ^ Int.toString (length missing) ^ " missing\n");
            OS.Process.exit (if null missing then OS.Process.success else OS.Process.failure)
          end
      | _ => raise Usage ("no command " ^ command ^ " (list, run, explain, stats, doctor)")
    end
    handle Usage m => (TextIO.output (TextIO.stdErr, "rune-test: " ^ m ^ "\n"); TextIO.flushOut TextIO.stdErr;
                       Posix.Process.exit 0w2)

  fun main tree = mainWith {tests = tree, capabilities = []}
end
