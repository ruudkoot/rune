(* Checked standalone programs and data use the matrix loader directly. A
   successful process and a consistent zero-failure summary are both required. *)
structure MatrixProgram =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun readList file =
    let val () = need (exists file, "missing source/data list " ^ file)
        val text = read file
        val rows = String.fields (fn c => c = #"\n") text
    in List.filter (fn row => row <> "") rows end
  fun summary output =
    let val checks = MatrixSuite.checks output
        val summaries = List.filter (String.isPrefix "SUMMARY ") (lines output)
        val zero = case summaries of [line] => (case String.tokens Char.isSpace line of
               ["SUMMARY", n, "checks,", "0", "failed"] => Int.fromString n = SOME (length checks) | _ => false) | _ => false
        val labels = List.map MatrixSuite.label checks
    in zero andalso not (List.exists (String.isPrefix "FAIL ") checks) end
  fun run {config, directory, sources, input, data, timeout, memoryKiB} =
    let val () = need (not (null sources) andalso List.all exists sources, "empty or missing standalone program sources")
        val () = need (exists input, "missing standalone program input")
        val () = need (timeout > 0 andalso memoryKiB > 0, "invalid standalone program limit")
        val () = need (MatrixLoad.kind config <> "xc1", "standalone xc1 programs require library setup")
        val () = if MatrixLoad.kind config = "xc2" then MatrixPrepare.prepare config directory else ()
        val (prefix, image) = MatrixPrepare.ready config directory
        val ctx : MatrixLoad.context = {config = config, directory = directory, prefix = prefix, image = image,
           standalone = true, input = input, data = data, timeout = timeout, memoryKiB = memoryKiB}
        val () = mkdirs directory
        val result = MatrixLoad.load ctx (directory ^ "/program") MatrixLoad.Run (prefix @ sources)
        val poly = MatrixLoad.host config = "polyml"
        val limitLine = "PROGRAM LIMIT " ^ (if poly then "DATA " else "AS ") ^ Int.toString memoryKiB ^ " KiB"
                     ^ (if poly then "; ML heap " ^ Int.toString (memoryKiB div 2048) ^ " MiB" else "") ^ "\n"
        val () = say limitLine
        val () = say (#output result)
        val pass = #loaded result andalso #status result = 0 andalso summary (#output result)
        val verdictLine = "PROGRAM " ^ (if pass then "PASS " else "FAIL ") ^ #id config
                        ^ (if pass then "" else " (exit " ^ Int.toString (#status result) ^ "): " ^ MatrixPrepare.firstError (#messages result)) ^ "\n"
        val () = MatrixPrepare.atomic (directory ^ "/program.console",limitLine ^ #output result ^ verdictLine)
        val () = say verdictLine
    in need (pass, "standalone program failed: " ^ #id config) end
end
