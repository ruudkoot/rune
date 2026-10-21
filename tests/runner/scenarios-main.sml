structure ScenarioMain =
struct
  open Sh
  exception Usage of string
  fun main args =
    let val (suite, args) = case args of suite :: rest => (suite, rest) | _ => raise Usage "deps | buildfile | dynamic | units | install | dist"
        val () = if List.exists (fn name => name = suite) ["deps", "buildfile", "dynamic", "units", "install", "dist"] then ()
                 else raise Usage ("unknown suite " ^ suite)
        val changes = ref [] : (string * string) list ref
        val hosts = ref ["rbc"]
        fun parse [] = ()
          | parse ("--rune" :: compiler :: rest) = (changes := ("SCENARIO_RUNE", fromRoot compiler) :: !changes; parse rest)
          | parse ("--host" :: host :: rest) =
              if suite = "install" andalso List.exists (fn h => h = host) Hosts.names
              then (hosts := !hosts @ [host]; parse rest) else raise Usage "invalid install host"
          | parse _ = raise Usage "unexpected or incomplete scenario option"
        val () = parse args
        val changes = if suite = "install" then ("SCENARIO_INSTALL_HOSTS", String.concatWith "," (!hosts)) :: !changes else !changes
        val environment = List.foldl (fn ((name, value), e) => setEnv (name, value) e) (Posix.ProcEnv.environ ()) changes
        val vm = fromRoot "bin/runevm"
    in Posix.Process.exece (vm, [vm, fromRoot "bin/rune-test.rbc", "run", "--tier", "scenarios-" ^ suite], environment) end
end
val () = case ScenarioJobs.command (CommandLine.arguments ()) of SOME action => action ()
 | NONE => (ScenarioMain.main (CommandLine.arguments ()) handle ScenarioMain.Usage message =>
       (TextIO.output (TextIO.stdErr, "rune-scenarios: " ^ message ^ "\n"); TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2))
