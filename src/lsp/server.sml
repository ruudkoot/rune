(* Standalone server command-line entry point. *)
structure RuneLsp =
struct
  structure P=LspProtocol
  exception Usage of string
  fun stderr message=(TextIO.output (TextIO.stdErr,"runelsp: " ^ message ^ "\n");TextIO.flushOut TextIO.stdErr)
  fun main args =
    let
      val lib = ref "lib"
      val maximum = ref (16 * 1024 * 1024)
      fun parse [] = () | parse ("--stdio" :: rest) = parse rest
        | parse ("--lib" :: directory :: rest) = (lib := directory; parse rest)
        | parse ("--max-message-bytes" :: value :: rest) =
            (case P.uinteger (Json.Number value) of
               SOME n => if IntInf.> (n, 0) andalso IntInf.<= (n, IntInf.fromInt String.maxSize)
                         then (maximum := IntInf.toInt n; parse rest) else raise Usage "invalid message byte limit"
             | NONE => raise Usage "invalid message byte limit")
        | parse _ = raise Usage "usage: runelsp [--stdio] [--lib DIR] [--max-message-bytes N]"
    in case args of
         ["--help"] => (print "runelsp [--stdio] [--lib DIR] [--max-message-bytes N]\n"; OS.Process.success)
       | ["--version"] => (print ("runelsp " ^ Config.version ^ "\n"); OS.Process.success)
       | _ =>
           if List.exists (fn arg => arg="--analysis-worker") args then RuneLspWorker.serve () else
           let val ()=parse args
               val windows=List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
               val program=CommandLine.name ()
               val normalized=if windows then String.map (fn #"\\" => #"/" | c => c) program else program
               val vm=OS.Path.concat (OS.Path.dir normalized,if windows then "runevm.exe" else "runevm")
           in RuneLspSession.serve {maxMessageBytes= !maximum,lib= !lib,workerCommand=vm,
             workerArgs=["--jit=opt","--heap-limit","536870912",program,"--analysis-worker"]} end
    end handle Usage message => (stderr message; OS.Process.failure)
             | e => (stderr (General.exnMessage e); OS.Process.failure)
end
