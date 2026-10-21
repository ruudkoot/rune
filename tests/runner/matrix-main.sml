(* Public compatibility CLI. Once selections are concrete, exec the existing
   inventory/runner; workers use the same small executable for SML actions. *)
structure MatrixMain =
struct
  open Sh
  exception Usage of string
  fun main args =
    let val configs = ref "rune"
        val jobs = ref (env ("RUNE_TEST_CPUS", Int.toString (Runtime.processors ())))
        val filter = ref ""
        val resolve = ref ""
        val exact = ref false
        val changes = ref [] : (string * string) list ref
        fun set key value = changes := (key, value) :: List.filter (fn (name, _) => name <> key) (!changes)
        fun parse [] = ()
          | parse ("--one" :: config :: test :: rest) =
              (configs := hd (String.fields (fn c => c = #"@") config); filter := test; exact := true; parse rest)
          | parse ("-j" :: n :: rest) = (jobs := n; parse rest)
          | parse ("--configs" :: selection :: rest) = (configs := selection; parse rest)
          | parse ("--timing" :: rest) = (set "RUNE_MATRIX_TIMING" "1"; parse rest)
          | parse ("--perf" :: rest) = (set "RUNE_MATRIX_PERF" "1"; set "RUNE_MATRIX_TIMING" "1"; parse rest)
          | parse ("--refresh" :: rest) = (set "RUNE_MATRIX_REFRESH" "1"; parse rest)
          | parse ("--program-list" :: file :: rest) = (set "RUNE_MATRIX_PROGRAM_LIST" (fromRoot file); parse rest)
          | parse ("--program-input" :: file :: rest) = (set "RUNE_MATRIX_PROGRAM_INPUT" (fromRoot file); parse rest)
          | parse ("--program-data" :: file :: rest) = (set "RUNE_MATRIX_PROGRAM_DATA" (fromRoot file); parse rest)
          | parse ("--program-data-list" :: file :: rest) = (set "RUNE_MATRIX_PROGRAM_DATA_LIST" (fromRoot file); parse rest)
          | parse ("--program-out" :: dir :: rest) =
              let val path = OS.Path.mkCanonical (fromRoot dir)
              in if String.isPrefix (root ^ "/tests/out/") path andalso MatrixLoad.dataPath (String.extract (path, size root + 1, NONE))
                 then (set "RUNE_MATRIX_OUT" path; parse rest) else raise Usage "program output must be under tests/out" end
          | parse ("--resolve-out" :: file :: rest) = (resolve := fromRoot file; parse rest)
          | parse (arg :: rest) = if String.isPrefix "-" arg then raise Usage ("unknown or incomplete option " ^ arg)
                                 else (filter := arg; parse rest)
        val () = parse args
        val () = if (case Int.fromString (!jobs) of SOME n => n > 0 | NONE => false) then () else raise Usage "invalid job count"
        val specs = MatrixModel.expand (!configs)
        val () = if null specs orelse length specs <> length (MatrixProbe.unique specs) then raise Usage "empty or duplicate matrix selection" else ()
        val () = List.app (fn spec => if MatrixModel.validSpec spec then () else raise Usage ("unknown configuration " ^ spec)) specs
        fun chosen key = case List.find (fn (name, _) => name = key) (!changes) of SOME (_, value) => value | NONE => env (key, "")
        val perf = chosen "RUNE_MATRIX_PERF" = "1"
        val timing = perf orelse chosen "RUNE_MATRIX_TIMING" = "1"
        val () = if perf andalso chosen "RUNE_MATRIX_PROGRAM_LIST" <> "" then raise Usage "standalone program mode cannot be combined with perf" else ()
        val () = set "RUNE_MATRIX_CONFIGS" (!configs)
        val () = set "RUNE_MATRIX_FILTER" (!filter)
        val () = if !exact then set "RUNE_MATRIX_ONE" (!filter) else ()
        val () = set "RUNE_MATRIX_TIMING" (if timing then "1" else "0")
        val program = fromRoot "bin/runevm"
        val environment = List.foldl (fn ((name, value), environment) => setEnv (name, value) environment) (Posix.ProcEnv.environ ()) (!changes)
    in if !resolve <> "" then
       let val configs = MatrixModel.resolveAll {timing = timing, directory = fromRoot "tests/out/matrix-resolution" ^ "/" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())) } (!configs)
           val () = mkdirs (OS.Path.dir (!resolve))
       in write (!resolve, String.concat (List.map MatrixModel.row configs)) end
       else
         let val resolved = MatrixModel.resolveAll {timing = timing,
                    directory = fromRoot "tests/out/matrix-resolution" ^ "/" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())) } (!configs)
             val standalone = chosen "RUNE_MATRIX_PROGRAM_LIST" <> ""
             val output = if chosen "RUNE_MATRIX_OUT" <> "" then chosen "RUNE_MATRIX_OUT" else
                     if chosen "RUNE_MATRIX_RUN" <> "" then fromRoot (chosen "RUNE_MATRIX_RUN") ^ "/matrix" else fromRoot "tests/out/matrix"
             fun console (c : MatrixModel.config) = output ^ "/" ^ MatrixSuite.path (#id c) ^ "/program.console"
             val () = if standalone then List.app (fn c => MatrixLoad.remove (console c)) resolved else ()
             val pid = Subprocess.spawn {program = program,
                 args = [program,fromRoot "bin/rune-test.rbc","run","--strict","--tier","matrix-selected","-j",!jobs],
                 env = SOME environment, search = false, dir = SOME root, stdin = NONE, stdout = NONE, stderr = NONE,
                 group = false, limits = Subprocess.unlimited}
             val {status,...} = Subprocess.wait (SOME pid)
             val () = if standalone then List.app (fn c => if exists (console c) then say (read (console c)) else ()) resolved else ()
         in case status of Posix.Process.W_EXITED => ()
             | Posix.Process.W_EXITSTATUS code => Posix.Process.exit code
             | Posix.Process.W_SIGNALED signal => Posix.Process.exit (Word8.fromInt (128 + SysWord.toInt (Posix.Signal.toWord signal)))
             | _ => Posix.Process.exit 0w1 end
    end
  fun protect f = f () handle Usage why =>
      (TextIO.output (TextIO.stdErr, "rune-matrix: " ^ why ^ "\n"); TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2)
    | MatrixModel.Invalid why =>
      (TextIO.output (TextIO.stdErr, "rune-matrix: " ^ why ^ "\n"); TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2)
end
val () = case Matrix.command (CommandLine.arguments ()) of SOME f => f ()
         | NONE => MatrixMain.protect (fn () => MatrixMain.main (CommandLine.arguments ()))
