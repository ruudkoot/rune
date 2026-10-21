(* External corpus controller. Source trees are inputs, kept outside Rune;
   skip policy, limits, exception normalization and count verdicts are SML. *)
structure ExternalChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok, message) = if ok then () else raise Failed message
  fun setting name fallback = env ("EXTERNAL_" ^ name, fallback)
  fun directory () = fromRoot (setting "DIR" "")
  fun output () = fromRoot (setting "OUT" (if setting "SUITE" "regression" = "benchmark" then "tests/out/mlton-bench" else "tests/out/external"))
  fun integer key fallback = case Int.fromString (setting key fallback) of SOME n =>
       (need (n > 0, "invalid external " ^ key); n) | NONE => raise Failed ("invalid external " ^ key)
  fun invoke name cwd stdin cmd timeout =
    let val dir = output ()
        val () = mkdirs dir
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME timeout,
                                    fileSize = SOME (1024*1024*1024), core = SOME 0} (unsetEnv ["FORCE_COLOR","CLICOLOR_FORCE"])
          {cmd = cmd, dir = SOME cwd, stdin = stdin, stdout = dir ^ "/" ^ name ^ ".stdout",
           stderr = dir ^ "/" ^ name ^ ".stderr", timeout = timeout}
    in {status = status, output = read (dir ^ "/" ^ name ^ ".stdout"), errors = read (dir ^ "/" ^ name ^ ".stderr")} : Scenarios.result end
  fun compiler () = fromRoot (setting "RUNE" (if setting "SUITE" "regression" = "regression" then "bin/rune-stack" else "bin/rune"))
  fun vm () = fromRoot (setting "VM" (if setting "SUITE" "regression" = "regression" then "bin/runevm-stack" else "bin/runevm"))
  fun publish name verdict = (write (output () ^ "/" ^ name ^ ".result", verdict ^ "\n"); say (verdict ^ "\n"))
  fun skip name = case List.find (fn row : Expectations.line => Expectations.glob (#path row,name))
                                  (Expectations.read (fromRoot "tests/external/mlton-skip.txt")) of
                    SOME row => SOME (#category row ^ ": " ^ #reason row) | NONE => NONE
  fun regression name () =
    let val dir = directory ()
        val out = output ()
        fun run () =
          let val source = dir ^ "/" ^ name ^ ".sml"
              val expected = dir ^ "/" ^ name ^ ".ok"
              val () = need (exists source andalso exists expected, "missing regression source or expected output: " ^ name)
              val () = rmTree (out ^ "/" ^ name ^ ".rbc")
              val compile = invoke (name ^ ".compile") root "" [compiler (), "--no-warnings", source, "-o", out ^ "/" ^ name ^ ".rbc"] 600
          in if #status compile = 124 then "TIMEOUT " ^ name ^ ": compiler"
             else if #status compile <> 0 then "COMPILE " ^ name ^ ": " ^ (case lines (#errors compile) of line :: _ => line | [] => "compiler failed")
             else
               let val scratch = out ^ "/" ^ name ^ ".dir"
                   val () = rmTree scratch
                   val () = mkdirs scratch
                   val result = invoke name scratch "" [vm (), out ^ "/" ^ name ^ ".rbc"] 20
                   val exceptionText = String.concat (List.mapPartial (fn line => if String.isPrefix "runevm: uncaught exception " line
                                 then SOME ("unhandled exception: " ^ String.extract (line,size "runevm: uncaught exception ",NONE) ^ "\n") else NONE) (lines (#errors result)))
                   val normalized = #output result ^ (if #status result = 0 then "" else exceptionText ^ "Nonzero exit status.\n")
                   val () = write (out ^ "/" ^ name ^ ".stdout", normalized)
               in if #status result = 124 then "TIMEOUT " ^ name
                  else if normalized = read expected then "PASS " ^ name
                  else if #status result <> 0 then "RUNTIME " ^ name ^ ": " ^ #errors result else "OUTPUT " ^ name end
          end
    in mkdirs out; publish name (case skip name of SOME why => "SKIP " ^ name ^ ": " ^ why | NONE => run ()) end
  fun table () = fromRoot (setting "TABLE" "tests/perf/mlton-bench.txt")
  type row = {name : string, n : string, bytes : string, objects : string, note : string}
  fun rows () = List.mapPartial (fn line =>
       let val pieces = String.fields (fn c => c = #"#") line
           val text = hd pieces
           val note = if length pieces > 1 then String.concatWith "#" (tl pieces) else ""
       in case String.tokens Char.isSpace text of [] => NONE
        | [name,n,bytes,objects] => SOME {name=name,n=n,bytes=bytes,objects=objects,note=Hosts.trim note}
        | _ => raise Failed ("malformed external benchmark table: " ^ line) end) (String.fields (fn c => c = #"\n") (read (table ())))
  fun row name = case List.find (fn r : row => #name r = name) (rows ()) of SOME row => row | NONE => raise Failed ("unknown external benchmark " ^ name)
  fun prepareData () =
    let val dir = directory ()
        val out = output ()
        val () = need (isDir dir, "missing external corpus directory " ^ dir)
        val () = mkdirs out
        val () = if isDir (out ^ "/DATA") then () else
                       (need (isDir (dir ^ "/DATA"), "missing external corpus DATA directory"); Incremental.copyTree (dir ^ "/DATA") (out ^ "/DATA"))
        val () = if exists (out ^ "/fxp-input.xml") andalso OS.FileSys.fileSize (out ^ "/fxp-input.xml") > 0 then () else
          let val input = invoke "fxp-input" root "" ["sh", fromRoot "tests/external/mlton-bench/gen-fxp-input.sh"] 30
          in need (#status input = 0 andalso #output input <> "", "external input producer failed");
             write (out ^ "/fxp-input.xml", #output input) end
    in () end
  fun prepareSource name n =
    let val shims = fromRoot "tests/external/mlton-bench"
        val sourceName = if exists (shims ^ "/" ^ name ^ ".from") then Hosts.trim (read (shims ^ "/" ^ name ^ ".from")) else name
        val file = directory () ^ "/" ^ sourceName ^ ".sml"
        val () = need (exists file, "missing external benchmark source " ^ file)
        val source = if exists (shims ^ "/" ^ name ^ ".sed") then
           let val result = invoke (name ^ ".transform") root "" ["sed", "-f", shims ^ "/" ^ name ^ ".sed", file] 30
           in need (#status result = 0, "external source transformation failed"); #output result end else read file
        val wrapped = read (shims ^ "/" ^ name ^ ".shim.sml") ^ source
                      ^ (if exists (shims ^ "/" ^ name ^ ".nowrap") then "" else "\nval _ = Main.doit " ^ n ^ "\n")
        val path = output () ^ "/" ^ name ^ ".sml"
        val () = write (path,wrapped)
        val () = if exists (shims ^ "/" ^ name ^ ".args") then Incremental.copy (shims ^ "/" ^ name ^ ".args") (output () ^ "/" ^ name ^ ".args") else ()
    in path end
  fun count text =
    let fun line text = case String.tokens (fn c => Char.isSpace c orelse c = #",") text of
           ["runevm:","count:",instructions,"instructions",bytes,"bytes",objects,"objects"] =>
             if List.all (fn n => n <> "" andalso CharVector.all Char.isDigit n) [instructions,bytes,objects] then SOME (bytes ^ " " ^ objects) else NONE
         | _ => NONE
    in case List.mapPartial line (lines text) of [] => NONE | xs => SOME (List.last xs) end
  fun benchmark name () =
    let val r = row name
        val out = output ()
        val () = mkdirs out
        val () = rmTree (out ^ "/" ^ name ^ ".count")
        val large = case IntInf.fromString (#bytes r) of SOME n => n > 2000000000 | NONE => false
        fun run () =
          let val source = prepareSource name (#n r)
              val () = rmTree (out ^ "/" ^ name ^ ".rbc")
              val compile = invoke (name ^ ".compile") root "" [compiler (), source, "-o", out ^ "/" ^ name ^ ".rbc"] 600
          in if #status compile <> 0 then "COMPILE " ^ name ^ ": " ^ (case lines (#errors compile) of line :: _ => line | [] => "compiler failed")
             else if setting "PREPARE" "0" = "1" then "PREPARED " ^ name else
               let val result = invoke name out "" ([vm (), "--count"] @ String.tokens Char.isSpace (setting "VM_OPTS" "")
                        @ [name ^ ".rbc"] @ words (out ^ "/" ^ name ^ ".args")) (integer "TIMEOUT" "600")
               in if #status result = 124 then "TIMEOUT " ^ name ^ ": " ^ setting "TIMEOUT" "600" ^ " s"
                  else case count (#errors result) of SOME counts =>
                     if #status result <> 0 then "RUNTIME " ^ name ^ ": exit " ^ Int.toString (#status result) else
                     (write (out ^ "/" ^ name ^ ".count", counts ^ "\n");
                      if counts = #bytes r ^ " " ^ #objects r then "PASS " ^ name ^ ": " ^ counts
                      else "COUNT " ^ name ^ ": " ^ counts ^ ", where " ^ table () ^ " says " ^ #bytes r ^ " " ^ #objects r)
                   | NONE => "RUNTIME " ^ name ^ ": exit " ^ Int.toString (#status result) ^ ": no allocation counters"
               end
          end
    in publish name (if #n r = "-" then "SKIP " ^ name ^ ": " ^ #note r
                       else if large andalso setting "ALL" "0" <> "1" then "SKIP " ^ name ^ ": " ^ #bytes r ^ " bytes; --all runs it" else run ()) end
  fun probe file () =
    let val result = invoke ("host-basis-" ^ CachePlant.contentHash file) root "" [compiler (), "--no-prelude", "--typecheck-only", "--allow-prim", file] 120
        val message = case lines (#output result ^ #errors result) of line :: _ => line | [] => ""
        val () = need (#status result <> 124, "host Basis probe timed out: " ^ file)
        val () = need (message <> "" orelse #status result = 0, "host Basis compiler failed without a diagnostic: " ^ file)
        val category = if message = "" then "ok" else if String.isSubstring "unbound" message then "unbound"
          else if String.isSubstring "infix" message then "fixity"
          else if List.exists (fn word => String.isSubstring word message) ["expected","unexpected","illegal","unterminated"] then "syntax" else "other"
    in publish ("probe-" ^ CachePlant.contentHash file) (category ^ "\t" ^ file ^ "\t" ^ message) end
end
