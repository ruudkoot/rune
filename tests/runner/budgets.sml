(* Deterministic performance budgets. Measured arguments and output names
   retain the old spellings: the compiler counts the strings it reads. *)
structure Budgets =
struct
  open Sh
  exception Failed of string
  datatype mode = Registers | Stack
  type config = {mode : mode, compiler : string, vm : string}
  fun need (ok, message) = if ok then () else raise Failed message
  fun integer text =
    case IntInf.scan StringCvt.DEC Substring.getc (Substring.full text) of
      SOME (n, rest) => if Substring.isEmpty rest then n else raise Failed ("not an integer: " ^ text)
    | NONE => raise Failed ("not an integer: " ^ text)
  fun readLines file =
    let val text = read file
        val ls = String.fields (fn c => c = #"\n") text
    in if text = "" then [] else if String.isSuffix "\n" text then List.take (ls, length ls - 1) else ls end
  fun values name key =
    List.map (fn line => String.extract (line, size key + 1, NONE))
      (List.filter (String.isPrefix (key ^ " ")) (readLines (fromRoot ("tests/perf/" ^ name ^ ".budget"))))
  fun value name key = case values name key of [] => "" | [v] => v | _ => raise Failed (name ^ ": repeated " ^ key)
  fun args name key = String.tokens Char.isSpace (value name key)
  fun output Registers = "tests/out/perf" | output Stack = "tests/out/perf-stack"
  fun target Registers = "--target=registers" | target Stack = "--target=stack"
  fun compilerRbc Registers = "bin/rune.rbc" | compilerRbc Stack = "bin/rune.stack.rbc"
  fun runedocRbc Registers = "bin/runedoc.rbc" | runedocRbc Stack = "bin/runedoc.stack.rbc"
  val limits = {addressSpace = NONE, cpuTime = SOME 900, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
  fun execute name command stdout stderr =
    let val status = Children.exec limits (fn e => e)
          {cmd = command, dir = SOME root, stdin = "-", stdout = fromRoot stdout,
           stderr = fromRoot stderr, timeout = 900}
    in need (status = 0, name ^ ": exit " ^ Int.toString status ^ ": " ^ firstLine (fromRoot stderr)) end
  fun expand pattern =
    if not (CharVector.exists (fn c => c = #"*" orelse c = #"?") pattern) then [pattern] else
      let val dir = OS.Path.dir pattern
          val names = sort (entries (fromRoot (if dir = "" then "." else dir)))
          val names = List.filter (fn name => Expectations.glob (OS.Path.file pattern, name)) names
      in if null names then [pattern] else List.map (fn name => if dir = "" then name else dir ^ "/" ^ name) names end
  fun counters file =
    let
      fun parse line = case String.tokens Char.isSpace line of
          ["runevm:", "count:", i, "instructions,", b, "bytes,", o', "objects"] =>
            if line = "runevm: count: " ^ i ^ " instructions, " ^ b ^ " bytes, " ^ o' ^ " objects"
               andalso List.all (fn s => s <> "" andalso CharVector.all Char.isDigit s) [i, b, o']
            then SOME (List.map integer [i, b, o']) else NONE
        | _ => NONE
    in case List.rev (List.mapPartial parse (readLines file)) of
         counts :: _ => counts | [] => raise Failed (file ^ ": no counters") end
  fun measure ({mode, compiler, vm} : config) name argv =
    let
      val out = output mode
      val prefix = out ^ "/" ^ name
      val () = mkdirs (fromRoot out)
      val () = List.app (fn suffix => rmTree (fromRoot (prefix ^ suffix))) [".stdout", ".stderr", ".out.rbc", ".rbc"]
      val generated = args name "generate"
      val () = if null generated then () else
        (execute name (["python3", "tests/perf/gen.py"] @ generated) (prefix ^ ".gen.sml") (prefix ^ ".generate.err");
         need (exists (fromRoot (prefix ^ ".gen.sml")) andalso OS.FileSys.fileSize (fromRoot (prefix ^ ".gen.sml")) > 0,
               name ^ ": generator produced no program"))
      val doc = args name "runedoc"
      val compile = args name "compile"
      fun boot () =
        let val () = execute name ["sh", "scripts/build-files.sh", "rune.build"] (prefix ^ ".sources") (prefix ^ ".sources.err")
        in "build/config.sml" :: String.tokens Char.isSpace (read (fromRoot (prefix ^ ".sources"))) @ ["src/main/rune-main.sml"] end
      fun file "@boot" = boot () | file "@gen" = [prefix ^ ".gen.sml"] | file path = [path]
      val () =
        if not (null doc) then
          (execute name ([vm, "--count", "--heap-size", "67108864", runedocRbc mode, "--lib", "lib"]
                           @ List.concat (List.map expand doc)) (prefix ^ ".stdout") (prefix ^ ".stderr");
           need (OS.FileSys.fileSize (fromRoot (prefix ^ ".stdout")) > 0, name ^ ": runedoc printed nothing"))
        else if not (null compile) then
          (execute name ([vm, "--count", "--heap-size", "67108864", compilerRbc mode, "--lib", "lib", target mode,
                           "-o", prefix ^ ".out.rbc"] @ List.concat (List.map file compile)) (prefix ^ ".stdout") (prefix ^ ".stderr");
           need (List.exists (fn arg => arg = "--typecheck-only") compile orelse
                    (exists (fromRoot (prefix ^ ".out.rbc")) andalso OS.FileSys.fileSize (fromRoot (prefix ^ ".out.rbc")) > 0),
                 name ^ ": compile produced no bytecode"))
        else
          (execute name [compiler, target mode, "tests/perf/" ^ name ^ ".sml", "-o", prefix ^ ".rbc"]
                       (prefix ^ ".compile.out") (prefix ^ ".stderr");
           need (exists (fromRoot (prefix ^ ".rbc")) andalso OS.FileSys.fileSize (fromRoot (prefix ^ ".rbc")) > 0,
                 name ^ ": compiler produced no bytecode");
           execute name ([vm, "--count", prefix ^ ".rbc"] @ argv) (prefix ^ ".stdout") (prefix ^ ".stderr"))
    in counters (fromRoot (prefix ^ ".stderr")) end
  fun budgetPath Registers name = "tests/perf/" ^ name ^ ".budget"
    | budgetPath Stack name = "tests/perf/stack/" ^ name ^ ".budget"
  val keys = ["instructions", "bytes", "objects"]
  fun limit file key =
    case List.filter (String.isPrefix (key ^ " ")) (readLines (fromRoot file)) of
      [line] => integer (String.extract (line, size key + 1, NONE))
    | [] => raise Failed (file ^ ": no " ^ key ^ " budget")
    | _ => raise Failed (file ^ ": repeated " ^ key ^ " budget")
  fun update file counts =
    let
      val file = fromRoot file
      val () = mkdirs (OS.Path.dir file)
      val kept = List.filter (fn line => not (List.exists (fn key => String.isPrefix (key ^ " ") line) keys))
                   (if exists file then readLines file else [])
      val rows = List.map (fn (key, n) => key ^ " " ^ IntInf.toString (n + IntInf.div (n, 10))) (ListPair.zip (keys, counts))
      val mode = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.irgrp,
                                      Posix.FileSys.S.iwgrp, Posix.FileSys.S.iroth, Posix.FileSys.S.iwoth]
      val stem = file ^ ".tmp." ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
      fun reserve i =
        let val path = stem ^ "." ^ Int.toString i
            val fd = Posix.FileSys.createf (path, Posix.FileSys.O_WRONLY, Posix.FileSys.O.flags [Posix.FileSys.O.excl], mode)
        in Posix.IO.close fd; path end
        handle e as OS.SysErr (_, SOME code) => if code = Posix.Error.exist andalso i < 100 then reserve (i + 1) else raise e
      val tmp = reserve 0
      fun publish () = (write (tmp, String.concat (List.map (fn line => line ^ "\n") (kept @ rows)));
                         OS.FileSys.rename {old = tmp, new = file})
    in publish () handle e => (rmTree tmp; raise e) end
  fun scaleExponent (i1, i4) =
    if i1 <= 0 orelse i4 <= 0 then NONE else
      SOME (Real.fmt (StringCvt.FIX (SOME 2))
        (Math.ln (Real.fromLargeInt (IntInf.toLarge i4) / Real.fromLargeInt (IntInf.toLarge i1)) / Math.ln 4.0))
  fun one (config as {mode, ...} : config) writes name =
    let
      val () = need (not (mode = Stack andalso value name "nostack" <> ""), name ^ ": no stack measurement")
      val counts = measure config name (args name "args")
      val expected = fromRoot ("tests/perf/" ^ name ^ ".expected")
      val () = need (not (exists expected) orelse same (fromRoot (output mode ^ "/" ^ name ^ ".stdout"), expected),
                     name ^ ": checksum differs from expected")
      val file = budgetPath mode name
      val () = if writes then update file counts else ()
      val () = List.app (fn (key, actual) =>
                 need (actual <= limit file key, name ^ ": " ^ IntInf.toString actual ^ " " ^ key ^ ", budget " ^ IntInf.toString (limit file key)))
                   (ListPair.zip (keys, counts))
      val scale = args name "scale"
      val growth = case scale of [] => ""
        | [n, exponent] =>
            let val i1 = hd (measure config name [n])
                val i4 = hd (measure config name [IntInf.toString (integer n * 4)])
                val grown = case scaleExponent (i1, i4) of SOME s => s | NONE => raise Failed (name ^ ": scale run counted no instructions")
                val expected = case Real.fromString exponent of SOME r => r | NONE => raise Failed "invalid scale exponent"
                val actual = valOf (Real.fromString grown)
                val () = need (actual <= expected + 0.15, name ^ ": instructions grow with n^" ^ grown ^ ", expected n^" ^ exponent)
            in ", n^" ^ grown end
        | _ => raise Failed (name ^ ": scale expects N EXPONENT")
    in say ("ok   " ^ name ^ ": " ^ String.concatWith " " (List.map (fn (key, n) => IntInf.toString n ^ " " ^ key)
                  (ListPair.zip (keys, counts))) ^ growth ^ "\n") end
  fun protect name f () = f () handle Failed message => say ("FAIL " ^ name ^ ": " ^ message ^ "\n")
  fun config mode : config =
    {mode = mode, compiler = env ("RUNE", "bin/rune"),
     vm = env ("RUNEVM", case mode of Registers => "bin/runevm" | Stack => "bin/runevm-stack")}
  fun names () = List.map (OS.Path.base o OS.Path.file) (glob (fromRoot "tests/perf", ".budget"))
  fun parsedMode "stack" = Stack | parsedMode "register" = Registers | parsedMode _ = raise Failed "unknown budget mode"
  fun command ["budget-one", way, name] = SOME (protect name (fn () => one (config (parsedMode way)) false name))
    | command _ = NONE
  fun main argv =
    let
      fun parse ([], mode, writes, filter) = (mode, writes, filter)
        | parse ("--stack" :: rest, _, writes, filter) = parse (rest, Stack, writes, filter)
        | parse ("--new" :: rest, _, writes, filter) = parse (rest, Registers, writes, filter)
        | parse ("--update" :: rest, mode, _, filter) = parse (rest, mode, true, filter)
        | parse (arg :: rest, mode, writes, _) =
            if String.isPrefix "-" arg then raise Failed "usage: rune-budget [--stack|--new] [--update] [FILTER]"
            else parse (rest, mode, writes, arg)
      val (mode, writes, filter) = parse (argv, Registers, false, "")
      val here = OS.FileSys.getDir ()
      fun fromCaller p = if String.isSubstring "/" p andalso not (OS.Path.isAbsolute p) andalso exists p
                         then OS.Path.concat (here, p) else p
      fun tool (key, fallback) = case OS.Process.getEnv key of
          SOME p => if p = "" then fallback else fromCaller p | NONE => fallback
      val c = {mode = mode, compiler = tool ("RUNE", "bin/rune"),
               vm = tool ("RUNEVM", if mode = Stack then "bin/runevm-stack" else "bin/runevm")} : config
      val selected = List.filter (fn name => String.isSubstring filter name andalso
                      not (mode = Stack andalso value name "nostack" <> "")) (names ())
      val failed = ref false
      fun run name = one c writes name handle Failed message => (failed := true; say ("FAIL " ^ name ^ ": " ^ message ^ "\n"))
      val () = List.app run selected
    in if !failed then Posix.Process.exit 0w1 else say "perf-check: within budget\n" end
  fun job (way, name) =
    let val vm = if way = "stack" then "${RUNEVM:-bin/runevm-stack}" else "${RUNEVM_REGISTER:-bin/runevm}"
        val needs = if null (args name "generate") then [] else ["python3"]
    in Test.requires needs (Test.it name {program = "/bin/sh", args = ["sh", "-c", "RUNEVM=\"" ^ vm
          ^ "\" exec \"$RUNE_TEST_ROOT\"/bin/rune-budget budget-one " ^ way ^ " " ^ quote name],
        env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800,
        cap = 0, cpus = 1, memory = 1000, pools = [], exclusive = false, after = [], judge = failLines}) : Run.command Test.tree end
  fun tree () =
    let val names = names ()
        fun mode (way, names) = Test.describe way (List.map (fn name => job (way, name)) names)
    in Test.tag "check" (Test.tag "perf-check" (Test.tag "covers:tests/perf/*"
      (Test.describe "budgets" [mode ("register", names), mode ("stack", List.filter (fn name => value name "nostack" = "") names)]))) end
end
