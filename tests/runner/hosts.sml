(* The native SML hosts used by the library suites and the matrix. Commands
   are arguments, never shell text. Each build has its own directory;
   MLKit also caches beside its sources, so its jobs share the matrix pool.
   Every child has a memory limit and a process group. *)
structure Hosts =
struct
  open Sh

  type host = {name : string, program : string, library : string}
  type result = {built : bool, status : int, output : string, messages : string,
                 again : (string * string) list -> int * string}
  val names = ["mlton", "smlnj-legacy", "smlnj32", "smlnj-dev", "polyml", "mlkit"]
  val home = env ("RUNE_HOSTS", env ("HOME", "") ^ "/.local/rune-hosts")
  val settings =
    [("mlton", "MLTON", "mlton/bin/mlton"),
     ("smlnj-legacy", "SMLNJ", "smlnj-legacy/bin/sml"),
     ("smlnj32", "SMLNJ32", "smlnj32/bin/sml"),
     ("smlnj-dev", "SMLNJ_DEV", "smlnj-dev/bin/sml"),
     ("polyml", "POLY", "polyml/bin/poly"),
     ("mlkit", "MLKIT", "mlkit/bin/mlkit")]
  fun get name =
    case List.find (fn (n, _, _) => n = name) settings of
      SOME (_, variable, path) =>
        {name = name, program = fromRoot (env (variable, home ^ "/" ^ path)),
         library = fromRoot (env ("MLKIT_LIB", home ^ "/mlkit/lib/mlkit"))} : host
    | NONE => raise Fail ("unknown host: " ^ name)

  val capabilities = List.map
    (fn n => {name = "host:" ^ n, probe = "test -x " ^ quote (#program (get n)), hint = "run: make hosts"}) names

  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))
  type source = {path : string, host : bool, provides : string list, requires : string list}
  fun manifest library =
    let
      val dir = "lib/" ^ library
      fun one l =
        if String.isPrefix "#" l orelse trim l = "" then NONE
        else case List.map trim (String.fields (fn c => c = #"|") l) of
          f :: _ :: h :: p :: r :: _ =>
            SOME {path = dir ^ "/" ^ f, host = h = "yes", provides = String.tokens Char.isSpace p,
                  requires = String.tokens Char.isSpace r}
        | _ => raise Fail (dir ^ "/MANIFEST: malformed line: " ^ l)
      val file = dir ^ "/MANIFEST"
      val () = if exists file then () else raise Fail (file ^ ": missing; run make manifests")
    in List.mapPartial one (lines (read file)) end
  fun portable library = List.map #path (List.filter #host (manifest library))

  fun cleanEnv changes e =
    List.foldl (fn ((k, v), e) => setEnv (k, v) e) (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"] e) changes

  (* Build, run, and (for laws) run again with changed property settings.
     A session's exit status is checked apart from its diagnostics: SML/NJ
     can report a static error and exit successfully. *)
  fun build {host = {name = host, program, library} : host, name, sources, dir, runDir, timeout, memory} =
    let
      val () = mkdirs dir
      val dir = OS.FileSys.fullPath dir
      fun f ext = dir ^ "/" ^ name ^ ext
      val sources = List.map fromRoot sources
      (* Poly/ML reserves more virtual space than its heap: a 2 GiB
         address-space cap prevents even an empty session from starting.
         Bound its heap explicitly and leave room for that reservation. *)
      val addressMB = if host = "polyml" then Int.max (4096, memory * 2) else memory
      val limits = {addressSpace = SOME (addressMB * 1024 * 1024), cpuTime = NONE, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
      val serial = ref 0
      fun execute at (args, stdin, changes, log) =
        let val status = execLimited limits (cleanEnv changes)
              {cmd = args, dir = SOME at, stdin = stdin, stdout = log, stderr = log, timeout = timeout}
        in (status, read log) end
      fun run args stdin changes =
        (serial := !serial + 1;
         execute runDir (args, stdin, changes, f (".run-" ^ Int.toString (!serial))))
      fun session () =
        if host = "polyml" then
          let val () = write (f ".use", String.concat (List.map (fn p => "use \"" ^ String.toString p ^ "\";\n") sources)
                                      ^ "OS.Process.exit OS.Process.success;\n")
          in fn changes => run [program, "-q", "--maxheap", Int.toString memory] (f ".use") changes end
        else
          let val exit = dir ^ "/exit.sml"
              val () = write (exit, "val () = OS.Process.exit OS.Process.success\n")
          in fn changes => run ([program] @ sources @ [exit]) "" changes end
    in
      if host = "mlton" orelse host = "mlkit" then
        let
          val () = write (f ".mlb", "$(SML_LIB)/basis/basis.mlb\n" ^ String.concat (List.map (fn p => p ^ "\n") sources))
          val changes = if host = "mlkit" then [("SML_LIB", library)] else []
          val (code, msgs) = execute dir ([program, if host = "mlton" then "-output" else "-o", name, name ^ ".mlb"], "", changes, f ".err")
          fun again changes = run [f ""] "" changes
          val (status, output) = if code = 0 then again [] else (code, "")
        in {built = code = 0, status = status, output = output, messages = msgs, again = again} end
      else
        let
          val again = session ()
          val (status, output) = again []
          val bad = if host = "polyml" then ["Error-", "Exception-", "Static Errors", ": error:"]
                    else ["Error:", "uncaught exception"]
          val built = not (List.exists (fn s => String.isSubstring s output) bad)
        in {built = built, status = status, output = output, messages = output, again = again} end
    end

  (* Session chatter removed exactly as run-hosts.sh removed it. *)
  fun libraryOutput host text =
    let
      val prefixes =
        if String.isPrefix "smlnj" host then
          ["[", "Standard ML", "val ", "- ", "structure ", "signature ", "type ", "datatype ", "exception ", "fun "]
        else if host = "polyml" then ["val ", "structure ", "signature ", "type ", "datatype ", "exception ", "fun ", "> "]
        else []
      val raw = if text = "" then [] else String.fields (fn c => c = #"\n") text
      val raw = if String.isSuffix "\n" text then List.take (raw, length raw - 1) else raw
    in String.concat (List.map (fn l => l ^ "\n")
         (List.filter (fn l => not (List.exists (fn p => String.isPrefix p l) prefixes)) raw)) end
end
