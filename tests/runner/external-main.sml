structure ExternalMain =
struct
  open Sh
  exception Usage of string
  fun need (ok,why) = if ok then () else raise Usage why
  fun command args = case args of
      ["--worker","regression",name] => SOME (ExternalChecks.regression name)
    | ["--worker","benchmark",name] => SOME (ExternalChecks.benchmark name)
    | ["--worker","prepare"] => SOME ExternalChecks.prepareData
    | ["--worker","probe",file] => SOME (ExternalChecks.probe file)
    | _ => NONE
  fun selected names =
    let val filters = String.fields (fn c => c = #"\n") (ExternalChecks.setting "FILTERS" "")
        val one = ExternalChecks.setting "ONE" ""
    in List.filter (fn name => (one = "" orelse one = name) andalso List.exists (fn filter => String.isSubstring filter name) filters) names end
  fun judge (result,files) = case Run.exitZero (result,files) of SOME bad => SOME bad | NONE =>
    let val text = read (#stdout files)
        val line = firstNonEmpty (#stdout files)
    in if String.isPrefix "PASS " line orelse String.isPrefix "PREPARED " line then NONE
       else if String.isPrefix "SKIP " line then SOME ("SKIP",line)
       else if String.isPrefix "COUNT " line andalso ExternalChecks.setting "UPDATE" "0" = "1" then NONE
       else SOME ("FAIL",text) end
  fun job name args after judge = Test.it name {program = fromRoot "bin/rune-external", args = "rune-external" :: args,
       env = NONE, dir = SOME root, stdin = NONE, timeout = Time.fromSeconds 1800, cap = 0, cpus = 1, memory = 1500,
       pools = [], exclusive = false, after = after, judge = judge} : Run.command Test.tree
  fun update names =
    let fun line text = case String.tokens Char.isSpace text of [] => text | name :: n :: _ =>
          if String.isPrefix "#" name orelse not (List.exists (fn x => x = name) names) then text else
          let val count = Hosts.trim (read (ExternalChecks.output () ^ "/" ^ name ^ ".count"))
              val pieces = String.fields (fn c => c = #"#") text
              val note = if length pieces > 1 then " # " ^ Hosts.trim (String.concatWith "#" (tl pieces)) else ""
          in if count = "" then text else name ^ " " ^ n ^ " " ^ count ^ note end
        | _ => text
        val file = ExternalChecks.table ()
        val text = String.concatWith "\n" (List.map line (String.fields (fn c => c = #"\n") (read file)))
        val temporary = file ^ ".new-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
    in write (temporary,text); OS.FileSys.rename {old=temporary,new=file}; say ("mlton-bench: " ^ file ^ " updated\n") end
  fun run () =
    let val suite = ExternalChecks.setting "SUITE" "regression"
        val dir = ExternalChecks.directory ()
        val () = need (isDir dir, "missing external corpus directory " ^ dir)
        val () = need (OS.FileSys.access (ExternalChecks.compiler (), [OS.FileSys.A_EXEC]), "compiler is unavailable")
        val cpus = ExternalChecks.integer "JOBS" "4"
        val sourceDirs = String.fields (fn c => c = #"\n") (ExternalChecks.setting "DIRS" dir)
        val () = List.app (fn dir => need (isDir dir,"missing external corpus directory " ^ dir)) sourceDirs
        val names = if suite = "regression" then selected (List.map basename (List.filter (fn path => exists (OS.Path.base path ^ ".ok")) (glob (dir,".sml"))))
                    else if suite = "benchmark" then selected (List.map #name (ExternalChecks.rows ()))
                    else List.concat (List.map (fn dir => List.filter (String.isSuffix ".sml") (Incremental.entriesBelow dir))
                           sourceDirs)
        val () = need (not (null names), "no external program matches selection")
        val () = List.app (fn name => rmTree (ExternalChecks.output () ^ "/" ^ name ^ ".result"))
                         (if suite = "probe" then [] else names)
        val prepare = if suite = "benchmark" then [job "prepare" ["--worker","prepare"] [] Run.exitZero] else []
        val jobs = List.map (fn name => job (if suite = "probe" then CachePlant.contentHash name else name)
                      (["--worker",suite,name]) (if suite = "benchmark" then ["external/prepare"] else [])
                      (if suite = "probe" then Run.exitZero else judge)) names
        val tests = Test.leaves (Test.describe "external" (prepare @ jobs))
        val ok = Run.run {tests=List.map (fn {path,meta,leaf} => (path,meta,leaf)) tests, root=root,
                 out=ExternalChecks.output () ^ "/receipts", history=fromRoot "build/external-history.tsv", cpus=cpus,
                 memory=Int.max (4000,cpus*1500), keep=false, reader=Report.reader (), capabilities=[], strict=true, quarantine=[]}
        val () = if suite <> "probe" then () else
          let val rows = List.map (fn file => read (ExternalChecks.output () ^ "/probe-" ^ CachePlant.contentHash file ^ ".result")) names
              val () = write (ExternalChecks.output () ^ "/host-basis.tsv",String.concat rows)
              val () = if ExternalChecks.setting "LIST" "0" = "1" then List.app (fn row =>
                  say (String.concatWith "\t" (List.take (String.fields (fn c => c = #"\t") row,2)) ^ "\n")) rows else ()
              val () = say ("probe-host-basis: " ^ Int.toString (length rows) ^ " files\n")
          in List.app (fn category => let val count = length (List.filter (String.isPrefix (category ^ "\t")) rows)
                 in if count = 0 then () else say ("  " ^ category ^ " " ^ Int.toString count ^ "\n") end) ["ok","unbound","fixity","syntax","other"] end
        val () = if suite = "probe" then () else List.app (fn name => say (read (ExternalChecks.output () ^ "/" ^ name ^ ".result"))) names
        val () = if suite = "benchmark" andalso ExternalChecks.setting "UPDATE" "0" = "1" then update names else ()
    in if ok then () else Posix.Process.exit 0w1 end
  fun options suite args =
    let val changes = ref [("EXTERNAL_SUITE",suite)]
        val filters = ref []
        fun set name value = changes := ("EXTERNAL_" ^ name,value) :: !changes
        fun parse [] = ()
          | parse ("--dir" :: value :: rest) = (set "DIR" (fromRoot value); parse rest)
          | parse ("--out" :: value :: rest) = (set "OUT" (fromRoot value); parse rest)
          | parse ("--rune" :: value :: rest) = (set "RUNE" (fromRoot value); parse rest)
          | parse ("--vm" :: value :: rest) = (set "VM" (fromRoot value); parse rest)
          | parse ("--vm-opts" :: value :: rest) = (set "VM_OPTS" value; parse rest)
          | parse ("--timeout" :: value :: rest) = (set "TIMEOUT" value; parse rest)
          | parse ("--table" :: value :: rest) = (set "TABLE" (fromRoot value); parse rest)
          | parse ("-j" :: value :: rest) = (set "JOBS" value; parse rest)
          | parse ("--one" :: value :: rest) = (set "ONE" value; parse rest)
          | parse ("--all" :: rest) = (set "ALL" "1"; parse rest)
          | parse ("--update" :: rest) = (set "UPDATE" "1"; parse rest)
          | parse ("--prepare" :: rest) = (set "PREPARE" "1"; parse rest)
          | parse ("--list" :: rest) = (set "LIST" "1"; parse rest)
          | parse (arg :: rest) = if String.isPrefix "-" arg then raise Usage ("unknown or incomplete option " ^ arg)
               else if suite = "benchmark" then (filters := !filters @ [arg]; parse rest) else (if suite = "probe" then filters := !filters @ [fromRoot arg] else (); set "DIR" (fromRoot arg); parse rest)
        val () = parse args
        val () = if suite = "probe" andalso not (null (!filters)) then (set "DIRS" (String.concatWith "\n" (!filters)); filters := []) else ()
        val defaults = [("EXTERNAL_DIR",if suite = "benchmark" then env ("MLTON_BENCH","/home/ruud/reference/mlton/benchmark/tests") else ""),
                        ("EXTERNAL_JOBS",Int.toString (Runtime.processors ()))]
        val environment = List.foldr (fn ((key,value),e) => setEnv (key,value) e)
                     (List.foldl (fn ((key,value),e) => setEnv (key,value) e) (Posix.ProcEnv.environ ()) defaults)
                     (("EXTERNAL_FILTERS",String.concatWith "\n" (!filters)) :: !changes)
        val vm = fromRoot "bin/runevm"
    in Posix.Process.exece (vm,[vm,fromRoot "bin/rune-external.rbc","--run"],environment) end
  fun main ["--run"] = run ()
    | main (suite :: args) = if List.exists (fn x => x = suite) ["regression","benchmark","probe"] then options suite args
                            else raise Usage "regression DIR | benchmark [OPTIONS] | probe DIR"
    | main [] = raise Usage "regression DIR | benchmark [OPTIONS] | probe DIR"
end
val () = ((case ExternalMain.command (CommandLine.arguments ()) of SOME action => action ()
           | NONE => ExternalMain.main (CommandLine.arguments ())) handle e =>
    (Sh.say ("FAIL external controller: " ^ (case e of ExternalMain.Usage text => text | ExternalChecks.Failed text => text | _ => General.exnMessage e) ^ "\n"); Posix.Process.exit 0w2))
