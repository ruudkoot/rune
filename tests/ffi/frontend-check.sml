(* Independent compiler comparisons for the reusable SML C frontend. *)
structure CFrontendChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok, s) = if ok then () else raise Failed s
  fun field name value = case Json.member (name, value) of SOME v => v | NONE => raise Failed ("missing " ^ name)
  fun string (Json.String s) = s | string _ = raise Failed "expected JSON string"
  fun array (Json.Array vs) = vs | array _ = raise Failed "expected JSON array"
  fun json path = Json.decode (read path)
  val directory = run ^ "/c-frontend/" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  fun command name args =
    let val () = mkdirs directory
        val out = directory ^ "/" ^ name ^ ".out"
        val err = directory ^ "/" ^ name ^ ".err"
        val status = Children.exec Subprocess.unlimited (fn e => e)
          {cmd = args, dir = SOME root, stdin = "", stdout = out, stderr = err, timeout = 600}
        val errors = List.filter (String.isSubstring "error:") (lines (read err))
        val summary = if null errors then List.take (lines (read err), Int.min (12, length (lines (read err))))
                      else List.take (errors, Int.min (12, length errors))
        val () = need (status = 0, name ^ " exited " ^ Int.toString status ^ ": " ^ String.concatWith "\n" summary ^ " (see " ^ err ^ ")")
    in out end
  fun significant ts = List.filter (fn (t : CLex.token) => #kind t <> CLex.Newline) ts
  fun comparable ts =
    let fun strip [] = []
          | strip ((hash : CLex.token) :: pragma :: kind :: rest) =
            if #text hash = "#" andalso #text pragma = "pragma" then
              let fun line ([], acc) = (rev acc, [])
                    | line (t :: ts, acc) = if #kind t = CLex.Newline then (rev acc, ts) else line (ts, t :: acc)
                  val (body, after) = line (kind :: rest, [])
              in (if #text kind = "pack" then hash :: pragma :: body else []) @ strip after end
            else hash :: strip (pragma :: kind :: rest)
          | strip (t :: rest) = t :: strip rest
    in List.map #text (significant (strip ts)) end
  fun oracleTokens path = CLex.scan {file = path, text = read path}
  fun definitions value = List.map (fn entry => case array entry of [n, v] => (string n, string v)
      | _ => raise Failed "invalid predefinition") (array (field "predefined" value))
  fun preprocess defs roots source = CPreprocess.run {source = CFiles.read source, predefined = defs,
    resolve = CFiles.resolver roots, width = 64, maxDepth = 256, maxExpansions = 10000000}
  fun fixture () =
    let val input = fromRoot "tests/ffi/preprocess.h"
        val own = preprocess [] [] input
        val compiler = String.tokens Char.isSpace (env ("CC", "cc"))
        val reference = command "fixture" (compiler @ ["-E", "-P", "-std=c11", "-undef", "-nostdinc", "-x", "c", input])
        val () = need (comparable (#tokens own) = comparable (oracleTokens reference), "C fixture preprocessing differs")
    in say "PASS C frontend: fixture agrees with independent C preprocessor\n" end
  fun functions declarations =
    let fun function (CParse.Attributed (base, _)) = function base
          | function (CParse.Function {parameters, variadic, ...}) = SOME (length parameters, variadic)
          | function _ = NONE
    in List.mapPartial (fn CParse.Declaration {name = SOME name, ctype, ...} =>
          (case function ctype of SOME shape => SOME (name, shape) | NONE => NONE) | _ => NONE) declarations end
  fun astFunctions value =
    let val here = case (Json.member ("kind", value), Json.member ("name", value)) of
          (SOME (Json.String "FunctionDecl"), SOME (Json.String name)) =>
            let val children = case Json.member ("inner", value) of SOME v => array v | NONE => []
                val count = length (List.filter (fn c => Json.member ("kind", c) = SOME (Json.String "ParmVarDecl")) children)
                val variadic = Json.member ("variadic", value) = SOME (Json.Bool true)
            in [(name, (count, variadic))] end
        | _ => []
        val below = case Json.member ("inner", value) of SOME (Json.Array vs) => List.concat (List.map astFunctions vs) | _ => []
    in here @ below end
  fun astConstants value =
    let fun integer v = case Json.member ("value", v) of SOME (Json.String n) => IntInf.fromString n
          | _ => case Json.member ("inner", v) of SOME (Json.Array vs) =>
              let fun first [] = NONE | first (x :: xs) = case integer x of NONE => first xs | some => some
              in first vs end | _ => NONE
        val here = case (Json.member ("kind", value), Json.member ("name", value)) of
          (SOME (Json.String "EnumConstantDecl"), SOME (Json.String name)) =>
            if String.isPrefix "runeffi_probe_constant_" name then
              (case integer value of SOME n => [(name, n)] | NONE => raise Failed ("missing Clang constant value: " ^ name)) else []
        | _ => []
        val below = case Json.member ("inner", value) of SOME (Json.Array vs) => List.concat (List.map astConstants vs) | _ => []
    in here @ below end
  fun header library target =
    let val () = mkdirs directory
        val profile = json (fromRoot ("ffi/targets/" ^ target ^ ".json"))
        val defs = definitions profile
        val windows = String.isPrefix "windows-" target
        val roots = if windows then
            let val sdk = env ("RUNEFFI_WINDOWS_SDK", "")
                val msvc = env ("RUNEFFI_MSVC_INCLUDE", "")
                val () = need (sdk <> "" andalso msvc <> "", "set RUNEFFI_WINDOWS_SDK and RUNEFFI_MSVC_INCLUDE; see ffi/win32/README.md")
            in List.map (fn d => sdk ^ "/" ^ d) ["um", "shared", "ucrt"] @ [msvc] end
          else
            let val compiler = String.tokens Char.isSpace (env ("CC", "cc"))
                val standardRoot = Hosts.trim (read (command "include-root" (compiler @ ["-print-file-name=include"])))
            in [standardRoot, "/usr/include/x86_64-linux-gnu", "/usr/include"] end
        val roots = (if library = "sdl" then [fromRoot "ffi/sdl/upstream"] else []) @ roots
        val inventory = json (fromRoot ("ffi/" ^ library ^ "/inventory.json"))
        val headers = List.map string (array (field "headers" inventory))
        val constants = List.map (string o field "foreign") (array (field "constants" inventory))
        fun probe n = "runeffi_probe_constant_" ^ Int.toString n
        val input = directory ^ "/input.c"
        val () = write (input, String.concat (List.map (fn h => "#include <" ^ h ^ ">\n") headers)
          ^ (if windows andalso library = "win32" then
              "_Static_assert(_Generic((LONGLONG)0, long long:1, default:0), \"LONGLONG must be integral\");\n" else "")
          ^ "enum runeffi_constant_probe {\n" ^ String.concatWith ",\n"
              (ListPair.map (fn (n, name) => probe n ^ " = " ^ name) (List.tabulate (length constants, fn n => n), constants)) ^ "\n};\n")
        val config = directory ^ "/predefined.h"
        val () = write (config, String.concat (List.map (fn (n, v) => "#define " ^ n ^ " " ^ v ^ "\n") defs))
        val own = preprocess defs roots input
        val declarations = #declarations (CParse.translationUnit {tokens = #tokens own, predefinedTypes = []})
        val clang = String.tokens Char.isSpace (env ("CLANG", "clang"))
        val flags = ["-std=c11", "-target", string (field "triple" profile), "-undef", "-nostdinc",
          "-Wno-builtin-macro-redefined", "-Wno-nonportable-include-path", "-Wno-ignored-attributes"]
          @ (if windows then ["-fms-extensions", "-fms-compatibility", "-fms-compatibility-version=19.40"] else [])
          @ List.concat (List.map (fn root => ["-I", root]) roots) @ ["-include", config]
        val reference = command "preprocess" (clang @ flags @ ["-E", "-P", input])
        val () = need (comparable (#tokens own) = comparable (oracleTokens reference), "header preprocessing differs from Clang")
        val ast = json (command "ast" (clang @ flags @ ["-fsyntax-only", "-Xclang", "-ast-dump=json", input]))
        val native = astFunctions ast
        val ownFunctions = functions declarations
        val selected = List.map (string o field "foreign") (array (field "entries" inventory))
        fun unique source name = case List.filter (fn (n, _) => n = name) source of [(_, shape)] => shape
          | [] => raise Failed ("missing selected function " ^ name) | _ => raise Failed ("ambiguous selected function " ^ name)
        val () = List.app (fn name => need (unique ownFunctions name = unique native name, "Clang declaration shape differs: " ^ name)) selected
        val values = astConstants ast
        val environment = CEnumConst.collect declarations
        val () = ListPair.app (fn (n, name) =>
          let val own = CEnumConst.evaluate {environment = environment, width = 64, name = probe n}
              val expected = case List.find (fn (key, _) => key = probe n) values of SOME (_, value) => value
                | NONE => raise Failed ("missing Clang constant " ^ name)
          in need (#integer own = expected, "Clang constant value differs: " ^ name) end) (List.tabulate (length constants, fn n => n), constants)
    in say ("PASS C frontend: " ^ library ^ " " ^ target ^ ": " ^ Int.toString (length (#dependencies own)) ^
        " original files, " ^ Int.toString (length declarations) ^ " declarations, " ^ Int.toString (length selected) ^
        " functions and " ^ Int.toString (length constants) ^ " constants agree with Clang\n") end
  fun main ["fixture"] = fixture ()
    | main ["headers", library, target] = header library target
    | main _ = raise Failed "expected fixture or headers LIBRARY TARGET"
end
val () = CFrontendChecks.main (CommandLine.arguments ()) handle e =>
  (TextIO.output (TextIO.stdErr, "FAIL C frontend: " ^ (case e of CFrontendChecks.Failed s => s | _ => General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)
