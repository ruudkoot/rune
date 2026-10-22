(* The VM-shaped native launcher. The thin bin/runevm-native entrypoint
   supplies the repository root as the first private argument. Execution
   replaces this process, preserving the program's streams and signals. *)
structure NativeVM =
struct
  open Sh
  fun absolute here path = if OS.Path.isAbsolute path then path else OS.Path.concat (here, path)
  fun program here path = if String.isSubstring "/" path then absolute here path else path
  fun regular path = Posix.FileSys.ST.isReg (Posix.FileSys.stat path) handle OS.SysErr _ => false
  fun executable path =
    (OS.FileSys.access (path, [OS.FileSys.A_EXEC]) andalso not (OS.FileSys.isDir path)
     andalso OS.FileSys.fileSize path > 0) handle OS.SysErr _ => false
  fun temporary prefix =
    let
      val stem = prefix ^ "." ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
                 ^ "." ^ LargeInt.toString (Time.toMicroseconds (Runtime.clock ()))
      fun attempt n =
        if n = 100 then raise Fail "cannot reserve a native cache temporary"
        else
          let val path = stem ^ "." ^ Int.toString n
              val fd = Posix.FileSys.createf (path, Posix.FileSys.O_WRONLY, Posix.FileSys.O.flags [Posix.FileSys.O.excl],
                         Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
          in Posix.IO.close fd; path end
          handle e as OS.SysErr (_, SOME code) => if code = Posix.Error.exist then attempt (n + 1) else raise e
    in attempt 0 end
  fun smlChecksum file =
    let
      val input = BinIO.openIn file
      fun chunks context =
        let val bytes = BinIO.inputN (input, 65536)
        in if Word8Vector.length bytes = 0 then Sha256.finish context
           else chunks (Sha256.update (context, Byte.bytesToString bytes)) end
      val hash = (chunks Sha256.empty before BinIO.closeIn input)
                   handle e => (BinIO.closeIn input; raise e)
    in String.substring (Hex.fromBytes hash, 0, 32) end
  (* sha256sum is the existing native tool adapter. Use it when available
     so launching a cached compiler does not hash megabytes in the VM.
     The portable SML implementation remains the fallback and the oracle
     for this adapter's boundary checks. *)
  fun checksum file =
    let
      val path = String.fields (fn c => c = #":") (env ("PATH", ""))
      val tool = List.find executable (List.map (fn dir => OS.Path.concat (if dir = "" then "." else dir, "sha256sum")) path)
      fun external tool =
        let
          val output = temporary (env ("TMPDIR", "/tmp") ^ "/rune-sha256")
          fun remove () = OS.FileSys.remove output handle OS.SysErr _ => ()
          fun hash () =
            let val status = Children.exec Subprocess.unlimited (fn e => e)
                  {cmd = [tool], dir = NONE, stdin = file, stdout = output, stderr = "", timeout = 0}
            in case String.tokens Char.isSpace (read output) of
                 [sum, "-"] => if status = 0 andalso size sum = 64 andalso CharVector.all Char.isHexDigit sum
                               then SOME (String.map Char.toLower (String.substring (sum, 0, 32))) else NONE
               | _ => NONE end
        in (hash () before remove ()) handle e => (remove (); raise e) end
      val result = case tool of NONE => NONE | SOME tool =>
            (external tool handle OS.SysErr _ => NONE | IO.Io _ => NONE)
    in case result of SOME sum => sum | NONE => smlChecksum file end
  fun main repo args =
    let
      val repo = OS.FileSys.fullPath repo
      val here = OS.FileSys.getDir ()
      val vm = env ("RUNEVM", repo ^ "/bin/runevm-stack")
      val opt = program here (env ("RUNEOPT", if exists (repo ^ "/bin/runeopt-mlton")
                                            then repo ^ "/bin/runeopt-mlton" else repo ^ "/bin/runeopt"))
      val cache = absolute here (env ("RUNEOPT_CACHE", repo ^ "/tests/out/opt-cache"))
      val compilerOptions = List.concat (List.map
        (fn (key, flag, path) => case OS.Process.getEnv key of
             SOME value => if value = "" then [] else [flag, path value] | NONE => [])
        [("RUNEOPT_RUNTIME", "--runtime", absolute here), ("RUNEOPT_CC", "--cc", program here)])
      fun delegate args = Posix.Process.execp (vm, vm :: args)
      fun remove path = OS.FileSys.remove path handle OS.SysErr _ => ()
      fun fresh name = temporary (cache ^ "/" ^ name)
      fun report log =
        (TextIO.output (TextIO.stdErr, String.concatWith "\n" (List.map
          (fn l => if String.isPrefix "runeopt: " l then "runevm: " ^ String.extract (l, 9, NONE) else l)
          (String.fields (fn c => c = #"\n") (read log)))); TextIO.flushOut TextIO.stdErr)
      fun translate (args, target, dir) =
        let val log = target ^ ".log"
            val status = Children.exec Subprocess.unlimited (fn e => e)
              {cmd = opt :: compilerOptions @ args @ ["-o", target], dir = dir,
               stdin = "", stdout = log, stderr = log, timeout = 0}
        in
          if status = 0 andalso executable target then (remove log; true)
          else (report log;
                if status = 0 then (TextIO.output (TextIO.stdErr, "runevm: native compiler produced no executable\n");
                                    TextIO.flushOut TextIO.stdErr) else ();
                List.app remove [target, log, target ^ ".rbc", target ^ ".s"]; false)
        end
      fun execute exe options name args =
        let val e = setEnv ("RUNEVM_OPTIONS", env ("RUNEVM_OPTIONS", "") ^ options) (Posix.ProcEnv.environ ())
            val e = case name of NONE => e | SOME name => setEnv ("RUNEVM_NAME", name) e
        in Posix.Process.exece (exe, exe :: args, e) end
      val unary = ["--count", "--stats", "--emulate-fork", "--checked", "--gc-verify", "--gc-compact", "--gc-stress-cycles"]
      val binary = ["--heap-size", "--heap-limit", "--equality-work", "--heap-fill", "--gc-stress", "--gc-log",
                    "--nursery", "--nursery-max", "--gc", "--old-space"]
      fun parse ([], _, _) = delegate []
        | parse ("--name" :: name :: rest, options, _) = parse (rest, options, if name = "" then NONE else SOME name)
        | parse ("--restore" :: image :: rest, options, name) =
            if not (regular image) then delegate ("--restore" :: image :: rest)
            else
              let val () = mkdirs cache
                  val exe = fresh "image"
              in if translate (["--from-image", image], exe, NONE)
                 then execute exe (options ^ " --restore " ^ image) name rest
                 else Posix.Process.exit 0w2 end
        | parse (arg :: rest, options, name) =
            if List.exists (fn flag => flag = arg) unary then parse (rest, options ^ " " ^ arg, name)
            else if List.exists (fn flag => flag = arg) binary then
              (case rest of value :: tail => parse (tail, options ^ " " ^ arg ^ " " ^ value, name)
                          | [] => delegate [arg])
            else if String.isPrefix "-" arg then delegate (arg :: rest)
            else if not (regular arg) then delegate (String.tokens Char.isSpace options @ (arg :: rest))
            else
              let
                val () = mkdirs cache
                val sum = checksum arg
                val exe = cache ^ "/" ^ sum
                val ready = executable exe
                val tmp = if ready then "" else fresh sum
                val built = ready orelse translate ([absolute here arg], tmp, SOME repo)
                val () = if built andalso not ready then OS.FileSys.rename {old = tmp, new = exe} else ()
              in if built then execute exe options (SOME (getOpt (name, arg))) rest
                 else Posix.Process.exit 0w2 end
    in parse (args, "", NONE) end
end
