(* Catalogue correctness jobs reuse the production catalogue's SML model.
   Source order, arguments, full expected state and runtime data stay typed. *)
structure BenchmarkRun =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun atRoot f =
    let val prior = OS.FileSys.getDir ()
        val () = OS.FileSys.chDir root
    in (f () before OS.FileSys.chDir prior) handle e => (OS.FileSys.chDir prior; raise e) end
  fun entries () = atRoot (fn () => BenchCatalog.load "examples/benchmarks/manifest.tsv")
  fun selected routine profile filter = atRoot (fn () =>
    let val rows = entries ()
        val rows = if routine then BenchCatalog.routine rows else rows
    in BenchCatalog.selected rows (if routine then "smoke" else profile) filter end)
  fun entry name profile = case selected false profile ("=" ^ name) of [entry] => entry
                         | _ => raise Failed ("missing or duplicate catalogue case " ^ name ^ "/" ^ profile)
  fun baseFiles (r : BenchCatalog.entry) =
    (List.map (fn path => fromRoot ("examples/benchmarks/" ^ path)) (#sources r),
     List.map (fn path => (fromRoot ("examples/benchmarks/" ^ #name r ^ "/" ^ path), path)) (#inputFiles r))
  fun runEntry (r : BenchCatalog.entry) config dir dataOverride =
    let val () = mkdirs dir
        val (sources, data) = baseFiles r
        val input = dir ^ "/input"
        val expected = fromRoot ("examples/benchmarks/" ^ #expected r)
        val () = need (exists expected, "missing catalogue expected result")
        val () = write (input, #name r ^ "\n" ^ String.concatWith " " (#args r) ^ "\n" ^ read expected)
        val data = case dataOverride of NONE => data | SOME data => data
    in MatrixProgram.run {config = config, directory = dir, sources = sources, input = input, data = data,
                          timeout = #seconds r, memoryKiB = #memory r} end
  fun one name profile spec () =
    let val r = entry name profile
        val () = atRoot (fn () => BenchCatalog.validate (entries ()))
        val dir = run ^ "/benchmark-catalogue/" ^ profile ^ "/" ^ name ^ "/" ^ MatrixSuite.path spec
        val () = mkdirs dir
        val config = MatrixModel.resolve {timing = false, directory = dir ^ "/resolve"} spec
    in runEntry r config dir NONE end
  fun alteredState text =
    let val rows = String.fields (fn c => c = #"\n") text
        val () = need (length rows >= 2, "complete state fixture has no state row")
        val values = String.tokens Char.isSpace (List.nth (rows, 1))
        val () = need (not (null values), "complete state fixture has no values")
        val value = case Real.fromString (hd values) of SOME value => value | NONE => raise Failed "invalid complete state value"
        val changed = Real.toString (value + 1.0) :: tl values
    in String.concatWith "\n" (hd rows :: String.concatWith " " changed :: List.drop (rows, 2)) end
  fun state name () =
    let val r = entry name "smoke"
        val reference = case List.rev (#args r) of path :: _ => path | _ => raise Failed "state benchmark has no reference argument"
        val () = need (BenchCases.relative reference, "invalid state reference path")
        val dir = run ^ "/benchmark-state/" ^ name
        val () = mkdirs (dir ^ "/fixture/" ^ OS.Path.dir reference)
        val source = fromRoot ("examples/benchmarks/" ^ name ^ "/" ^ reference)
        val fixture = dir ^ "/fixture/" ^ reference
        val () = need (exists source, "state benchmark has no complete state fixture")
        val () = write (fixture, alteredState (read source))
        val config = MatrixModel.resolve {timing = false, directory = dir ^ "/resolve"} "rune"
        val (sources, _) = baseFiles r
        val input = dir ^ "/input"
        val () = write (input, name ^ "\n" ^ String.concatWith " " (#args r) ^ "\n"
                          ^ read (fromRoot ("examples/benchmarks/" ^ #expected r)))
        val ctx : MatrixLoad.context = {config = config, directory = dir, prefix = [], image = MatrixLoad.NoImage,
             standalone = true, input = input, data = [(fixture, reference)], timeout = 120, memoryKiB = 1048576}
        val result = MatrixLoad.load ctx (dir ^ "/program") MatrixLoad.Run sources
        val output = #output result
    in need (#loaded result andalso #status result = 1 andalso String.isSubstring ("FAIL " ^ name ^ " -- Fail: hydrodynamic state") output
                     andalso String.isSubstring "SUMMARY 1 checks, 1 failed" output,
             "benchmark accepted perturbed complete state: " ^ name);
       say ("PASS " ^ name ^ " rejects perturbed full state\n") end
  fun stageState name () =
    let val vm = fromRoot "bin/runevm"
        val payload = fromRoot (env ("RUNE_BENCH_PAYLOAD", "bin/rune-bench-check.rbc"))
        val environment = setEnv ("RUNE_BENCH_COMPILE_OPTIONS", "-O2") (Posix.ProcEnv.environ ())
    in Posix.Process.exece (vm, [vm, payload, "bench-state-exec", name], environment) end
  fun protect f () = f () handle e => (say ("FAIL catalogue benchmark: " ^ General.exnMessage e ^ "\n"); Posix.Process.exit 0w1)
  fun command ["bench-catalogue-case", name, profile, spec] = SOME (protect (one name profile spec))
    | command ["bench-state", name] = SOME (protect (stageState name))
    | command ["bench-state-exec", name] = SOME (protect (state name))
    | command ["bench-catalogue-validate"] = SOME (protect (fn () => atRoot (fn () => BenchCatalog.validate (entries ()))))
    | command _ = NONE
end
