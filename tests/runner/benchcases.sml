(* Declarative replacement for the repetitive benchmark matrix wrappers.
   The captured source/data order is checked independently before execution;
   catalogue families and recursive data lists remain live inputs. *)
structure BenchCases =
struct
  open Sh
  exception Invalid of string
  datatype sources = Sources of string list | Catalogue of string
  datatype fixture = From of string | Contents of string
  datatype data = NoData | Files of string list | FileList of string | Flat | Recursive | Mapped of (string * fixture) list
  datatype policy = Fixed | Environment | Family
  type mode = {level : int option, configs : string, timeout : int option, memoryKiB : int option}
  type group = {name : string, driver : string, blob : string, aliases : string list, sources : sources,
                dataRoot : string, data : data, input : string option, policy : policy, modes : mode list}
  fun need (ok, message) = if ok then () else raise Invalid message
  fun field key (Json.Object fields) =
        (case List.filter (fn (name, _) => name = key) fields of [(_, value)] => value
          | _ => raise Invalid ("missing or repeated benchmark field " ^ key))
    | field _ _ = raise Invalid "benchmark object required"
  fun maybe key (Json.Object fields) = (case List.filter (fn (name, _) => name = key) fields of
        [] => NONE | [(_, value)] => SOME value | _ => raise Invalid ("repeated benchmark field " ^ key))
    | maybe _ _ = raise Invalid "benchmark object required"
  fun string (Json.String s) = s | string _ = raise Invalid "benchmark string required"
  fun array (Json.Array xs) = xs | array _ = raise Invalid "benchmark array required"
  fun strings value = List.map string (array value)
  fun optional f Json.Null = NONE | optional f value = SOME (f value)
  fun integer value = case Json.toInt value of SOME n => n | NONE => raise Invalid "benchmark integer required"
  fun decode text =
    let
      val root = Json.decode text
      val () = need (integer (field "format" root) = 1, "unknown benchmark case format")
      fun mode value : mode =
        {level = optional integer (field "level" value), configs = string (field "configs" value),
         timeout = optional integer (field "timeout" value), memoryKiB = optional integer (field "memoryKiB" value)}
      fun one value : group =
        let
          val source = field "sources" value
          val sources = case string (field "kind" source) of
              "literal" => Sources (strings (field "files" source))
            | "catalogue" => Catalogue (string (field "family" source))
            | _ => raise Invalid "unknown benchmark source mode"
          val data = field "data" value
          fun mapping value =
            (string (field "path" value), case (maybe "source" value, maybe "contents" value) of
                (SOME source, NONE) => From (string source) | (NONE, SOME contents) => Contents (string contents)
              | _ => raise Invalid "mapped fixture requires exactly one source or contents")
          val data = case string (field "kind" data) of
              "none" => NoData | "literal" => Files (strings (field "files" data))
            | "file" => FileList (string (field "path" data)) | "flat" => Flat | "recursive" => Recursive
            | "mapped" => Mapped (List.map mapping (array (field "files" data)))
            | _ => raise Invalid "unknown benchmark data mode"
          val policy = case string (field "configurationPolicy" value) of
              "fixed" => Fixed | "environment" => Environment | "family" => Family
            | _ => raise Invalid "unknown benchmark configuration policy"
        in {name = string (field "name" value), driver = string (field "driver" value), blob = string (field "baselineBlob" value),
            aliases = strings (field "aliases" value), sources = sources, dataRoot = string (field "dataRoot" value),
            data = data, input = optional string (field "input" value), policy = policy, modes = List.map mode (array (field "modes" value))} end
      val groups = List.map one (array (field "cases" root))
      val names = List.map #name groups
      val () = need (List.all (fn name => length (List.filter (fn n => name = n) names) = 1) names, "duplicate benchmark case name")
    in groups end
  fun readGroups () = decode (read (fromRoot "tests/runner/benchmark-cases.json"))
  fun relative path = path <> "" andalso not (OS.Path.isAbsolute path)
      andalso List.all (fn part => part <> "" andalso part <> "." andalso part <> "..") (String.fields (fn c => c = #"/") path)
      andalso not (CharVector.exists (fn c => c = #"\000" orelse c = #"\n" orelse c = #"\r") path)
  fun regular path = Posix.FileSys.ST.isReg (Posix.FileSys.stat path) handle OS.SysErr _ => false
  fun readLines file =
    let val () = need (regular file, "missing benchmark file list " ^ file)
        val text = read file
        val rows = String.fields (fn c => c = #"\n") text
    in if text = "" then [] else if String.isSuffix "\n" text then List.take (rows, length rows - 1) else rows end
  fun sourceFiles (g : group) =
    case #sources g of Sources paths => paths
    | Catalogue family =>
        let
          val () = need (List.exists (fn name => name = family) ["anna", "fluid", "hpg", "parser", "reptile", "veritas"], "unknown catalogue test family")
          val dir = run ^ "/benchmark-cases"
          val () = mkdirs dir
          val out = dir ^ "/" ^ family ^ ".catalogue"
          val status = Children.exec {addressSpace = NONE, cpuTime = SOME 120, fileSize = SOME (16 * 1024 * 1024), core = SOME 0} (fn e => e)
              {cmd = [fromRoot "bin/runevm-stack", fromRoot "build/bench-catalog.rbc", "--list", "smoke", "=" ^ family ^ "-lazy"],
               dir = SOME root, stdin = "", stdout = out, stderr = out ^ ".err", timeout = 120}
          val () = need (status = 0, "cannot read checked source order for " ^ family)
          val row = case lines (read out) of [row] => String.fields (fn c => c = #"\t") row
                  | _ => raise Invalid ("expected one checked source-order entry for " ^ family)
          val () = need (length row = 7, "malformed catalogue program row")
          val paths = List.filter (fn path => path <> family ^ "-lazy/benchmark.sml" andalso path <> "shared/main.sml")
                         (String.tokens Char.isSpace (List.nth (row, 3)))
        in ["tests/basis/harness.sml", "tests/benchmarks/application-test-io.sml"]
             @ List.map (fn path => "examples/benchmarks/" ^ path) paths
             @ ["tests/benchmarks/nofib-" ^ family ^ "-tests.sml", "tests/basis/finish.sml"] end
  fun dataFiles (g : group) =
    let
      val base = if #dataRoot g = "." then root else fromRoot (#dataRoot g)
      fun walk prefix = List.concat (List.map (fn name =>
        let val relative = if prefix = "" then name else prefix ^ "/" ^ name
            val path = base ^ "/" ^ relative
        in if isDir path then (if OS.FileSys.isLink path then [] else walk relative)
           else if regular path andalso name <> ".gitattributes" then [relative] else [] end)
          (sort (entries (if prefix = "" then base else base ^ "/" ^ prefix))))
    in case #data g of NoData => [] | Files paths => paths | FileList path => readLines (fromRoot path)
       | Mapped mappings => List.map #1 mappings
       | Flat => let val paths = sort (List.filter (fn name => not (String.isPrefix "." name)) (entries base))
                 in need (not (null paths), "empty benchmark data glob " ^ base); paths end
       | Recursive => (need (isDir base, "missing benchmark data directory " ^ base); sort (walk "")) end
  fun fixtures (g : group) = case #data g of Mapped mappings => mappings
    | _ => List.map (fn path => (path, From (if #dataRoot g = "." then path else #dataRoot g ^ "/" ^ path))) (dataFiles g)
  fun configurations (g : group) (m : mode) =
    case (#policy g, OS.Process.getEnv "BENCH_CONFIGS") of
      (Fixed, _) => #configs m | (_, NONE) => #configs m | (_, SOME "") => #configs m
    | (Family, SOME specs) => if #level m <> SOME 0 then specs else
        String.concatWith "," (List.filter (fn spec => spec <> "hosts" andalso not (String.isPrefix "native:" spec))
                                      (String.fields (fn c => c = #",") specs))
    | (_, SOME specs) => specs
  fun validate (g : group) =
    let
      val () = need (relative (#name g) andalso size (#blob g) = 40 andalso CharVector.all Char.isHexDigit (#blob g), "invalid benchmark identity")
      val () = need (List.all (fn path => relative path andalso String.isPrefix "tests/benchmarks/" path andalso String.isSuffix ".sh" path)
                        (#driver g :: #aliases g), "invalid benchmark driver ownership")
      val paths = sourceFiles g
      val () = need (not (null paths) andalso not (null (#modes g)), "empty benchmark sources or modes")
      val () = List.app (fn path => need (relative path andalso regular (fromRoot path), "missing or invalid benchmark source " ^ path)) paths
      val base = if #dataRoot g = "." then root else fromRoot (#dataRoot g)
      val () = case #data g of NoData => () | Mapped _ => () | _ => need ((#dataRoot g = "." orelse relative (#dataRoot g)) andalso isDir base,
                            "missing or invalid benchmark data directory for " ^ #name g ^ ": " ^ #dataRoot g)
      val () = List.app (fn (path, fixture) =>
          (need (relative path, "invalid benchmark data path " ^ path);
           case fixture of Contents _ => () | From source => need (relative source andalso regular (fromRoot source), "missing benchmark fixture " ^ source))) (fixtures g)
    in List.app (fn m : mode =>
      (need (case #level m of NONE => true | SOME n => n >= 0 andalso n <= 2, "invalid benchmark optimization level");
       need (case #timeout m of NONE => true | SOME n => n > 0, "invalid benchmark timeout");
       need (case #memoryKiB m of NONE => true | SOME n => n > 0, "invalid benchmark memory bound"))) (#modes g) end
end
