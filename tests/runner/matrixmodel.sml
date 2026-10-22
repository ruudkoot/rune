(* Shared compiler/library/target identities. Resolution probes tools, but
   never starts a suite or interprets its printed summary. *)
structure MatrixModel =
struct
  open Sh
  exception Invalid of string
  datatype library = RuneBasis | NativeBasis of string | HostOnRune of string | RuneOnHost of string
  datatype target = Stack | Registers | Jit | Native | Windows of int * bool | Linux32 of bool
                  | PowerPC64 of bool | AArch64
  datatype compiler = Rune of string | Host of Hosts.host
  type config = {spec : string, id : string, library : library, target : target,
                 compiler : compiler, command : string, vm : string, extra : string, version : string}
  fun need (ok, message) = if ok then () else raise Invalid message
  fun executable path = OS.FileSys.access (path, [OS.FileSys.A_EXEC]) andalso not (isDir path) handle OS.SysErr _ => false
  fun find program =
    if String.isSubstring "/" program then fromRoot program else
      case List.find executable (List.map (fn dir => OS.Path.concat (if dir = "" then "." else dir, program))
                    (String.fields (fn c => c = #":") (env ("PATH", "")))) of
        SOME path => OS.FileSys.fullPath path | NONE => program
  fun host name : Hosts.host =
    let val () = need (List.exists (fn h => h = name) Hosts.names, "unknown host " ^ name)
        val previous = Hosts.get name
        val program = case List.find (fn (n, _, _) => n = name) Hosts.settings of
              SOME (_, variable, _) => env (variable, #program previous) | NONE => raise Invalid ("unknown host " ^ name)
        val program = find program
        val library = if name = "mlkit" then env ("MLKIT_LIB", OS.Path.dir (OS.Path.dir program) ^ "/lib/mlkit") else #library previous
    in {name = name, program = program, library = library} end
  val nativeHosts = Hosts.names
  fun validSpec spec =
    case String.fields (fn c => c = #":") spec of ["rune"] => true
    | [kind, name] => if kind = "native" orelse kind = "xc1" then List.exists (fn h => h = name) nativeHosts
        else if kind = "xc2" then name <> "smlnj32" andalso List.exists (fn h => h = name) nativeHosts
        else kind = "rune" andalso List.exists (fn target => name = target)
          ["stack", "new", "jit", "opt", "windows", "windows32", "windows-new", "windows32-new",
           "linux32", "linux32-new", "ppc64", "ppc64-new", "aarch64-new"]
    | _ => false
  fun expand text =
    let fun one "hosts" = List.map (fn h => "native:" ^ h) nativeHosts
          | one "xc1" = List.map (fn h => "xc1:" ^ h) nativeHosts
          | one "xc2" = List.map (fn h => "xc2:" ^ h) ["mlton", "mlkit", "smlnj-legacy", "smlnj-dev", "polyml"]
          | one "all" = "rune" :: one "hosts" @ one "xc1"
          | one "windows" = ["rune:windows", "rune:windows32", "rune:windows-new", "rune:windows32-new"]
          | one "portability" = ["rune:linux32", "rune:ppc64", "rune:linux32-new", "rune:ppc64-new", "rune:aarch64-new"]
          | one name = [name]
    in List.concat (List.map one (String.tokens (fn c => c = #"," orelse Char.isSpace c) text)) end
  fun trial dir label envf command =
    let val () = mkdirs dir
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 60, fileSize = SOME (16 * 1024 * 1024), core = SOME 0} envf
          {cmd = command, dir = SOME root, stdin = "", stdout = dir ^ "/" ^ label ^ ".out",
           stderr = dir ^ "/" ^ label ^ ".err", timeout = 30}
    in (status, read (dir ^ "/" ^ label ^ ".out"), read (dir ^ "/" ^ label ^ ".err")) end
  fun first text = case String.fields (fn c => c = #"\n") text of line :: _ => line | [] => ""
  fun version dir (h : Hosts.host) =
    let val name = #name h
        val args = if name = "mlton" then [] else if name = "polyml" then ["-v"]
                   else if name = "mlkit" then ["--version"] else ["@SMLversion"]
        val (_, output, _) = trial dir "version" (fn e => e) (#program h :: args)
        val prefix = if name = "mlton" then "MLton " else if name = "polyml" then "Poly/ML "
                     else if name = "mlkit" then "MLKit v" else "sml "
        val line = first output
        val tail = if String.isPrefix prefix line then String.extract (line, size prefix, NONE)
                   else if String.isPrefix "smlnj" name then line else ""
        val value = Substring.string (Substring.takel (fn c => Char.isDigit c orelse c = #".") (Substring.full tail))
    in need (value <> "" andalso Char.isDigit (String.sub (value, 0)), "cannot identify " ^ name ^ " at " ^ #program h); value end
  fun resolve {timing, directory} spec : config =
    let
      val (kind, name) = case String.fields (fn c => c = #":") spec of [kind] => (kind, "") | [kind, name] => (kind, name)
                         | _ => raise Invalid ("unknown configuration " ^ spec)
      val directory = directory ^ "/" ^ String.translate (fn #":" => "_" | c => str c) spec
      fun path (variable, fallback) = find (env (variable, fromRoot fallback))
      fun rune target compiler vm =
        {spec = spec, id = spec, library = RuneBasis, target = target, compiler = Rune compiler,
         command = compiler, vm = vm, extra = "", version = ""} : config
      val stackCompiler = path ("RUNE", "bin/rune-stack")
      val registerCompiler = path ("RUNE_NEW", "bin/rune")
      fun stack target vm = rune target stackCompiler vm
      fun register target vm = rune target registerCompiler vm
      val result =
        case (kind, name) of
          ("rune", "") => if timing then register Registers (path ("RUNEVM_NEW", "bin/runevm"))
                          else stack Stack (path ("RUNEVM", "bin/runevm-stack"))
        | ("rune", "stack") => stack Stack (path ("RUNEVM", "bin/runevm-stack"))
        | ("rune", "new") => register Registers (path ("RUNEVM_NEW", "bin/runevm"))
        | ("rune", "jit") => register Jit (path ("RUNEVM_NEW_JIT", "bin/runevm-opt"))
        | ("rune", "opt") => stack Native (path ("RUNEVM_OPT", "bin/runevm-native"))
        | ("rune", "windows") => stack (Windows (64, false)) (path ("RUNEVM_WINDOWS", "bin/runevm-stack.exe"))
        | ("rune", "windows32") => stack (Windows (32, false)) (path ("RUNEVM_WINDOWS32", "bin/runevm-stack32.exe"))
        | ("rune", "windows-new") => register (Windows (64, true)) (path ("RUNEVM_NEW_WINDOWS", "bin/runevm.exe"))
        | ("rune", "windows32-new") => register (Windows (32, true)) (path ("RUNEVM_NEW_WINDOWS32", "bin/runevm32.exe"))
        | ("rune", "linux32") => stack (Linux32 false) (path ("RUNEVM_LINUX32", "bin/runevm-stack32"))
        | ("rune", "ppc64") => stack (PowerPC64 false) (path ("RUNEVM_PPC64", "bin/runevm-stack-ppc64"))
        | ("rune", "linux32-new") => register (Linux32 true) (path ("RUNEVM_NEW_LINUX32", "bin/runevm32"))
        | ("rune", "ppc64-new") => register (PowerPC64 true) (path ("RUNEVM_NEW_PPC64", "bin/runevm-ppc64"))
        | ("rune", "aarch64-new") => register AArch64 (path ("RUNEVM_NEW_AARCH64", "bin/runevm-aarch64"))
        | ("native", _) => native directory spec NativeBasis name
        | ("xc1", _) => native directory spec RuneOnHost name
        | ("xc2", _) =>
            let val () = need (name <> "smlnj32", "xc2 does not support smlnj32")
                val h = host name
                val v = version directory h
                val installation = OS.Path.dir (OS.Path.dir (#program h))
                val extra = if name = "mlton" then installation ^ "/lib/mlton"
                            else if name = "mlkit" then #library h else installation
                val compiler = path ("RUNE", "bin/rune")
            in {spec = spec, id = spec ^ "@" ^ v, library = HostOnRune name, target = Registers, compiler = Rune compiler,
                command = compiler, vm = path ("RUNEVM", "bin/runevm"), extra = extra, version = v} end
        | _ => raise Invalid ("unknown configuration " ^ spec)
      val () = need (executable (#command result), "missing compiler " ^ #command result)
      val () = case #compiler result of Host _ => () | Rune _ => need (executable (#vm result), "missing VM " ^ #vm result)
      val foreign = case #target result of Windows _ => true | Linux32 _ => true | PowerPC64 _ => true | AArch64 => true | _ => false
      val () = if not foreign then () else
        let val (status, _, _) = trial directory "vm-start" (fn e => e) [#vm result, "--version"]
        in need (status = 0, "VM will not start here: " ^ #vm result) end
    in result end
  and native directory spec library name : config =
    let val () = need (List.exists (fn h => h = name) nativeHosts, "unknown host " ^ name)
        val h = host name
        val v = version directory h
    in {spec = spec, id = spec ^ "@" ^ v, library = library name, target = Native, compiler = Host h,
        command = #program h, vm = if name = "mlkit" then #library h else "", extra = "", version = v} end
  fun row ({spec, id, library, compiler, command, vm, extra, ...} : config) =
    let val (kind, host) = case String.fields (fn c => c = #":") spec of [kind] => (kind, "")
                          | [kind, name] => (kind, name) | _ => raise Invalid "malformed resolved spec"
    in String.concatWith "\t" [id, kind, host, command, vm, extra] ^ "\n" end
  fun resolveAll options specs =
    let val configs = List.map (resolve options) (expand specs)
        val ids = List.map #id configs
        val () = need (List.all (fn id => length (List.filter (fn x => id = x) ids) = 1) ids, "duplicate configuration selection")
    in configs end
  (* A resolved table is the controller/worker protocol. Reading it performs
     no availability probes, so listing or starting a worker never re-runs a
     compiler or changes the selected configuration set. *)
  fun parseRow timing line : config =
    case String.fields (fn c => c = #"\t") line of [id, kind, name, command, vm, extra] =>
      let val parts = String.fields (fn c => c = #"@") id
          val spec = hd parts
          val version = case parts of [_] => "" | [_, version] => version | _ => raise Invalid "malformed host version"
          val () = need (spec = kind ^ (if name = "" then "" else ":" ^ name), "inconsistent resolved configuration")
          val () = need (validSpec spec, "unknown resolved configuration " ^ spec)
          val native = kind = "native" orelse kind = "xc1"
          val () = need (not native orelse List.exists (fn h => h = name) Hosts.names, "unknown resolved native host")
          val library = case kind of "rune" => RuneBasis | "native" => NativeBasis name
                           | "xc1" => RuneOnHost name | "xc2" => HostOnRune name | _ => raise Invalid "unknown resolved library"
          val compiler = if native then Host {name = name, program = command, library = vm} else Rune command
          val target = if native then Native else if kind = "xc2" then Registers else
            case name of "" => if timing then Registers else Stack
              | "stack" => Stack | "new" => Registers | "jit" => Jit | "opt" => Native
              | "windows" => Windows (64, false) | "windows32" => Windows (32, false)
              | "windows-new" => Windows (64, true) | "windows32-new" => Windows (32, true)
              | "linux32" => Linux32 false | "linux32-new" => Linux32 true
              | "ppc64" => PowerPC64 false | "ppc64-new" => PowerPC64 true | "aarch64-new" => AArch64
              | _ => raise Invalid "unknown resolved target"
      in {spec = spec, id = id, library = library, compiler = compiler, target = target,
          command = command, vm = vm, extra = extra, version = version} end
    | _ => raise Invalid "malformed resolved configuration table"
end
