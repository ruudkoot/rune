(* Census and heap experiment assertions. Each command is one bounded case;
   the runner supplies ordering, scheduling and the shared run directory. *)
structure HeapChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok, message) = if ok then () else raise Failed message
  val base = run ^ "/heap-checks"
  val limits = {addressSpace = SOME 4294967296, cpuTime = SOME 600,
                fileSize = SOME 1073741824, core = SOME 0}
  fun directory name = let val dir = base ^ "/" ^ name in mkdirs dir; dir end
  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))
  fun number s = case IntInf.fromString (trim s) of SOME n => n | NONE => raise Failed ("not an integer: " ^ s)
  fun commandIn envf cwd dir label command =
    let val program = OS.Path.file (hd command)
        val limits = {addressSpace = SOME (if program = "gcsim" then 2147483648 else 4294967296),
                      cpuTime = SOME 600, fileSize = SOME 1073741824, core = SOME 0}
        val timeout = if program = "gcbench" orelse String.isPrefix "harness-" program then 120 else 600
        val status = Children.exec limits envf
          {cmd = command, dir = SOME cwd, stdin = "", stdout = dir ^ "/" ^ label ^ ".out",
           stderr = dir ^ "/" ^ label ^ ".err", timeout = timeout}
    in need (status = 0, label ^ ": exit " ^ Int.toString status ^ ": " ^ firstLine (dir ^ "/" ^ label ^ ".err"));
       read (dir ^ "/" ^ label ^ ".out") end
  fun command dir label args = commandIn (fn e => e) root dir label args
  fun equal (label, actual, expected) = need (actual = expected, label ^ ": got " ^ IntInf.toString actual ^ ", want " ^ IntInf.toString expected)
  fun column (row, n) = List.nth (String.fields (fn c => c = #"\t") (trim row), n - 1)
  fun numeric (row, n) = number (column (row, n))
  fun count file =
    case List.rev (List.filter (String.isPrefix "runevm: count: ") (lines (read file))) of
      line :: _ => line | [] => raise Failed (file ^ ": no count line")
  fun census () =
    let
      val dir = directory "census"
      val trace = dir ^ "/trace"
      val summary = dir ^ "/summary"
      val () = List.app rmTree [trace, summary]
      val rbc = dir ^ "/program.rbc"
      val rune = env ("RUNE_NEW", "bin/rune")
      val vm = env ("RUNEVM_NEW", "bin/runevm")
      val census = env ("RUNEVM_CENSUS", "bin/runevm-census")
      val () = ignore (command dir "compile" [rune, env ("PROGRAM", "tests/perf/list_ops.sml"), "-o", rbc])
      val stock = command dir "stock" [vm, "--jit=off", "--count", rbc]
      val actual = command dir "census" [census, "--jit=off", "--count", "--census-dir", trace,
                                          "--census-every", "65536", "--census-graph", rbc]
      val counted = count (dir ^ "/stock.err")
      val () = need (counted = count (dir ^ "/census.err"), "census and stock count lines differ")
      val () = need (stock = actual, "census and stock stdout differ")
      val words = String.tokens (fn c => Char.isSpace c orelse c = #",") counted
      val bytes = number (List.nth (words, 4))
      val objects = number (List.nth (words, 6))
      val table = lines (read (trace ^ "/census.txt"))
      fun row marker = case List.find (String.isPrefix marker) table of SOME s => String.tokens Char.isSpace s
                       | NONE => raise Failed ("census.txt: missing " ^ marker)
      val counts = row "# count_objects "
      val () = equal ("table objects", number (List.nth (counts, 2)), objects)
      val () = equal ("table bytes", number (List.nth (counts, 4)), bytes)
      val () = List.app (fn file => need (exists (trace ^ "/" ^ file) andalso OS.FileSys.fileSize (trace ^ "/" ^ file) > 0,
                                                "missing or empty " ^ file))
                         ["alloc.bin", "fields.bin", "graph.bin", "death.bin", "samples.bin", "pcs.bin", "meta.txt"]
      val () = need (exists (trace ^ "/stores.bin"), "stores.bin missing")
      val () = need (number (List.nth (row "# samples ", 2)) > 0, "no forced samples")
      val () = TraceCheck.check trace
      val () = ignore (command dir "summary" [census, "--jit=off", "--count", "--census-dir", summary,
                                                "--census-every", "65536", "--census-summary", rbc])
      val () = need (count (dir ^ "/summary.err") = counted andalso exists (summary ^ "/census.txt")
                      andalso OS.FileSys.fileSize (summary ^ "/census.txt") > 0 andalso not (exists (summary ^ "/alloc.bin")),
                     "summary count or file set differs")
      val static = command dir "static" [census, "--census-static", rbc]
      val rows = lines static
      val functions = length (List.filter (String.isPrefix "F\t") rows)
      val sites = length (List.filter (String.isPrefix "S\t") rows)
      val header = case List.find (String.isPrefix "# static census of ") rows of SOME h => h | NONE => raise Failed "static header missing"
      val suffix = Substring.string (#2 (Substring.position ": " (Substring.full header)))
      val declared = number (List.nth (String.tokens Char.isSpace suffix, 1))
      val () = equal ("static function count", IntInf.fromInt functions, declared)
    in need (sites > 0, "static census has no sites") end
  fun traceName (seed, sample) = "s" ^ seed ^ "-" ^ sample
  fun synthetic (seed, sample) =
    let val dir = directory ("synthetic-" ^ traceName (seed, sample))
        val trace = dir ^ "/trace"
        val () = rmTree trace
        val truth = String.tokens Char.isSpace (command dir "generate" ["bin/heapsim-gen", "--out", trace,
          "--objects", "150000", "--sample", sample, "--seed", seed, "--heap-size", "4194304"])
        val () = ignore (command dir "check" ["bin/heapsim", "--check", "--trace", trace])
        val lo = command dir "lo" ["bin/heapsim", "--trace", trace, "--layout", "W8", "--collector", "copier", "--band", "lo"]
        val hi = command dir "hi" ["bin/heapsim", "--trace", trace, "--layout", "W8", "--collector", "copier", "--band", "hi"]
        val copied = number (List.nth (truth, 12))
        val live = number (List.nth (truth, 14))
        val mn = IntInf.min (numeric (lo, 20), numeric (hi, 20))
        val mx = IntInf.max (numeric (lo, 20), numeric (hi, 20))
        val slack = IntInf.div (mx - mn, 2) + 1
        val () = need (mn - slack <= copied andalso copied <= mx + slack, "truth copied bytes outside simulator bands")
    in if number sample > 4096 then () else
       (List.app (fn row =>
          (equal ("collections", numeric (row, 27), number (List.nth (truth, 8)));
           equal ("semispace", numeric (row, 30), number (List.nth (truth, 10))))) [lo, hi];
        need (numeric (lo, 31) - slack <= live andalso live <= numeric (hi, 31) + slack, "truth live bytes outside simulator bands")) end
  val collectors = [["copier"], ["nursery", "--nursery", "256K"], ["nursery", "--nursery", "1M", "--promote", "2"],
                    ["sticky", "--nursery", "512K"], ["los", "--los", "2K"], ["mutseg", "--nursery", "256K"]]
  val layouts = [["W8"], ["L0"], ["L1"], ["L1", "--variant", "REALIMM"], ["L2"], ["L3"], ["L3", "--variant", "NAN51"],
                 ["L4"], ["L4", "--variant", "L4UNIFORM"], ["L1", "--variant", "PAIRS,HDR4,COMPACT"], ["L4", "--variant", "ALIGN16"]]
  fun coverage (ci, li, band) =
    let val dir = directory ("coverage-" ^ Int.toString ci ^ "-" ^ Int.toString li ^ "-" ^ band)
        val trace = base ^ "/synthetic-s1-4096/trace"
    in ignore (command dir "simulate" (["bin/heapsim", "--trace", trace, "--layout"] @ List.nth (layouts, li)
               @ ["--collector"] @ List.nth (collectors, ci) @ ["--band", band])) end
  val kernels = [("list_ops", "300000", "32"), ("intmap", "60000", "8"), ("strmap", "60000", "8"),
     ("inttable", "100000", "24"), ("closures", "300000", "8"), ("int_loop", "1", "8"),
     ("word_loop", "2000000", "4"), ("real_regs", "100000", "4"), ("real_array", "1000000", "32"),
     ("strings", "200000", "4"), ("poly_eq_tree", "200000", "24"), ("gc_churn8", "20000", "32"),
     ("gc_churn64", "5000", "128"), ("lazy_case_header10", "1000000", "4"), ("lazy_case_code10", "1000000", "4"),
     ("lazy_case_enter10", "1000000", "4"), ("lazy_case_header50", "1000000", "4"), ("lazy_case_code0", "1000000", "4"),
     ("lazy_stream", "1200", "4"), ("lazy_update_old", "500000", "4")]
  fun layout (kernel, n, small) =
    let val dir = directory ("layout-" ^ kernel)
        val cc = OS.Path.file (env ("CC", "cc"))
        val bins = List.filter (fn p => not (isDir p)) (List.map (fn n => "tests/out/layouts/" ^ cc ^ "/" ^ n)
                         (List.filter (String.isPrefix "harness-") (sort (entries ("tests/out/layouts/" ^ cc)))))
        val () = need (not (null bins), "no layout harnesses for " ^ cc)
        val reference = ref NONE : string option ref
        fun one (binary, semi) =
          let val label = OS.Path.file binary ^ (if semi = "" then "-default" else "-small")
              val output = commandIn (fn e => e) (root ^ "/tests/layouts") dir label
                        ([fromRoot binary, kernel, n] @ (if semi = "" then [] else ["-s", semi]))
              val fields = String.tokens Char.isSpace output
              val () = need (length fields >= 3, "layout harness printed no checksum")
              val checksum = List.nth (fields, 2)
          in case !reference of NONE => reference := SOME checksum
             | SOME expected => need (checksum = expected, label ^ ": checksum " ^ checksum ^ " differs from " ^ expected) end
    in List.app (fn binary => List.app (fn semi => one (binary, semi)) [small, ""]) bins end
  fun table text =
    case List.filter (fn line => not (String.isPrefix "#" line)) (lines text) of
      header :: rows =>
        let val names = String.fields (fn c => c = #"\t") header
            fun row text =
              let val values = String.fields (fn c => c = #"\t") text
                  val () = need (length values = length names, "TSV row has the wrong width")
              in ListPair.zip (names, values) end
        in List.map row rows end
    | [] => raise Failed "missing TSV header"
  fun cell name row = case List.find (fn (n, _) => name = n) row of SOME (_, v) => v
                      | NONE => raise Failed ("missing TSV column " ^ name)
  fun gcsim which =
    let
      val dir = directory ("gcsim-" ^ which)
      fun generate name args =
        let val trace = dir ^ "/" ^ name
            val () = rmTree trace
            val () = ignore (command dir ("generate-" ^ name) (["bin/heapsim-gen", "--out", trace] @ args))
        in trace end
      val sequence = ref 0
      fun label prefix = (sequence := !sequence + 1; prefix ^ "-" ^ Int.toString (!sequence))
      fun ev trace args =
        let val file = dir ^ "/events-" ^ Int.toString (!sequence) ^ ".tsv"
            val () = ignore (command dir (label "events") (["bin/gcsim", "--max-mb", "1024", "--trace", trace,
                  "--nursery", "0", "--major-at-samples", "1,2", "--heap-size", "16M", "--events", file] @ args))
        in table (read file) end
      fun field rows sample column =
        number (cell column (List.nth (List.filter (fn row => List.exists (fn k => cell "kind" row = k) ["major", "compact"]) rows, sample - 1)))
      fun expect rows sample column want = equal (which ^ " " ^ column, field rows sample column, want)
      fun row trace args =
        case table (command dir (label "summary") (["bin/gcsim", "--header", "--trace", trace] @ args)) of
          [row] => row | _ => raise Failed "gcsim produced other than one summary row"
      fun old trace args = command dir (label "old") (["bin/heapsim", "--trace", trace, "--layout", "W8"] @ args)
      fun alt32 () =
        let val trace = generate "trace" ["--pattern", "alt", "--size", "32", "--count", "8184"]
            val segfit = ev trace ["--old", "segfit"]
            val () = List.app (fn (k, c, n) => expect segfit k c n)
                       [(1, "marked_bytes", 130944), (1, "usable", 130944), (2, "old_committed", 262144), (2, "usable", 0)]
            val () = List.app (fn allocator => let val events = ev trace ["--old", allocator]
                      in expect events 1 "held" 130944;
                         equal (allocator ^ " holes refilled", field events 2 "old_committed", field events 1 "old_committed") end)
                        ["bestfit", "nextfit", "firstfit"]
            val () = expect (ev trace ["--old", "immix", "--exact-lines", "--no-defrag"]) 1 "held" 261888
            val chez = ev trace ["--old", "chez"]
            val () = expect chez 1 "usable" 0
            val () = expect chez 2 "evac_bytes" 130944
            val mc = ev trace ["--old", "mc"]
            val () = expect mc 1 "moved_bytes" 130944
            val () = expect mc 2 "moved_bytes" 0
        in expect (ev trace ["--old", "copy"]) 1 "moved_bytes" 130944 end
      fun alt128 () =
        let val trace = generate "trace" ["--pattern", "alt", "--size", "128", "--count", "2048"]
            val exact = ev trace ["--old", "immix", "--exact-lines", "--no-defrag"]
            val () = expect exact 1 "held" 131072
            val () = expect exact 1 "usable" 131072
            val () = expect exact 2 "old_committed" 262144
            val conservative = ev trace ["--old", "immix", "--no-defrag"]
            val () = expect conservative 1 "usable" 1024
            val () = expect conservative 2 "old_committed" 393216
            val () = expect (ev trace ["--old", "immix", "--line", "64", "--no-defrag"]) 1 "usable" 66048
        in expect (ev trace ["--old", "immix", "--exact-lines", "--line", "256", "--no-defrag"]) 1 "usable" 0 end
      fun line1 () =
        let val trace = generate "trace" ["--pattern", "line1", "--size", "16", "--count", "16384", "--keep", "8"]
            val () = List.app (fn args => let val events = ev trace (["--old", "immix", "--no-defrag"] @ args)
                          in expect events 1 "usable" 0; expect events 1 "marked_bytes" 32768 end) [["--exact-lines"], []]
        in expect (ev trace ["--old", "segfit"]) 1 "usable" 261856 end
      fun nursery (band, allocator) =
        let val trace = generate "trace" ["--pattern", "nurs", "--nursery-bytes", "65536", "--windows", "10", "--size", "16", "--stores", "100"]
            val args = ["--nursery", "64K", "--band", band, "--old", allocator, "--big", "off"]
            fun want promote column n = equal ("nursery " ^ column, number (cell column (row trace (args @ ["--promote", promote]))), n)
        in want "1" "promoted" 264192; want "2" "promoted" 2048; want "2" "surv_copied" 264192;
           want "1" "remset_total" 700; want "1" "cards_total" 14 end
      fun minors () =
        let val trace = generate "trace" ["--pattern", "nurs", "--nursery-bytes", "65536", "--windows", "10", "--size", "16", "--stores", "100"]
        in equal ("nursery minors", number (cell "minors" (row trace ["--nursery", "64K", "--old", "copy", "--big", "off"])), 9) end
      fun satb () =
        let val trace = generate "trace" ["--pattern", "satb", "--size", "32", "--count", "8184"]
            val file = dir ^ "/events.tsv"
            val args = ["--nursery", "0", "--old", "segfit", "--satb", "2", "--slice", "4096", "--satb-at-sample", "1",
                        "--major-at-samples", "2", "--heap-size", "16M", "--band", "lo"]
            val () = ignore (command dir "satb" (["bin/gcsim", "--max-mb", "1024", "--trace", trace, "--events", file] @ args))
            val events = table (read file)
            val ending = case List.find (fn r => cell "kind" r = "satb-end") events of SOME r => r | NONE => raise Failed "no SATB end event"
            val () = equal ("floating garbage", number (cell "satb_float_total" (row trace args)), 130944)
            val () = equal ("cycle frees nothing", number (cell "swept_bytes" ending), 0)
            val () = equal ("snapshot live bytes", number (cell "marked_bytes" ending), 261888)
            val clock = number (cell "clock" ending)
            val () = need (clock >= 392832 andalso clock < 396928, "SATB completion outside slice grain")
        in expect events 1 "swept_bytes" 130944 end
      fun identity band =
        let val trace = generate "trace" ["--objects", "300000", "--sample", "4096", "--seed", "1", "--heap-size", "4194304"]
            fun compare (label, legacy, columns, args) =
              let val actual = row trace args
              in List.app (fn (index, name) => equal (label ^ " " ^ name, number (cell name actual), numeric (legacy, index))) columns end
            val () = compare ("copier", old trace ["--collector", "copier", "--band", band], [(20, "copied_major"), (27, "majors")],
                               ["--nursery", "0", "--old", "copy", "--band", band])
        in List.app (fn nursery =>
          (compare ("nursery", old trace ["--collector", "nursery", "--nursery", nursery, "--promote", "1", "--band", band],
                    [(20, "copied_total"), (21, "copied_minor"), (22, "copied_major"), (26, "minors"), (27, "majors")],
                    ["--nursery", nursery, "--old", "copy", "--minor-at-samples", "--full", "promote", "--big", "off", "--band", band]);
           compare ("sticky", old trace ["--collector", "sticky", "--nursery", nursery, "--band", band],
                    [(23, "surv_first"), (24, "marked_major"), (26, "minors"), (27, "majors")],
                    ["--old", "sticky-immix", "--nursery", nursery, "--line", "8", "--exact-lines", "--no-defrag", "--los", "off",
                     "--minor-at-samples", "--trigger-sim", "--band", band]))) ["256K", "1M"] end
    in case String.fields (fn c => c = #"/") which of
         ["alt32"] => alt32 () | ["alt128"] => alt128 () | ["line1"] => line1 () | ["minors"] => minors ()
       | ["satb"] => satb () | ["nursery", band, allocator] => nursery (band, allocator)
       | ["identity", band] => identity band | _ => raise Failed ("unknown gcsim case " ^ which) end
  val gcCases =
    [("h1", ["h1", "nursery=64K,256K", "pf=0,256", "reps=1"]),
     ("h2", ["h2", "live=32K,256K", "size=16,24,32,64,256", "reps=1"]),
     ("h3", ["h3", "heap=256K", "size=16,24,32,64", "live=0.1,0.5,0.9", "reps=1"]),
     ("h3-runs", ["h3", "heap=256K", "size=48", "live=0.5", "runs=1", "reps=1"]),
     ("alloc-test", ["alloc-test", "objects=20K", "rounds=5", "reserve=256M"]),
     ("h5", ["h5", "nursery=0,64K", "factor=2", "min=256K", "reserve=256M", "reps=1"]),
     ("h5-immix", ["h5", "nursery=64K", "alloc=immix", "line=64", "exact=1", "min=256K", "reserve=256M", "reps=1"]),
     ("h5-ops", ["h5", "reserve=256M"]),
     ("h6", ["h6", "nursery=256K", "old=16M", "reps=1", "n_inttable=20K", "n_impfor=50K", "n_lazyold=64K", "n_refcons=100K"]),
     ("h7", ["h7", "n=4K,16K", "reps=1"]),
     ("h8", ["h8", "frames=10,100", "locals=4,16,70", "rets=4,64", "funcs=1,16", "reps=1"]),
     ("h9", ["h9", "block=32K,256K", "touch=4M", "reps=1"]),
     ("h10", ["h10", "sizes=16K,256K,1M", "huge=both", "what=lat,latpg,bw", "reps=1"]),
     ("h2-tsc", ["h2", "live=32K", "size=32", "reps=1"])]
  fun gcTrace () =
    let val dir = directory "gcbench"
        val trace = dir ^ "/trace"
        val pending = trace ^ ".pending"
        val () = List.app rmTree [trace, pending]
        val () = ignore (commandIn (fn e => e) (root ^ "/tests/gcbench") dir "mktrace"
             [fromRoot "tests/out/gcbench/gcbench", "mktrace", "dir=" ^ pending, "objects=100K", "every=32K", "check=1"])
    in OS.FileSys.rename {old = pending, new = trace} end
  fun gcOps () =
    let val dir = directory "gcbench"
        val output = TextIO.openOut (dir ^ "/ops.txt")
        fun say s = TextIO.output (output, s ^ "\n")
        val () = say "# gcsim ops synthetic old=segfit size=W8"
        fun loop (6001, _) = ()
          | loop (i, state) =
            let val state = Real.rem (state * 1103515245.0 + 12345.0, 2147483648.0)
                val bytes = 16 + 8 * Real.floor (Real.rem (state, 40.0))
                val () = say ("a " ^ Int.toString i ^ " " ^ Int.toString bytes ^ " 0 " ^ (if i mod 500 = 0 then "4" else "3"))
                fun free j = if j > i then () else (say ("f " ^ Int.toString j); free (j + 2))
                val () = if i mod 1000 = 0 then free (i - 999) else ()
                val () = if i mod 1500 = 0 then say ("m " ^ Int.toString i ^ " 24 0 3") else ()
            in loop (i + 1, state) end
    in (loop (1, 7.0) before TextIO.closeOut output) handle e => (TextIO.closeOut output; raise e) end
  fun gcbench name =
    let val dir = directory ("gcbench/" ^ name)
        val args = case List.find (fn (n, _) => n = name) gcCases of SOME (_, args) => args | NONE => raise Failed "unknown gcbench case"
        val trace = if List.exists (fn n => n = name) ["h1", "h5", "h5-immix"] then ["trace=" ^ base ^ "/gcbench/trace"] else []
        val ops = if name = "h5-ops" then ["ops=" ^ base ^ "/gcbench/ops.txt", "majors=" ^ dir ^ "/majors.tsv"] else []
        val output = commandIn (if name = "h2-tsc" then setEnv ("GCB_EV", "none") else fn e => e)
                       (root ^ "/tests/gcbench") dir "check" ([fromRoot "tests/out/gcbench/gcbench"] @ args @ trace @ ops @ ["check=1"])
    in if name <> "h2-tsc" then () else
       need (List.exists (String.isSuffix "\ttsc") (lines output), "GCB_EV=none did not report tsc") end
  fun protect label f () = f () handle Failed message => say ("FAIL " ^ label ^ ": " ^ message ^ "\n")
                                    | TraceCheck.Invalid message => say ("FAIL " ^ label ^ ": " ^ message ^ "\n")
end
