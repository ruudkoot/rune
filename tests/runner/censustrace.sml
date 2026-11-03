(* Trace production for replay checks. A successful producer publishes its
   recipe last; consumers have a runner dependency rather than polling for
   DONE. Each recipe stores argv words separately, including whitespace. *)
structure CensusTrace =
struct
  open HeapChecks
  type recipe = {rbc : string, args : string list, cwd : string, output : string}
  type collection = {clock : IntInf.int, copied : IntInf.int}
  type band = {clock : IntInf.int, lo : IntInf.int, hi : IntInf.int, exact : bool}
  (* The copied bytes of each of the stock VM's collections against the band
     at its own clock, which bin/heapsim --probe gives. The two band runs
     cannot stand in for it: each collects where its own live data puts it
     (the lower band, with less alive, later), and an object that lands
     between two runs' triggers moves a collection past it. compile-sigs at
     4 MiB after build-system M4: the stock's seventh collection came before
     IntTable.grow's array of 4,104 bytes, the lower band's after it and
     4,848 bytes later, copying 4,632 bytes more; the two runs' totals, 304
     bytes apart, were 3,104 and 3,408 bytes above the stock's, while each of
     its eight collections was in its band. Stale registers can still put a
     collection outside (docs/census.md, Limits). NONE when every collection
     is inside its band, else what is wrong with the first that is not. *)
  fun outside (stock : collection list, bands : band list) =
    let
      fun text n = String.translate (fn #"~" => "-" | c => str c) (IntInf.toString n)
      fun go (i, {clock, copied} :: cs, {clock = at, lo, hi, exact} :: bs) =
            let val name = "collection " ^ Int.toString i ^ " at clock " ^ text clock
            in if at <> clock then SOME (name ^ ": the band is at clock " ^ text at)
               else if not exact then SOME (name ^ ": not where an object of the trace begins")
               else if copied < lo orelse hi < copied then
                 SOME (name ^ ": copied " ^ text copied ^ ", the band there " ^ text lo ^ " to " ^ text hi)
               else go (i + 1, cs, bs) end
        | go (_, [], []) = NONE
        | go _ = SOME (Int.toString (length stock) ^ " collections, " ^ Int.toString (length bands) ^ " bands")
    in go (1, stock, bands) end
  (* The stock's collections from its --gc-log (with --nursery 0 every one is
     full), each at the trace's clock: the log's bytes leave out the boxes and
     the objects made before the trace began, which the trace's clock counts
     (tools/measure/sim-validate.sml has them so too). *)
  fun metaValue trace key =
    case List.find (String.isPrefix (key ^ " ")) (lines (read (trace ^ "/meta.txt"))) of
      SOME line => number (String.extract (line, size key + 1, NONE))
    | NONE => raise Failed (trace ^ "/meta.txt: no " ^ key)
  fun collections (log, pretrace) : collection list =
    let fun row line =
          case String.tokens Char.isSpace line of
            _ :: "full" :: _ :: bytes :: _ :: _ :: _ :: boxBytes :: _ :: copied :: _ =>
              {clock = number bytes + number boxBytes + pretrace, copied = number copied}
          | _ => raise Failed (log ^ ": not a full collection: " ^ line)
    in List.map row (List.filter (fn line => line <> "" andalso not (String.isPrefix "#" line)) (lines (read log))) end
  (* bin/heapsim --probe's lines on its standard error: probe: at CLOCK lo LO
     hi HI, and (next object) after them where CLOCK falls inside an object *)
  fun bands text : band list =
    List.mapPartial (fn line =>
      case String.tokens Char.isSpace line of
        "probe:" :: "at" :: clock :: "lo" :: lo :: "hi" :: hi :: rest =>
          SOME {clock = number clock, lo = number lo, hi = number hi, exact = null rest}
      | _ => NONE) (lines text)
  fun liveWithin (lo, hi, actual) = IntInf.min (lo, hi) - 65536 <= actual andalso actual <= IntInf.max (lo, hi) + 65536
  fun budget name key =
    case List.find (String.isPrefix (key ^ " ")) (lines (read ("tests/perf/" ^ name ^ ".budget"))) of
      SOME line => String.tokens Char.isSpace (String.extract (line, size key + 1, NONE)) | NONE => []
  fun prepare dir name : recipe =
    let
      val compiler = env ("RUNE_NEW", "bin/rune")
      val out = dir ^ "/out.rbc"
      val (rbc, args, output) =
        if name = "compile-sigs" orelse name = "compile-hello" then
          (fromRoot "bin/rune.rbc", ["--lib", "lib", "-o", out] @ budget name "compile", out)
        else if name = "bootstrap" then
          (fromRoot "bin/rune.rbc", ["--lib", "lib", "-o", out]
           @ String.tokens Char.isSpace (command dir "sources" ["sh", "scripts/plan-files.sh", "rune.plan"]), out)
        else if name = "runedoc-ir" orelse name = "runedoc-page" then
          (fromRoot "bin/runedoc.rbc", ["--lib", "lib", if name = "runedoc-ir" then "--dump-ir" else "--page"]
           @ glob ("tests/basis/spec-sigs", ".sml"), "")
        else if String.isSuffix ".rbc" name then (fromRoot name, [], "")
        else
          let val rbc = dir ^ "/" ^ name ^ ".rbc"
              val () = need (exists ("tests/perf/" ^ name ^ ".sml"), "unknown census workload " ^ name)
              val () = ignore (command dir "compile" [compiler, "tests/perf/" ^ name ^ ".sml", "-o", rbc])
          in (rbc, budget name "args", "") end
    in {rbc = rbc, args = args, cwd = root, output = output} end
  fun reset ({output, ...} : recipe) = if output = "" then () else rmTree output
  fun writeRecipe file ({rbc, args, cwd, output} : recipe) =
    let fun row (key, value) = key ^ "\t" ^ String.toString value ^ "\n"
    in write (file, "version\t1\n" ^ String.concat (List.map row
          ([("rbc", rbc), ("cwd", cwd), ("output", output)] @ List.map (fn arg => ("arg", arg)) args))) end
  fun readRecipe file : recipe =
    let val rows = List.map (fn line => case String.fields (fn c => c = #"\t") line of
                    [key, value] => (key, case String.fromString value of SOME s => s | NONE => raise Failed "bad recipe escape")
                  | _ => raise Failed "bad recipe row") (lines (read file))
        fun get key = case List.filter (fn (k, _) => key = k) rows of [(_, v)] => v | _ => raise Failed ("missing or repeated recipe " ^ key)
        val () = need (get "version" = "1", "unsupported census recipe")
    in {rbc = get "rbc", cwd = get "cwd", output = get "output", args = List.map #2 (List.filter (fn (k, _) => k = "arg") rows)} end
  fun produce (name, every) =
    let
      val dir = directory ("replay-" ^ name)
      val trace = dir ^ "/trace"
      val () = List.app rmTree [trace, dir ^ "/recipe.tsv"]
      val recipe as {rbc, args, cwd, ...} = prepare dir name
      val stock = env ("RUNEVM_NEW", "bin/runevm")
      val census = env ("RUNEVM_CENSUS", "bin/runevm-census")
      val () = reset recipe
      val stdout = commandIn (fn e => e) cwd dir "stock" ([stock, "--jit=off", "--count", "--heap-size", "67108864", rbc] @ args)
      val () = reset recipe
      val actual = commandIn (fn e => e) cwd dir "census" ([census, "--jit=off", "--count", "--stats", "--heap-size", "1073741824",
           "--heap-fill", "50", "--census-dir", trace, "--census-every", every, rbc] @ args)
      val () = need (stdout = actual andalso count (dir ^ "/stock.err") = count (dir ^ "/census.err"),
                     "census producer differs from stock")
      val () = ignore (command dir "static" [census, "--census-static", rbc])
      val () = writeRecipe (dir ^ "/recipe.pending") recipe
    in OS.FileSys.rename {old = dir ^ "/recipe.pending", new = dir ^ "/recipe.tsv"} end
  fun replayWith {name, dir, trace, report, recipe = recipe as {rbc, args, cwd, ...} : recipe} =
    let
      val () = write (report, "")
      val failures = ref [] : string list ref
      val () = TraceCheck.silent trace
      val () = ignore (command dir "check" ["bin/heapsim", "--check", "--trace", trace])
      val stock = env ("RUNEVM_NEW", "bin/runevm")
      fun one (heap, fill) =
        let
          val label = heap ^ "-" ^ fill
          val log = dir ^ "/stock-" ^ label ^ ".gclog"
          val () = reset recipe
          val () = ignore (commandIn (fn e => e) cwd dir ("stock-" ^ label)
              ([stock, "--jit=off", "--nursery", "0", "--stats", "--gc-log", log, "--heap-size", heap, "--heap-fill", fill, rbc] @ args))
          val stats = case List.rev (List.filter (fn line => String.isPrefix "runevm: " line andalso String.isSubstring " collections," line)
                         (lines (read (dir ^ "/stock-" ^ label ^ ".err")))) of
                        line :: _ => String.tokens (fn c => Char.isSpace c orelse c = #",") line
                      | [] => raise Failed "stock VM printed no GC stats"
          val sc = number (List.nth (stats, 1))
          val sb = number (List.nth (stats, 3))
          val ss = number (List.nth (stats, 7))
          val sl = number (List.nth (stats, 9))
          val sx = number (List.nth (stats, 12))
          val made = collections (log, metaValue trace "pretrace_bytes")
          val () = need (IntInf.fromInt (length made) = sc andalso List.foldl (fn ({copied, ...}, n) => n + copied) 0 made = sx,
                         "stock-" ^ label ^ ": its --gc-log and its --stats disagree")
          val probe = if null made then [] else ["--probe", String.concatWith "," (List.map (fn {clock, ...} => IntInf.toString clock) made)]
          fun band band = command dir (band ^ "-" ^ label) (["bin/heapsim", "--trace", trace, "--workload", name,
                 "--layout", "W8", "--collector", "copier", "--heap-size", heap, "--heap-fill", fill, "--band", band]
                 @ (if band = "lo" then probe else []))
          val lo = band "lo"
          val hi = band "hi"
          val atStock = bands (read (dir ^ "/lo-" ^ label ^ ".err"))
          val miss = outside (made, atStock)
          val (blo, bhi) = List.foldl (fn ({lo, hi, ...}, (a, b)) => (a + lo, b + hi)) (0, 0) atStock
          val lc = numeric (lo, 27)
          val hc = numeric (hi, 27)
          val lx = numeric (lo, 20)
          val hx = numeric (hi, 20)
          val ll = numeric (lo, 31)
          val hl = numeric (hi, 31)
          val verdict = if IntInf.min (lc, hc) <= sc andalso sc <= IntInf.max (lc, hc) then "ok" else "COLLECTIONS"
          val verdict = verdict ^ (if numeric (lo, 30) = ss then "" else "/SEMISPACE")
          val verdict = verdict ^ (if numeric (lo, 8) = sb then "" else "/BYTES")
          val verdict = verdict ^ (if isSome miss then "/COPIED" else "")
          val verdict = if verdict = "ok" andalso not (liveWithin (ll, hl, sl)) then "LIVE" else verdict
          fun text n = String.translate (fn #"~" => "-" | c => str c) (IntInf.toString n)
          fun group ns = String.concatWith " " (List.map text ns)
          (* the band at the stock's own collections, summed, and its width *)
          val width = if blo = 0 then "0" else String.translate (fn #"~" => "-" | c => str c)
                (Real.fmt (StringCvt.FIX (SOME 3)) (100.0 * Real.fromLargeInt (IntInf.toLarge (bhi - blo)) / Real.fromLargeInt (IntInf.toLarge blo)))
          val row = String.concatWith "\t" [name, heap, fill,
                "| " ^ group [sc, ss, sx, sl, number (List.nth (stats, 17))] ^ " us",
                "| " ^ group [lc, numeric (lo, 30), lx, ll], "| " ^ group [hc, numeric (hi, 30), hx, hl],
                "| " ^ group [blo, bhi] ^ " " ^ width ^ "%", verdict]
          val () = append (report, row ^ "\n")
          val () = say (row ^ "\n")
        in if verdict = "ok" then ()
           else failures := (label ^ ": " ^ verdict ^ (case miss of SOME why => " (" ^ why ^ ")" | NONE => "")) :: !failures end
      val () = List.app one [("4194304", "50"), ("67108864", "50"), ("268435456", "50"), ("67108864", "25"), ("67108864", "80")]
    in need (null (!failures), String.concatWith "; " (List.rev (!failures))) end
  fun replay name =
    let val dir = directory ("replay-" ^ name)
    in replayWith {name = name, dir = dir, trace = dir ^ "/trace", report = dir ^ "/" ^ name ^ ".validate",
                   recipe = readRecipe (dir ^ "/recipe.tsv")} end
  (* Keep the standalone replay interface for existing census archives.
     The SML census producer may make
     an absent/stale archive, while all replay assertions live here. *)
  fun validate out names =
    let
      val out = fromRoot out
      val traces = fromRoot (env ("CENSUS_TRACES", "tests/out/census"))
      val () = mkdirs out
      fun one name =
        let
          val dir = out ^ "/" ^ name
          val () = mkdirs dir
          val trace = traces ^ "/" ^ name
          val done = trace ^ "/DONE"
          fun rows () = lines (read done)
          fun value key = case List.find (String.isPrefix (key ^ " ")) (rows ()) of
                  SOME line => String.extract (line, size key + 1, NONE) | NONE => ""
          fun recipe () : recipe =
            case String.tokens Char.isSpace (value "cmd") of
              rbc :: args => {rbc = rbc, args = args, cwd = value "cwd", output = value "out"}
            | [] => raise Failed ("no command in " ^ done)
          fun newer path = not (exists path) orelse Time.> (OS.FileSys.modTime path, OS.FileSys.modTime done)
          val fresh = exists done andalso
            ((let val r = recipe ()
              in not (newer (#rbc r) orelse newer (fromRoot "bin/runevm") orelse newer (fromRoot "bin/runevm-census")) end)
             handle Failed _ => false)
          val () = if fresh then () else
            let val () = rmTree done
                val every = env ("CENSUS_EVERY", "")
                val args = [fromRoot "bin/rune-measure", "census", "--out", traces]
                           @ (if every = "" then [] else ["--every", every]) @ [name]
            in ignore (command dir "produce" args);
               need (exists done andalso value "cmd" <> "", "census producer published no successful recipe") end
          val recipe = recipe ()
          val () = need (#cwd recipe <> "", "census recipe has no working directory")
        in replayWith {name = name, dir = dir, trace = trace, report = out ^ "/" ^ name ^ ".validate", recipe = recipe} end
      val failed = ref false
      fun run name = one name handle Failed message => (failed := true; say ("FAIL " ^ name ^ ": " ^ message ^ "\n"))
        | TraceCheck.Invalid message => (failed := true; say ("FAIL " ^ name ^ ": " ^ message ^ "\n"))
      val () = List.app run names
    in need (not (!failed), "one or more replay workloads failed"); say "heapsim validate: ok\n" end
end
