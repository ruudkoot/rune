(* Static porting schedule. Reasons and pinned review identities are data;
   executable capability decisions are made here, without running a workload. *)
structure GenerateInventoryClassify =
struct
  open GenerateInventoryBase
  structure D=GenerateInventoryDiscover
  fun entryBody file =
    let val raw=T.replace (T.replace (binary file) "\r\n" "\n") "\r" "\n"
        val raw=T.prefix "(* Added val _ = Main.doit() at end of file -- mael 2001-10-19 *)\n" raw
        val stem=OS.Path.base (OS.Path.file file)
        val raw=if stem="kitlife35u_mlton" orelse stem="kitlife35u_smlnj" then
              T.substituteEnd "\\s*(val _ = \\(testit \\(\\); testit \\(\\); testit \\(\\)\\))?\\s*in\\s*val done = \"done\";\\s*(fun doit\\(\\) = \\(testit\\(\\); testit\\(\\); testit\\(\\)\\))?\\s*end\\s*$" (fn _ => "") raw else raw
        val raw=if stem="kitsimple_smlnj" then T.substituteEnd "structure Main\\s*=\\s*struct\\s*val doit = doit\\s*end\\s*$" (fn _ => "") raw else raw
    in trim (T.substituteEnd "\\s*(val\\s+_\\s*=\\s*(Main\\.)?doit\\s*\\(\\s*\\)\\s*;?|fun\\s+doit\\s*\\(\\s*\\)\\s*=\\s*Main\\.doit\\s*\\(\\s*\\))\\s*$" (fn _ => "") raw) end
  fun featureCode root path =
    let val code=haskellCode path
    in if relative root path="spectral/hartel/Fast2haskell.hs" andalso hash path="b94c6d53bd465be5b940bcbfec12c66c2ba971039072f91c0edb04558bea7596" then
         T.substitute "^\\s*import\\s+GHC\\.Prim\\s*;?" (fn _ => "") code else code end
  fun profiles directory =
    let val file=directory ^ "/Makefile"
        val raw=if regular file then readText file else ""
        val pattern=TerminalPattern.compile false "^(FAST_OPTS|NORM_OPTS|SLOW_OPTS)\\s*=\\s*[^\n]*$"
        fun loop i acc=case TerminalPattern.find pattern raw i of NONE => List.rev acc | SOME (a,b) =>
             let val matched=String.substring (raw,a,b-a) val (name,value)=valOf (T.splitAt "=" matched)
             in loop b ((trim name,trim value)::acc) end
    in loop 0 [] end
  fun classify source root (item:D.item) files code =
    let val path= #path item val name= !(#name item)
        val milestone=ref (case source of "mlton" => "M2" | "smlnj" => "M2" | "mlkit" => "M2" | "nofib" => "M3" | "sandmark" => "M5" | _ => raise Failed ("unknown source " ^ source))
        val disposition=ref "import" val reason=ref "portable workload; retain algorithm and review driver, numeric assumptions, fixtures and notices before import"
        fun choose kind why=(disposition:=kind;reason:=why)
        fun exclude why=(choose "exclude" why;milestone:="-")
        fun member value names=List.exists (fn name => name=value) names
        val cfg=review ()
        val ()=if source<>"mlkit" then () else
          let val stem=D.baseName name
              val candidate=String.isPrefix "kit" stem orelse member stem (strings "MLKIT_WORKLOADS") orelse (String.isPrefix "test_dev/" path andalso member stem (strings "MLKIT_DEV_WORKLOADS"))
              val ()=if candidate then () else exclude "regression or support source outside the benchmark families; test/all.tst and test_dev/Makefile distinguish compiler/Basis tests"
              val region=List.filter (fn name => T.matches ("(^|[^A-Za-z0-9_])" ^ name ^ "([^A-Za-z0-9_]|$)") code) ["resetRegions","forceResetting"]
              val noops=List.filter (fn name => T.matches ("(^|[^A-Za-z0-9_])fun\\s+" ^ name ^ "\\s+_\\s*=\\s*\\(\\s*\\)") code) region
              val ()=if !disposition<>"import" orelse null region then () else if List.all (fn name => member name noops) region then
                     reason:="portable upstream variant defines region-control functions as no-ops; preserve this distinct storage policy and its original algorithm"
                   else choose "defer" "calls ML Kit region-reset controls; removing these changes the measured storage policy; reconsider with equivalent region lifetime controls, and retain portable algorithm variants separately"
              val ()=case Json.member (path,field "MLKIT_REVIEW" cfg) of NONE => () | SOME v =>
                 (case List.map text (array v) of [kind,why] => (choose kind why;if kind="exclude" then milestone:="-" else ()) | _ => raise Failed "invalid MLKit review")
              val ()=if not (String.isPrefix "test/" path) then () else case Json.member (name,field "MLKIT_ENTRYPOINT_ALIASES" cfg) of NONE => () | SOME canonical =>
                 let val canonical=root ^ "/test/" ^ text canonical ^ ".sml"
                 in if regular canonical andalso entryBody (root ^ "/" ^ path)=entryBody canonical then choose "duplicate" ("same complete kernel and hardcoded parameters as " ^ relative root canonical ^ "; only the reviewed top-level invocation/export adapter differs; share that implementation and retain both provenance paths") else () end
          in if path="test_dev/kitsimple.sml" then choose "duplicate" "identical source and hardcoded workload to mlkit:test/kitsimple.sml; retain the test entry and both provenance paths" else () end
        val ()=if source<>"smlnj" then () else
              if member name ["BASIS","common"] then exclude "shared library/benchmark interface, not an independent workload"
              else case Json.member (name,field "BLOCKERS" cfg) of SOME why => choose "defer" (text why) | NONE =>
                    if member name ["cml-sieve","pingpong"] then choose "defer" "requires Concurrent ML message passing; reconsider when a compatible concurrency facility exists" else ()
        val ()=if source<>"nofib" then () else
          let val entry=root ^ "/" ^ path val makefile=OS.Path.dir entry ^ "/Makefile"
              val excluded=if regular entry andalso regular makefile then List.concat (List.mapPartial (fn line => if T.matches "^EXCLUDED_SRCS\\s*[:?+]?=" line then Option.map (String.tokens Char.isSpace o #2) (T.splitAt "=" line) else NONE) (lines (readText makefile))) else []
              val direct=List.filter (fn file => OS.Path.dir file=entry orelse file=entry) files
              val ()=if member (OS.Path.file path) excluded then exclude "upstream Makefile lists this test entrypoint in EXCLUDED_SRCS; retain the application entrypoint and record this support/correctness program separately"
                  else if not (List.exists (fn p => hasExt [".hs",".lhs"] p andalso D.isMain (haskellCode p)) direct) then exclude "aggregate, support directory, or old source fragment without a standalone Main entrypoint"
                  else if String.isPrefix "parallel/" path orelse String.isPrefix "smp/" path then choose "defer" "parallel/concurrent/STM collection; preserve its runtime model and reconsider with the corresponding Rune facilities"
                  else if String.isPrefix "real/" path then milestone:="M4" else ()
              val ()=if !disposition="import" andalso T.matches "^[ \t]*(foreign import|import\\s+(qualified\\s+)?(GHC\\.Prim|GHC\\.Conc|Control\\.Concurrent|Control\\.Parallel|System\\.Mem\\.Weak))" code then
                    choose "defer" "source imports runtime-specific primitives, concurrency, or weak references; audit a faithful portable replacement before reconsideration" else ()
              val ()=if member path ["gc/fulsom/Bah.hs","real/fulsom/Bah.hs","real/infer/TestTerm.hs","real/infer/TestType.hs","real/compress/BinTest.hs","real/compress/Lzw.hs","real/compress/Lzw2.hs","real/compress/Uncompress.hs"] then exclude "auxiliary test or alternate entrypoint; the directory Makefile excludes it or selects the Main driver, not a separate benchmark invocation" else ()
              val ()=if member path ["gc/fulsom/Main.hs","real/fulsom/Main.hs","real/compress/Main.hs","real/infer/Main.hs"] then #name item:=OS.Path.file (OS.Path.dir path) else ()
          in if path<>"spectral/constraints" orelse !disposition<>"import" then () else
               let val canonical=root ^ "/gc/constraints" val candidate=root ^ "/" ^ path
               in if regular (canonical ^ "/Main.hs") andalso regular (candidate ^ "/Main.hs") then
                    let val fixed=profiles canonical
                    in if length fixed=3 andalso sort (List.map #1 fixed)=["FAST_OPTS","NORM_OPTS","SLOW_OPTS"] andalso fixed=profiles candidate andalso binary (canonical ^ "/Main.hs")=binary (candidate ^ "/Main.hs") then
                         choose "duplicate" "complete program, all five CSP algorithms, 240 repetitions and fixed FAST/NORM/SLOW inputs match nofib:gc/constraints byte for byte; GC heap flags are measurement configurations; share one implementation and retain both source, fixture and runtime-setting provenances" else () end else () end end
        val ()=if source<>"sandmark" then () else
          let val group=if String.isPrefix "benchmarks/" path then List.nth (fields #"/" path,1) else "external"
              val ()=if member group (strings "SANDMARK_PACKAGES") orelse group="external" then choose "defer" ("requires the upstream application/package dependency graph (" ^ group ^ "); reconsider with a portable implementation of those dependencies")
                else if T.matches "(^|[^A-Za-z0-9_])(effect\\s+[A-Z]|Effect\\.(Deep|Shallow|perform)|perform\\s+|Domain\\.(spawn|join)|Domainslib|Thread\\.|Lwt[._]|Weak\\.|Ephemeron\\.|Gc\\.(finalise|full_major|major|minor|compact|major_slice)|Gc\\.get|Gc\\.set|Obj\\.|Ms_sched\\.|external\\s+[A-Za-z0-9_]+\\s*:|Unix\\.(fork|wait|create_process)|foreign_stubs|[Oo]camlcapi)" code then
                    choose "defer" "source uses OCaml-specific effects, concurrency, GC/weak-reference introspection, unsafe objects or C bindings; reconsider with equivalent runtime facilities"
                else if List.exists (fn s => String.isSubstring s name) ["multicore","parallel","multiprocess"] orelse member group ["mpl","multicore-gcroots","multicore-structures","multicore-grammatrix"] then choose "defer" "parallel/runtime-specific executable; retain its original execution model" else ()
              val bigarray=root ^ "/benchmarks/stdlib/big_array_bench.ml"
              val ()=if !disposition="import" andalso path="benchmarks/stdlib/big_array_bench.exe" andalso regular bigarray andalso hash bigarray="4df8ddc28ddc4fd81ad2db5938003b1857791b6e8c74e68a1559dfd043ffa0d6" then
                   choose "defer" "both pinned modes benchmark Bigarray int/int32 C-layout storage; ordinary managed SML arrays change the measured storage policy; reconsider with equivalent typed C-layout storage, without adding runtime facilities through this benchmark roadmap" else ()
              val ()=if !disposition<>"import" then () else case Json.member (path,field "OPAQUE_PROBES" cfg) of NONE => () | SOME value =>
                   let val parts=List.map text (array value) val file=root ^ "/" ^ String.substring (path,0,size path-4) ^ ".ml"
                   in if regular file andalso hash file=hd parts then choose "defer" ("pinned " ^ List.nth (parts,1) ^ "; portable SML97 has no equivalent optimization barrier; reconsider with a reviewed portable barrier protocol or observable upstream workload, without adding prerequisite compiler/runtime features through this roadmap") else () end
          in if !disposition="import" andalso member path ["benchmarks/multicore-effects/rec_seq_fib.exe","benchmarks/multicore-effects/rec_seq_tak.exe"] then
               reason:="reviewed strict recurrence matches the classic " ^ (if name="rec_seq_fib" then "fib" else "tak") ^ " kernel; share one SML implementation and retain both provenances; keep this established executable name and its original input/repetition profiles, which differ from the classic launcher; document OCaml operand evaluation order and consumed repetition results" else () end
        val ()=if (source="mlton" andalso name="tak") orelse (source="mlkit" andalso path="test/kittmergesort.sml") orelse (source="nofib" andalso path="imaginary/primes") orelse (source="sandmark" andalso path="benchmarks/bdd/bdd.exe") then milestone:="M1" else ()
        val ()=if source="nofib" andalso path="spectral/dom-lt" andalso !disposition="import" then
             let val file=root ^ "/spectral/dom-lt/Dom.hs"
             in if regular file andalso hash file="ae7675a60f6915fee3f62c6e329b696e7f7a24324fc1cfac98fcaa1eff9094a1" then reason:="portable with reviewed semidominator-minimum repair; pinned source reuses a stale threshold and returns incorrect parents on supplied graphs; preserve original checksums while validating all corrected parents against independent results" else () end else ()
    in (!milestone,!disposition,!reason) end
end
