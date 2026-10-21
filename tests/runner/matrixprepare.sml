(* Library producers for cross configurations. Consumers depend on a producer
   job and read its published status; there is no success-marker polling. *)
structure MatrixPrepare =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun atomic (file, text) =
    let val tmp = file ^ "." ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())) ^ ".tmp"
    in write (tmp, text); OS.FileSys.rename {old = tmp, new = file} end
  fun treeFiles path = if OS.Path.file path = "MLB" then [] else if OS.FileSys.isLink path andalso isDir path then [] else if isDir path then
        List.concat (List.map (fn name => treeFiles (path ^ "/" ^ name)) (sort (entries path))) else [path]
  fun key (config : MatrixModel.config) =
    let val sourceFiles = glob (fromRoot "lib/basis", ".sml") @ [fromRoot "lib/basis/MANIFEST", fromRoot "runtime/prims.def"]
        val generator = List.filter exists [fromRoot "bin/rune-generate", fromRoot "bin/rune-generate.rbc"]
        val generatorData = treeFiles (fromRoot "tools/generate/data")
        val helpers = List.filter (fn path => not (String.isSubstring "/MLB/" path))
                         (treeFiles (fromRoot "tests/basis/host") @ treeFiles (fromRoot "tests/basis/xc2"))
        val tools = [OS.FileSys.realPath (#command config)]
        val rune = case #compiler config of MatrixModel.Host _ => [] | _ =>
              List.filter exists [fromRoot "bin/rune.rbc", fromRoot "bin/rune.stack.rbc"]
        val engines = case #compiler config of MatrixModel.Host _ => [] | _ =>
              List.filter exists [OS.FileSys.realPath (#vm config), fromRoot "bin/runevm-native.rbc", fromRoot "build/librune.a"]
        val controller = List.map fromRoot ["tests/runner/matrixmodel.sml", "tests/runner/matrixprobe.sml",
                 "tests/runner/matrixload.sml", "tests/runner/matrixprepare.sml", "tests/runner/matrixsuite.sml"]
    in "matrix-controller-2:" ^ MatrixLoad.hash (sourceFiles @ helpers @ generator @ generatorData @ tools @ rune @ engines @ controller)
          ^ ":" ^ #id config ^ ":" ^ #extra config end
  fun context config directory prefix image : MatrixLoad.context =
    {config = config, directory = directory, prefix = prefix, image = image, standalone = false, input = "", data = [],
     timeout = getOpt (Int.fromString (env ("RUNE_MATRIX_TIMEOUT", "120")), 120),
     memoryKiB = getOpt (Int.fromString (env ("RUNE_MATRIX_MEMORY", "4194304")), 4194304)}
  fun run ctx dir label command timeout =
    let val log = dir ^ "/" ^ label ^ ".log"
        val status = MatrixLoad.execute ctx dir {args = command, input = "", output = log, errors = log, timeout = timeout}
    in (status, read log) end
  fun firstError text = HostLaws.firstError text
  fun error (Failed text)=text | error (MatrixLoad.Failed text)=text
    | error (MatrixModel.Invalid text)=text | error e=General.exnMessage e
  fun discardImage dir =
    List.app MatrixLoad.remove (List.map (fn name => dir ^ "/" ^ name)
       (List.filter (fn name => String.isPrefix "basis.heap." name orelse name = "basis.image" orelse name = "basis.state") (entries dir)))
  fun image config dir =
    if not (exists (dir ^ "/basis.image")) then MatrixLoad.NoImage else
      let val name = MatrixLoad.host config
      in if name = "polyml" then (need (exists (dir ^ "/basis.state"), "saved Poly/ML state is missing"); MatrixLoad.PolyImage (dir ^ "/basis.state"))
         else (need (List.exists (String.isPrefix "basis.heap.") (entries dir), "saved SML/NJ heap image is missing");
               MatrixLoad.NJImage (dir ^ "/basis.heap")) end
  fun saveImage (ctx : MatrixLoad.context) files =
    let val config = #config ctx
        val dir = #directory ctx
        val name = MatrixLoad.host config
        val () = discardImage dir
        val source = dir ^ "/basis.export.sml"
        val use = "val () = (" ^ String.concatWith "; " (List.map (fn path => "use \"" ^ String.toString path ^ "\"") files) ^ ");\n"
        val output = if name = "polyml" then "val () = PolyML.SaveState.saveState \"" ^ String.toString (dir ^ "/basis.state")
                       ^ "\";\nval () = OS.Process.exit OS.Process.success;\n"
          else "val () = if SMLofNJ.exportML \"" ^ String.toString (dir ^ "/basis.heap") ^ "\" then\n"
              ^ "  ((use \"driver.sml\" handle e => (print (\"uncaught exception \" ^ exnName e ^ \" [\" ^ exnMessage e ^ \"]\\n\");\n"
              ^ "      OS.Process.exit OS.Process.failure)); OS.Process.exit OS.Process.success)\n"
              ^ "  else OS.Process.exit OS.Process.success;\n"
    in if env ("RUNE_MATRIX_NO_IMAGE", "0") <> "0" orelse not (name = "polyml" orelse String.isPrefix "smlnj" name) then () else
       let val () = write (source, use ^ output)
           val args = [#command config] @ (if name = "polyml" then ["-q", "--error-exit", "--use", source] else [source])
           val (status, _) = run ctx dir "basis.export" args (#timeout ctx * 8)
           val present = if name = "polyml" then exists (dir ^ "/basis.state")
                         else List.exists (String.isPrefix "basis.heap.") (entries dir)
       in if status = 0 andalso present then atomic (dir ^ "/basis.image", "ok\n") else discardImage dir end end
  fun sessionProbe ctx prelude files =
    let val dir = #directory ctx ^ "/basis.probe"
        val () = MatrixLoad.remove dir
        val () = mkdirs dir
        val source = dir ^ "/probe.sml"
        fun use path = "val () = use \"" ^ String.toString path ^ "\";\n"
        val body = String.concat (List.map use prelude)
          ^ "val probeSay__ = fn s__ => (TextIO.print s__; TextIO.flushOut TextIO.stdOut);\nval probeWhy__ = General.exnMessage;\n"
          ^ String.concat (List.map (fn path => "val () = probeSay__ \"@@FILE " ^ String.toString path ^ "\\n\";\n"
              ^ "val () = (use \"" ^ String.toString path ^ "\"; probeSay__ \"@@OK\\n\")\n"
              ^ "  handle probe__ => probeSay__ (String.concat [\"@@DROP \", probeWhy__ probe__, \"\\n\"]);\n") files)
          ^ "val () = probeSay__ \"@@END\\n\";\n"
        val () = write (source, body)
        val config = #config ctx
        val args = [#command config] @ (if MatrixLoad.host config = "polyml" then ["-q", "--use", source] else [source])
        val (_, output) = run ctx dir "probe" args (#timeout ctx * 8)
        fun parse ([], _, _, accepted, dropped) = (List.rev accepted, List.rev dropped)
          | parse (line :: rest, file, why, accepted, dropped) =
            if String.isPrefix "@@FILE " line then parse (rest, SOME (String.extract (line, 7, NONE)), "", accepted, dropped)
            else if String.isPrefix "@@OK" line then
              (case file of NONE => raise Failed "library probe has an unpaired OK marker"
               | SOME file => parse (rest, NONE, "", file :: accepted, dropped))
            else if String.isPrefix "@@DROP " line then
              (case file of NONE => raise Failed "library probe has an unpaired DROP marker"
               | SOME file => parse (rest, NONE, "", accepted, (OS.Path.file file, if why = "" then String.extract (line, 7, NONE) else why) :: dropped))
            else parse (rest, file, if why <> "" then why else
                    case file of SOME file => if MatrixProbe.sessionError (MatrixLoad.host config) [file] line then firstError line else ""
                               | NONE => "", accepted, dropped)
        val complete = List.exists (String.isPrefix "@@END") (lines output)
    in if not complete then NONE else
       let val (accepted, dropped) = parse (lines output, NONE, "", [], [])
           val () = need (length accepted + length dropped = length files, "library probe omitted a source")
       in SOME (accepted, dropped) end end
  fun basis config dir =
    let val ctx = context config dir [] MatrixLoad.NoImage
        val gen = dir ^ "/basis"
        val () = MatrixLoad.remove gen
        val (status, output) = run ctx dir "generate-basis" [fromRoot "bin/rune-generate", "host-basis", gen] (#timeout ctx * 8)
        val () = need (status = 0, "host library generation failed: " ^ firstError output)
        val prelude = words (gen ^ "/prelude")
        val () = need (not (null prelude) andalso List.all exists prelude, "host generator published an invalid prelude")
        val records = List.map (fn line => case String.fields (fn c => c = #"\t") line of [path, names] => (path, String.tokens Char.isSpace names)
                                      | _ => raise Failed "malformed host library file table") (lines (read (gen ^ "/files")))
        val files = List.map #1 records
        val ok = gen ^ "/ok.sml"
        val () = write (ok, "val () = TextIO.print \"SUMMARY loaded\\n\"\n")
        fun check files = MatrixLoad.load ctx (dir ^ "/basis.work") MatrixLoad.Check (prelude @ files @ [ok])
        val initial = check []
        val () = need (#loaded initial, "host primitive prelude does not load: " ^ firstError (#messages initial ^ #output initial))
        val whole = check files
        fun individually ([], accepted, dropped) = (accepted, dropped)
          | individually (file :: rest, accepted, dropped) =
            let val result = check (accepted @ [file])
            in if #loaded result then individually (rest, accepted @ [file], dropped)
               else individually (rest, accepted, dropped @ [(OS.Path.file file, firstError (#messages result ^ #output result))]) end
        val (accepted, dropped) = if #loaded whole then (files, []) else
          case if List.exists (fn name => name = MatrixLoad.host config) ["smlnj-legacy", "smlnj32", "smlnj-dev", "polyml"]
               then sessionProbe ctx prelude files else NONE of
            SOME (accepted, dropped) => if #loaded (check accepted) then (accepted, dropped) else individually (files, [], [])
          | NONE => individually (files, [], [])
        val provided = List.concat (List.map #2 (List.filter (fn (file, _) => List.exists (fn a => a = file) accepted) records))
        fun linesOf rows = String.concat (List.map (fn line => line ^ "\n") rows)
        val () = atomic (dir ^ "/basis.loaded", linesOf accepted)
        val () = atomic (dir ^ "/basis.provides", linesOf provided)
        val () = atomic (dir ^ "/basis.dropped", linesOf (List.map (fn (file, why) => file ^ "\t" ^ why) dropped))
        val () = saveImage ctx (prelude @ accepted)
        val () = MatrixLoad.remove (dir ^ "/basis.work")
    in () end
  fun xc2 config dir =
    let val ctx = context config dir [] MatrixLoad.NoImage
        val gen = dir ^ "/xc2"
        val () = need (isDir (#extra config), "missing library sources: " ^ #extra config)
        val () = MatrixLoad.remove gen
        val log = dir ^ "/generate-xc2.log"
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME (#timeout ctx * 8),
                                    fileSize = SOME (64 * 1024 * 1024), core = SOME 0} (setEnv ("RUNE", #command config))
             {cmd = [fromRoot "bin/rune-generate", "xc2-" ^ MatrixLoad.host config, gen, #extra config], dir = SOME root,
              stdin = "", stdout = log, stderr = log, timeout = #timeout ctx * 8}
        val () = need (status = 0, "xc2 generation failed: " ^ firstError (read log))
        val prefix = words (gen ^ "/prefix")
        val () = need (not (null prefix) andalso List.all exists prefix, "xc2 generator published an invalid prefix")
        val result = MatrixLoad.load ctx (dir ^ "/basis.work") MatrixLoad.Run
                       (prefix @ [fromRoot "tests/basis/harness.sml", fromRoot "tests/basis/finish.sml"])
    in need (#loaded result andalso #status result = 0, "xc2 library does not load: " ^ firstError (#messages result ^ #output result)) end
  fun prepare config dir =
    let val () = mkdirs dir
        val () = MatrixLoad.remove (dir ^ "/basis.done")
        val start = Runtime.clock ()
        fun body () =
          let val key = key config
              val cross = MatrixLoad.kind config
              val files = if cross = "xc1" then words (dir ^ "/basis.loaded") @ words (dir ^ "/basis/prelude")
                          else words (dir ^ "/xc2/prefix")
              val cached = read (dir ^ "/basis.key") = key ^ "\n" andalso not (null files) andalso List.all exists files
              val () = if cached then
                   (if cross = "xc1" andalso not (exists (dir ^ "/basis.image")) then saveImage (context config dir [] MatrixLoad.NoImage)
                          (words (dir ^ "/basis/prelude") @ words (dir ^ "/basis.loaded")) else ())
                 else (discardImage dir; MatrixLoad.remove (dir ^ "/basis.key");
                       if cross = "xc1" then basis config dir else if cross = "xc2" then xc2 config dir else ();
                       atomic (dir ^ "/basis.key", key ^ "\n"))
              val () = atomic (dir ^ "/basis.time", (if cached then "cached 0 " else "probed 1 ")
                                ^ Time.fmt 3 (Time.- (Runtime.clock (), start)) ^ "\n")
          in atomic (dir ^ "/basis.done", "ok\n") end
    in body () handle e => (atomic (dir ^ "/basis.done", "failed: " ^ error e ^ "\n"); raise e) end
  fun ready config dir =
    let val cross = MatrixLoad.kind config
    in if cross <> "xc1" andalso cross <> "xc2" then ([], MatrixLoad.NoImage) else
       (need (read (dir ^ "/basis.done") = "ok\n", "library producer did not succeed: " ^ read (dir ^ "/basis.done"));
        if cross = "xc1" then (words (dir ^ "/basis/prelude") @ words (dir ^ "/basis.loaded"), image config dir)
        else (words (dir ^ "/xc2/prefix"), MatrixLoad.NoImage)) end
end
