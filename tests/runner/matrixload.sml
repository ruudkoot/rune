(* Matrix compilation and execution, with explicit input/data and host image
   contracts. The surrounding runner owns scheduling and process groups. *)
structure MatrixLoad =
struct
  open Sh
  exception Failed of string
  datatype mode = Check | Run
  datatype image = NoImage | NJImage of string | PolyImage of string
  type context = {config : MatrixModel.config, directory : string, prefix : string list, image : image,
                  standalone : bool, input : string, data : (string * string) list, timeout : int, memoryKiB : int}
  type result = {loaded : bool, status : int, output : string, messages : string, timedOut : bool}
  fun need (ok, why) = if ok then () else raise Failed why
  fun remove path =
    if not (exists path) andalso not (OS.FileSys.isLink path handle OS.SysErr _ => false) then ()
    else if OS.FileSys.isLink path then OS.FileSys.remove path
    else if isDir path then
      (Posix.FileSys.chmod (path, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]);
       List.app (fn name => remove (path ^ "/" ^ name)) (entries path); OS.FileSys.rmDir path)
    else OS.FileSys.remove path
  fun copy (source, destination) =
    let val () = mkdirs (OS.Path.dir destination)
        val input = BinIO.openIn source
        val output = BinIO.openOut destination
        fun loop () = let val bytes = BinIO.inputN (input, 65536)
                      in if Word8Vector.length bytes = 0 then () else (BinIO.output (output, bytes); loop ()) end
        fun close () = (BinIO.closeIn input; BinIO.closeOut output)
    in (loop (); close ()) handle e => (close (); raise e) end
  fun dataPath path = path <> "" andalso not (OS.Path.isAbsolute path) andalso
       List.all (fn part => part <> "" andalso part <> "." andalso part <> "..") (String.fields (fn c => c = #"/") path)
       andalso not (CharVector.exists (fn c => c = #"\000" orelse c = #"\n" orelse c = #"\r") path)
  fun stage dir data = List.app (fn (source, path) =>
       (need (dataPath path, "invalid matrix data path " ^ path); copy (source, dir ^ "/" ^ path))) data
  fun hash names =
    let fun file (path, context) =
          let val input = BinIO.openIn path
              fun loop context = let val bytes = BinIO.inputN (input, 65536)
                in if Word8Vector.length bytes = 0 then context
                   else loop (Sha256.update (context, Byte.bytesToString bytes)) end
          in (loop (Sha256.update (context, path ^ "\000" ^ Position.toString (OS.FileSys.fileSize path) ^ "\000"))
                 before BinIO.closeIn input) handle e => (BinIO.closeIn input; raise e) end
    in Hex.fromBytes (Sha256.finish (List.foldl file Sha256.empty names)) end
  fun legacyKey dir sources =
    let val input = dir ^ "/cache-input"
        val output = dir ^ "/cache-checksum"
        val stream = BinIO.openOut input
        fun one path =
          let val source = BinIO.openIn path
              fun loop () = let val bytes = BinIO.inputN (source, 65536)
                            in if Word8Vector.length bytes = 0 then () else (BinIO.output (stream, bytes); loop ()) end
          in (loop () before BinIO.closeIn source) handle e => (BinIO.closeIn source; raise e) end
        val () = (List.app one sources; BinIO.closeOut stream) handle e => (BinIO.closeOut stream; raise e)
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 30, fileSize = SOME 1024, core = SOME 0} (fn e => e)
               {cmd = ["cksum"], dir = SOME root, stdin = input, stdout = output, stderr = output ^ ".err", timeout = 30}
        val checksum = read output
        val valid = status = 0 andalso (case String.tokens Char.isSpace checksum of [crc, count] =>
                     CharVector.all Char.isDigit crc andalso CharVector.all Char.isDigit count | _ => false)
        val () = remove input
    in need (valid, "invalid native checksum response for legacy cache");
       String.concat (List.map (fn path => path ^ " ") sources) ^ checksum end
  fun driver sources =
    "(" ^ String.concatWith "; " (List.map (fn source => "use \"" ^ String.toString source ^ "\"") sources)
      ^ ") handle e => (print (\"uncaught exception \" ^ exnName e ^ \" [\" ^ exnMessage e ^ \"]\\n\"); OS.Process.exit OS.Process.failure);\n"
  fun kind (config : MatrixModel.config) = case #library config of MatrixModel.RuneBasis => "rune"
       | MatrixModel.NativeBasis _ => "native" | MatrixModel.RuneOnHost _ => "xc1" | MatrixModel.HostOnRune _ => "xc2"
  fun host (config : MatrixModel.config) = case #compiler config of MatrixModel.Host h => #name h
       | _ => case #library config of MatrixModel.HostOnRune name => name | _ => ""
  fun execute (ctx : context) work {args, input, output, errors, timeout} =
    let val standalone = #standalone ctx
        val poly = host (#config ctx) = "polyml"
        val bounded = standalone orelse host (#config ctx) = "mlkit"
        val limits = {addressSpace = if bounded andalso not poly then SOME (#memoryKiB ctx * 1024) else NONE,
                      cpuTime = NONE, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
        (* RLIMIT_DATA is an OS launch operation. Poly/ML reserves 18 GiB of
           virtual space; preserve the old data quota and separate ML heap cap. *)
        val args = if standalone andalso poly then
             ["/bin/sh", "-c", "ulimit -d \"$1\" || exit 2; shift; exec \"$@\"", "matrix-data-limit", Int.toString (#memoryKiB ctx)] @ args
           else args
        val environment = Hosts.cleanEnv [("TZ", "NST3:30NDT,M3.2.0,M11.1.0")]
        val environment = case #compiler (#config ctx) of MatrixModel.Host h =>
               if #name h = "mlkit" then setEnv ("SML_LIB", #library h) o environment else environment
             | _ => environment
    in Children.exec limits environment {cmd = args, dir = SOME work, stdin = input,
                       stdout = output, stderr = errors, timeout = timeout} end
  fun load (ctx : context) work mode sources : result =
    let
      val config = #config ctx
      val () = remove work
      val () = mkdirs work
      val () = stage work (#data ctx)
      val stdout = work ^ "/stdout"
      val log = work ^ "/log"
      val () = write (stdout, "")
      val () = write (log, "")
      val limit = #timeout ctx
      val command = #command config
      val host = host config
      val check = mode = Check
      val sources = List.map fromRoot sources
      fun exec args input output errors timeout = execute ctx work
                   {args = args, input = input, output = output, errors = errors, timeout = timeout}
      fun result status =
        let val output = read stdout
            val timed = status = 124
            val () = if timed then append (log, "\ntimed out after " ^ Int.toString limit ^ " s\n") else ()
            val session = case #compiler config of MatrixModel.Host _ => String.isPrefix "smlnj" host orelse host = "polyml"
                         | MatrixModel.Rune _ => false
            val () = write (work ^ ".status", Int.toString status ^ "\n")
        in {loaded = if check andalso not session then status = 0 else
                     List.exists (String.isPrefix "SUMMARY ") (lines output)
                       andalso (status = 0 orelse status = (if host = "mlkit" andalso kind config <> "xc1" then 255 else 1)),
            status = status, output = output, messages = read log, timedOut = timed} : result end
      fun executable file = MatrixModel.executable file andalso OS.FileSys.fileSize file > 0
      fun runCompiled binary =
        let val prior = read log
            val status = exec [binary] (#input ctx) stdout log limit
            val () = write (log, prior ^ read log)
        in result status end
      fun missing name = (append (log, "\nerror: compiler exited successfully without " ^ name ^ "\n"); result 2)
    in
      case #compiler config of
        MatrixModel.Rune _ =>
          let val extra = case #library config of MatrixModel.HostOnRune _ =>
                       ["--lib", #directory ctx ^ "/xc2/lib", "--allow-prim"] @ words (#directory ctx ^ "/xc2/flags")
                     | _ => []
              val flags = if #standalone ctx andalso kind config = "rune" then
                              String.tokens Char.isSpace (env ("RUNE_BENCH_COMPILE_OPTIONS", "")) else []
              val output = work ^ "/prog.rbc"
              (* The prepared external library is a compilation input. Rune's
                 library is also guarded by the source/library mtimes below;
                 changing only the execution VM must preserve bytecode reuse. *)
              val libkey = if kind config = "xc2" then read (#directory ctx ^ "/basis.key") else ""
              val key = if check then "" else "matrix-key-v2\n" ^ hash sources ^ "\n" ^ command ^ "\n"
                        ^ String.concatWith "\n" (extra @ flags) ^ "\n"
                        ^ (if size libkey >= 64 then String.substring (libkey, 0, 64) else libkey) ^ "\n"
              val reuse = env ("RUNE_MATRIX_BYTECODE", "")
              val candidate = if reuse = "" then "" else fromRoot reuse ^ "/" ^ OS.Path.file work ^ "/prog.rbc"
              fun tree path = path :: (if isDir path andalso not (OS.FileSys.isLink path) then
                       List.concat (List.map (fn name => tree (path ^ "/" ^ name)) (entries path)) else [])
              fun reusable () =
                if check orelse candidate = "" orelse not (exists candidate) orelse OS.FileSys.fileSize candidate = 0 then false else
                  let val stored = read (OS.Path.base candidate ^ ".key")
                      val matches = if String.isPrefix "matrix-key-v2\n" stored then stored = key
                                    else stored = legacyKey work sources
                      val time = OS.FileSys.modTime candidate
                  in matches andalso List.all (fn file => Time.<= (OS.FileSys.modTime file, time))
                           (OS.FileSys.realPath command :: sources @ tree (fromRoot "lib/basis")) end
              val reused = reusable ()
              val status = if reused then (copy (candidate, output); 0) else
                   exec ([command] @ extra @ flags @ (if check then ["--typecheck-only"] else []) @ sources
                            @ (if check then [] else ["-o", output])) "" log log limit
          in if status <> 0 orelse check then result status else if not (exists output) orelse OS.FileSys.fileSize output = 0 then missing "bytecode"
             else
               let val () = write (work ^ "/prog.key", key)
                   val runDirectory = case #target config of MatrixModel.Windows _ =>
                     let val windows = env ("RUNE_WINDOWS_DIR", "")
                         val () = need (windows <> "", "RUNE_WINDOWS_DIR is required for Windows staging")
                         val dir = windows ^ "/matrix/" ^ OS.Path.file (#directory ctx) ^ "/" ^ OS.Path.file work
                         val () = remove dir
                         val () = mkdirs dir
                         val () = copy (output, dir ^ "/prog.rbc")
                         val () = stage dir (#data ctx)
                     in dir end
                   | _ => work
                   val prior = read log
                   val status = execute ctx runDirectory {args = [#vm config, "prog.rbc"], input = #input ctx,
                                            output = stdout, errors = log, timeout = limit}
                   val () = write (log, prior ^ read log)
               in result status end
          end
      | MatrixModel.Host h =>
        if host = "mlton" orelse host = "mlkit" then
          let
            val files = if host <> "mlkit" then sources else
              List.map (fn (i, path) => if String.isPrefix (#directory ctx ^ "/basis/") path then path else
                   let val destination = work ^ "/src/" ^ Int.toString i ^ "/" ^ OS.Path.file path
                   in copy (path, destination); destination end)
                (ListPair.zip (List.tabulate (length sources, fn i => i + 1), sources))
            val mlb = work ^ "/prog.mlb"
            val () = write (mlb, "$(SML_LIB)/basis/basis.mlb\n" ^ String.concat
                          (List.map (fn file => "\"" ^ String.toString file ^ "\"\n") files))
            val flags = if host = "mlton" andalso kind config = "xc1" then ["-default-type", "int64", "-default-type", "word64"] else []
            val args = if host = "mlton" then flags @ (if check then ["-stop", "tc", mlb] else ["-output", work ^ "/prog", mlb])
                       else ["--no_messages"] @ (if check then ["-c", "prog.mlb"] else ["-o", "prog", "prog.mlb"])
            val status = exec (command :: args) "" log log (if host = "mlkit" andalso check then limit * 8 else limit)
            val status = if status = 0 andalso MatrixProbe.staticError host (read log) then 2 else status
          in if status <> 0 orelse check then result status
             else if not (executable (work ^ "/prog")) then missing "executable" else runCompiled (work ^ "/prog") end
        else
          let val (loadState, files) = case #image ctx of NoImage => ("", sources)
                   | NJImage image =>
                     (need (List.exists (String.isPrefix (OS.Path.file image ^ ".")) (entries (OS.Path.dir image)), "missing SML/NJ heap image");
                      ("", List.drop (sources, length (#prefix ctx))))
                   | PolyImage image => (need (exists image, "missing Poly/ML state image");
                         ("val () = PolyML.SaveState.loadState \"" ^ String.toString image ^ "\";\n", List.drop (sources, length (#prefix ctx))))
              val () = write (work ^ "/driver.sml", loadState ^ driver files ^ "val () = OS.Process.exit OS.Process.success;\n")
              val args = if host = "polyml" then
                  (if #standalone ctx then ["-H", "16", "--maxheap", Int.toString (#memoryKiB ctx div 2048), "--stackspace", "64"] else [])
                         @ ["-q", "--error-exit", "--use", "driver.sml"]
                else (case #image ctx of NJImage image => ["@SMLload=" ^ image] | _ => ["driver.sml"])
              val status = exec (command :: args) (#input ctx) stdout log limit
              val output = read stdout ^ read log
              val status = if status = 0 andalso MatrixProbe.sessionError host sources output then 2 else status
          in result status end
    end
end
