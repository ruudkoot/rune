(* Native compiler/session adapter. Policy, selected sources, recovery and
   expectations remain with the caller. Every child inherits its runner job's
   process group, including compiler subprocesses. *)
structure MatrixHost =
struct
  open Sh
  type result = {built : bool, status : int, output : string, messages : string,
                 again : (string * string) list -> int * string}
  fun buildWith {host = h : Hosts.host, name, sources, directory, runDirectory, input, timeout,
                 addressMB, polyOptions, int64, compileTimeout} : result =
    let
      val () = mkdirs directory
      val directory = OS.FileSys.fullPath directory
      val runDirectory = OS.FileSys.fullPath runDirectory
      val host = #name h
      val program = #program h
      val sourcePaths = List.map fromRoot sources
      fun file suffix = directory ^ "/" ^ name ^ suffix
      val limits = {addressSpace = SOME (addressMB * 1024 * 1024),
                    cpuTime = NONE, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
      val serial = ref 0
      fun execute at deadline (args, stdin, changes, log) =
        let val status = Children.exec limits (Hosts.cleanEnv changes)
              {cmd = args, dir = SOME at, stdin = stdin, stdout = log, stderr = log, timeout = deadline}
            val output = read log
            val output = if status = 124 then output ^ "\n(stopped after " ^ Int.toString deadline ^ " s)\n" else output
        in (status, output) end
      fun run args stdin changes =
        (serial := !serial + 1;
         execute runDirectory timeout (args, stdin, changes, file (".run-" ^ Int.toString (!serial))))
      fun static output =
        let val (prior, _) = Substring.position "\nLAW " (Substring.full output)
            val text = Substring.string prior
        in if String.isPrefix "smlnj" host then
             List.exists (fn line => String.isSubstring " Error:" line andalso
                List.exists (fn path => not (null (MatrixProbe.errorLines host line path))) sourcePaths) (lines text)
           else if host = "polyml" then String.isSubstring ": error:" text orelse String.isSubstring "Static Errors" text
           else MatrixProbe.staticError host text end
      fun executable path = OS.FileSys.access (path, [OS.FileSys.A_EXEC]) andalso OS.FileSys.fileSize path > 0
                            handle OS.SysErr _ => false
    in
      if host = "mlton" orelse host = "mlkit" then
        let
          val () = if exists (file "") then OS.FileSys.remove (file "") else ()
          val () = write (file ".mlb", "$(SML_LIB)/basis/basis.mlb\n" ^ String.concat
                    (List.map (fn path => "\"" ^ String.toString path ^ "\"\n") sourcePaths))
          val changes = if host = "mlkit" then [("SML_LIB", #library h)] else []
          val flags = if host = "mlton" andalso int64 then ["-default-type", "int64", "-default-type", "word64"] else []
          val (code, messages) = execute directory compileTimeout
              ([program] @ flags @ [if host = "mlton" then "-output" else "-o", name, name ^ ".mlb"], "", changes, file ".build")
          val built = code = 0 andalso not (static messages) andalso executable (file "")
          fun again changes = run [file ""] input changes
          val (status, output) = if built then again [] else (if code = 0 then 2 else code, "")
          val messages = if code = 0 andalso not built then messages ^ "\ncompiler exited successfully without a valid executable\n" else messages
        in {built = built, status = status, output = output, messages = messages, again = again} end
      else
        let
          val () =
            if host = "polyml" then write (file ".use", String.concat
                   (List.map (fn path => "use \"" ^ String.toString path ^ "\";\n") sourcePaths)
                   ^ "OS.Process.exit OS.Process.success;\n")
            else ()
          val exit = directory ^ "/exit.sml"
          val () = write (exit, "val () = OS.Process.exit OS.Process.success\n")
          fun again changes =
            if host = "polyml" then run (program :: polyOptions) (file ".use") changes
            else run (program :: sourcePaths @ [exit]) input changes
          val (status, output) = again []
          val built = not (static output)
        in {built = built, status = status, output = output, messages = if built then "" else output, again = again} end
    end
  fun build {host, name, sources, directory, runDirectory, input, timeout, memory, int64} =
    buildWith {host = host, name = name, sources = sources, directory = directory, runDirectory = runDirectory,
      input = input, timeout = timeout, int64 = int64,
      addressMB = if #name host = "polyml" then Int.max (4096, memory * 2) else memory,
      polyOptions = ["-q", "--maxheap", Int.toString memory], compileTimeout = timeout}
  fun laws {host, name, sources, directory, runDirectory, input, timeout, memory} =
    buildWith {host = host, name = name, sources = sources, directory = directory, runDirectory = runDirectory,
      input = input, timeout = timeout, int64 = false, addressMB = memory, polyOptions = ["-q"],
      (* The former driver applied LAWS_HOST_TIMEOUT only to execution of a
         linked program. Compilation was unbounded. Keep a separate explicit
         compilation deadline; shortening the law deadline must not change
         which property libraries can be built. *)
      compileTimeout = Int.max (1, getOpt (Int.fromString (env ("LAWS_HOST_COMPILE_TIMEOUT", "600")), 600))}
end
