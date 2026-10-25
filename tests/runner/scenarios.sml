(* Ordered build/dependency scenarios. Commands are argument vectors; fixture
   creation, rebuild sets, diagnostics and byte comparisons are SML values. *)
structure Scenarios =
struct
  open Sh
  exception Failed of string
  type context = {directory : string, compiler : string, vm : string}
  type result = {status : int, output : string, errors : string}
  fun need (ok, why) = if ok then () else raise Failed why
  fun create name compiler : context =
    {directory = run ^ "/scenarios/" ^ name, compiler = fromRoot compiler,
     vm = OS.Path.dir (fromRoot compiler) ^ "/runevm"}
  fun put ({directory, ...} : context) path text =
    let val file = directory ^ "/" ^ path
    in mkdirs (OS.Path.dir file); write (file, text ^ "\n") end
  fun reset (c : context) = (rmTree (#directory c); mkdirs (#directory c))
  fun execute (c : context) name working args : result =
    let val log = #directory c ^ "/logs/" ^ name
        val () = mkdirs (OS.Path.dir log)
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 600,
                                    fileSize = SOME (1024 * 1024 * 1024), core = SOME 0}
          (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"])
          {cmd = args, dir = SOME (if OS.Path.isAbsolute working then working else #directory c ^ (if working = "" then "" else "/" ^ working)),
           stdin = "", stdout = log ^ ".out", stderr = log ^ ".err", timeout = 600}
    in {status = status, output = read (log ^ ".out"), errors = read (log ^ ".err")} end
  fun compiler c name working args = execute c name working (#compiler c :: args)
  fun program c name working args = execute c name working (#vm c :: args)
  fun success (r : result) = need (#status r = 0, "command failed (" ^ Int.toString (#status r) ^ "): " ^ #errors r)
  fun refused (r : result) message = need ((#status r = 1 orelse #status r = 255) andalso String.isSubstring message (#errors r ^ #output r),
                                          "expected refusal: " ^ message ^ "; got " ^ #errors r ^ #output r)
  fun output (r : result) expected = (success r; need (#output r = expected andalso #errors r = "",
           "expected output " ^ String.toString expected ^ ", got " ^ String.toString (#output r ^ #errors r)))
  fun bytecode file = need (exists file andalso OS.FileSys.fileSize file > 0, "compiler produced no bytecode: " ^ file)
  fun rebuilt text = List.mapPartial (fn line => if String.isPrefix "rune: compiled " line then
           SOME (Substring.string (#1 (Substring.position ":" (Substring.full (String.extract (line, 15, NONE)))))) else NONE) (lines text)
  fun depsPrepare c () =
    (reset c;
     List.app (fn (file, text) => put c file text)
      [("order/a.sml", "structure A = struct val x = 1 end"),
       ("order/b.sml", "structure B = struct val y = A.x + 1 end"),
       ("order/c.sml", "signature C = sig val z : int end  functor F (X : C) = struct val w = B.y + X.z end"),
       ("cycle/x.sml", "structure X = struct val a = Y.b end"),
       ("cycle/y.sml", "structure Y = struct val b = 1 val c = X.a end"),
       ("twice/p.sml", "structure P = struct end"), ("twice/q.sml", "structure P = struct val again = 1 end"),
       ("broken/m.sml", "structure M = struct end\nval top = 1"),
       ("entry/main.sml", "val () = print (Int.toString B.y ^ \"\\n\")"),
       ("entry/lib/a.sml", "structure A = struct val x = 40 end"),
       ("entry/lib/b.sml", "structure B = struct val y = A.x + 2 end"),
       ("entry/lib/u.sml", "structure U = struct val nothing = () end"),
       ("entry/lib/z.sml", "structure Z = struct end\nval zero = 0"),
       ("entry/needs-z.sml", "structure Use = Z")])
  fun deps c which () =
    case which of
      "order" => output (compiler c which "order" ["--deps", "c.sml", "b.sml", "a.sml"]) "a.sml\nb.sml\nc.sml\n"
    | "dot" => let val r = compiler c which "order" ["--deps-dot", "c.sml", "b.sml", "a.sml"]
               in success r; need (String.isSubstring "\"c.sml\" -> \"b.sml\"" (#output r)
                         andalso String.isSubstring "\"b.sml\" -> \"a.sml\"" (#output r), "incorrect dependency graph") end
    | "cycle" => refused (compiler c which "cycle" ["--deps", "x.sml", "y.sml"]) "a cycle: x.sml -> y.sml -> x.sml"
    | "duplicate" => refused (compiler c which "twice" ["--deps", "p.sml", "q.sml"]) "structure P is declared by p.sml and by q.sml"
    | "discipline" => refused (compiler c which "broken" ["--deps", "m.sml"])
          "m.sml:2:1: error: a file of a group declares modules and type abbreviations only, and this is a value"
    | "entry" =>
        let val target = #directory c ^ "/entry/p.rbc"
            val () = rmTree target
            val r = compiler c which "entry" ["--units", "--no-cache", "--explain-rebuild", "-I", "lib", "main.sml", "-o", "p.rbc"]
            val () = success r
            val () = bytecode target
            val compiled = List.filter (fn file => String.isPrefix "lib/" file orelse file = "main.sml") (rebuilt (#errors r))
            val () = need (compiled = ["lib/a.sml", "lib/b.sml", "main.sml"], "incorrect entry-point dependency closure")
        in output (program c "entry-run" "entry" ["p.rbc"]) "42\n" end
    | "broken-required-file" => refused (compiler c which "entry" ["-I", "lib", "needs-z.sml", "-o", "z.rbc"])
          "lib/z.sml declares a module needs-z.sml names, and breaks the discipline"
    | _ => raise Failed "unknown dependency scenario"
  val depsCases = ["order", "dot", "cycle", "duplicate", "discipline", "entry", "broken-required-file"]
  val factorial = "265252859812191058636308480000000\n~2\n16158687986375067893760000\nequal\n"
  fun buildPrepare c () =
    let val () = reset c
        val () = List.app (fn (file, text) => put c file text)
          [("a.sml", "structure A = struct val x = 40 end"),
           ("b.sml", "structure B = struct val y = A.x + 2 end"),
           ("main.sml", "val () = print (Int.toString B.y ^ \"\\n\")"),
           ("uses-a.sml", "val () = print (Int.toString A.x ^ \"\\n\")"),
           ("list.build", "a.sml b.sml main.sml"),
           ("local.build", "local a.sml in b.sml end main.sml"),
           ("local-hidden.build", "local a.sml in b.sml end uses-a.sml"),
           ("library.build", "library (structure B) = a.sml b.sml end main.sml"),
           ("library-hidden.build", "library (structure B) = a.sml b.sml end uses-a.sml"),
           ("main-mod.sml", "structure M = struct val z = B.y end"),
           ("group.build", "group main-mod.sml b.sml a.sml end main.sml"),
           ("counted.sml", "structure C = struct val () = print \"once\\n\" val c = 1 end"),
           ("lib/counted.build", "counted.sml"),
           ("use-twice.build", "use lib/counted.build use lib/counted.build use-c.sml"),
           ("use-c.sml", "val () = print (Int.toString C.c ^ \"\\n\")"),
           ("prim.sml", "val ok = _prim \"rt_version\" : unit -> string"),
           ("prim.build", "prim.sml main.sml"),
           ("prim-allowed.build", "annotate \"allowPrim\" in prim.sml end a.sml b.sml main.sml"),
           ("vars.build", "$(VENDOR)/a.sml $(VENDOR)/b.sml main.sml"),
           ("bad.build", "local a.sml"), ("self.build", "use self.build")]
        val dir = #directory c
        fun copy source destination = write (destination, read source)
        val () = copy (dir ^ "/counted.sml") (dir ^ "/lib/counted.sml")
        val () = mkdirs (dir ^ "/vendor")
        val () = List.app (fn file => copy (dir ^ "/" ^ file) (dir ^ "/vendor/" ^ file)) ["a.sml", "b.sml"]
        val original = fromRoot "examples/virtual/bigint"
        val () = mkdirs (dir ^ "/bigint")
        val () = List.app (fn file => if isDir (original ^ "/" ^ file) then () else copy (original ^ "/" ^ file) (dir ^ "/bigint/" ^ file)) (entries original)
        val () = put c "bigint/none.build" "bigint_sig.sml bigint.sml main.sml"
        val () = put c "bigint/two.build" "bigint_sig.sml implements BigInt = intinf.sml end implements BigInt = digits.sml end bigint.sml main.sml"
    in () end
  fun builds c label source flags expected =
    let val target = #directory c ^ "/" ^ source ^ ".rbc"
        val () = rmTree target
        val result = compiler c label "" (["--build", source ^ ".build", "--no-cache"] @ flags @ ["-o", source ^ ".rbc"])
        val () = success result
        val () = bytecode target
    in output (program c (label ^ "-run") "" [source ^ ".rbc"]) expected end
  fun buildRefused c source message =
    (rmTree (#directory c ^ "/" ^ source ^ ".rbc");
     refused (compiler c source "" ["--build", source ^ ".build", "--no-cache", "-o", source ^ ".rbc"]) message)
  fun build c which () =
    case which of
      "list" => builds c which "list" [] "42\n"
    | "local" => builds c which "local" [] "42\n"
    | "local-hidden" => buildRefused c which "unbound variable or constructor: A.x"
    | "library" => builds c which "library" [] "42\n"
    | "library-hidden" => buildRefused c which "unbound variable or constructor: A.x"
    | "group" => builds c which "group" [] "42\n"
    | "use-twice" => builds c which "use-twice" [] "once\n1\n"
    | "prim" => buildRefused c which "_prim"
    | "prim-allowed" => builds c which "prim-allowed" [] "42\n"
    | "path-variable" => builds c which "vars" ["--path", "VENDOR=vendor"] "42\n"
    | "missing-variable" => buildRefused c "vars" "no path variable VENDOR"
    | "build-list" => output (compiler c which "" ["--build-list", "group.build"]) "a.sml\nb.sml\nmain-mod.sml\nmain.sml\n"
    | "virtual-intinf" => builds c which "bigint/intinf" [] factorial
    | "virtual-digits" => builds c which "bigint/digits" [] factorial
    | "virtual-cache" =>
        let val dir = #directory c
            val () = rmTree (dir ^ "/vcache")
            val first = compiler c "virtual-cache-first" "" ["--build", "bigint/intinf.build", "--cache-dir", "vcache", "-o", "vcache1.rbc"]
            val () = success first
            val second = compiler c "virtual-cache-second" "" ["--build", "bigint/digits.build", "--cache-dir", "vcache", "--explain-rebuild", "-o", "vcache2.rbc"]
            val () = success second
            val compiled = List.filter (String.isPrefix "bigint/") (rebuilt (#errors second))
            val () = need (compiled = ["bigint/digits.sml"], "switching virtual implementation rebuilt an unrelated unit")
            val () = bytecode (dir ^ "/vcache2.rbc")
        in output (program c "virtual-cache-run" "" ["vcache2.rbc"]) factorial end
    | "virtual-whole" =>
        let val target = #directory c ^ "/vwhole.rbc"
            val () = rmTree target
            val result = compiler c which "" ["--build", "bigint/digits.build", "--whole", "-o", "vwhole.rbc"]
        in success result; bytecode target; output (program c (which ^ "-run") "" ["vwhole.rbc"]) factorial end
    | "virtual-none" =>
        let val target = #directory c ^ "/vnone.rbc"
            val () = rmTree target
            val compiled = compiler c which "" ["--build", "bigint/none.build", "--no-cache", "-o", "vnone.rbc"]
            val () = success compiled
            val () = bytecode target
            val result = program c (which ^ "-run") "" ["vnone.rbc"]
        in need ((#status result = 1 orelse #status result = 2) andalso
                 String.isSubstring "virtual module BigInt has no implementation" (#output result ^ #errors result),
                 "unimplemented virtual module was not rejected") end
    | "virtual-two" => buildRefused c "bigint/two" "two implementations"
    | "bad" => buildRefused c "bad" "unexpected end of the file"
    | "self" => buildRefused c "self" "uses itself"
    | _ => raise Failed "unknown buildfile scenario"
  val buildCases = ["list", "local", "local-hidden", "library", "library-hidden", "group", "use-twice", "prim", "prim-allowed",
                    "path-variable", "missing-variable", "build-list", "virtual-intinf", "virtual-digits", "virtual-cache", "virtual-whole",
                    "virtual-none", "virtual-two", "bad", "self"]
  fun copy source destination =
    let val input = BinIO.openIn source
        val output = BinIO.openOut destination
        fun loop () = let val bytes = BinIO.inputN (input, 65536)
                      in if Word8Vector.length bytes = 0 then () else (BinIO.output (output, bytes); loop ()) end
        fun close () = (BinIO.closeIn input; BinIO.closeOut output)
    in (loop (); close ()) handle e => (close (); raise e) end
  fun emit c name sources =
    let val dir = #directory c
        val () = rmTree (dir ^ "/" ^ name ^ ".units")
        val () = rmTree (dir ^ "/" ^ name ^ ".rbu")
        val result = compiler c (name ^ "-module") "" (["--units", "--no-cache", "--emit-units", name ^ ".units"]
                                                    @ sources @ ["-o", name ^ ".whole.rbc"])
        val () = success result
        val unitList = dir ^ "/" ^ name ^ ".units/units"
        val () = need (exists unitList, "module compiler published no unit list")
        val suffix = "-" ^ OS.Path.base (OS.Path.file (List.last sources)) ^ ".rbu"
        val files = List.filter (String.isSuffix suffix) (lines (read unitList))
        val unit = case files of [file] => if OS.Path.isAbsolute file then file else dir ^ "/" ^ file
                             | _ => raise Failed "module compiler published an ambiguous entry unit"
    in bytecode unit; copy unit (dir ^ "/" ^ name ^ ".rbu") end
  val shape = "signature SHAPE =\nsig\n  type t\n  datatype kind = Round | Square of int\n  exception Bad of int\n"
      ^ "  val make : int -> t\n  val area : t -> int\n  val kindOf : t -> kind\n  val name : string\n  val twice : 'a -> 'a * 'a\nend"
  val implementation = "_export structure Impl : SHAPE =\nstruct\n  datatype kind = Square of int | Round\n"
      ^ "  type t = int * kind\n  exception Bad of int\n  fun make n = if n < 0 then raise Bad n else (n, if n > 5 then Round else Square n)\n"
      ^ "  fun area (n, _) = n * n\n  fun kindOf (_, k) = k\n  val name = \"impl\"\n  fun twice x = (x, x)\nend"
  val client = "structure S = _dynamic \"impl.rbu\" : SHAPE\nfun kind k = case k of S.Round => \"round\" | S.Square n => \"square \" ^ Int.toString n\n"
      ^ "val () = print (S.name ^ \" \" ^ Int.toString (S.area (S.make 3)) ^ \" \" ^ kind (S.kindOf (S.make 3)) ^ \" \"\n"
      ^ "                ^ kind (S.kindOf (S.make 7)) ^ \"\\n\")\nval () = print (#1 (S.twice \"poly\") ^ \"\\n\")\n"
      ^ "val () = (ignore (S.make ~4); print \"no raise\\n\") handle S.Bad n => print (\"Bad \" ^ Int.toString n ^ \"\\n\")"
  fun linked c name sources =
    let val target = #directory c ^ "/" ^ name ^ ".rbc"
        val () = rmTree target
        val result = compiler c (name ^ "-client") "" (["--units", "--no-cache"] @ sources @ ["-o", name ^ ".rbc"])
    in success result; bytecode target end
  fun shapeModule c =
    (put c "shape.sml" shape; put c "impl.sml" implementation; emit c "impl" ["shape.sml", "impl.sml"])
  fun dynamicReload c jit =
    let val dir = #directory c
        val () = List.app (fn (file, text) => put c file text)
           [("live.sml", "signature LIVE = sig val version : unit -> string val step : int -> int end"),
            ("v1.sml", "_export structure V : LIVE = struct fun version () = \"v1\" fun step n = n + 1 end"),
            ("v2.sml", "_export structure V : LIVE = struct fun version () = \"v2\" fun step n = n * 2 end"),
            ("v3.sml", "signature LIVE = sig val version : unit -> string end\n_export structure V : LIVE = struct fun version () = \"v3\" end"),
            ("reload.sml", "structure L = _dynamic \"live.rbu\" : LIVE\nfun copy (a, b) =\n"
               ^ "  let val i = BinIO.openIn a val v = BinIO.inputAll i val () = BinIO.closeIn i\n"
               ^ "      val out = BinIO.openOut b in BinIO.output (out, v); BinIO.closeOut out end\n"
               ^ "fun loop (0, acc) = acc | loop (n, acc) = loop (n - 1, L.step acc)\nval kept = L.version\n"
               ^ "val () = print (L.version () ^ \" \" ^ Int.toString (loop (10, 0)) ^ \"\\n\")\n"
               ^ "val () = copy (\"v2.rbu\", \"live.rbu\")\nval () = Dynamic.reload \"live.rbu\"\n"
               ^ "val () = print (L.version () ^ \" \" ^ Int.toString (loop (10, 1)) ^ \" \" ^ kept () ^ \"\\n\")\n"
               ^ "val () = copy (\"v3.rbu\", \"live.rbu\")\n"
               ^ "val () = (Dynamic.reload \"live.rbu\"; print \"reloaded\\n\") handle Dynamic.Mismatch _ => print \"mismatch\\n\"\n"
               ^ "val () = print (L.version () ^ \"\\n\")")]
        val () = emit c "v1" ["live.sml", "v1.sml"]
        val () = emit c "v2" ["live.sml", "v2.sml"]
        val () = emit c "v3" ["v3.sml"]
        val () = linked c "reload" ["live.sml", "reload.sml"]
        val () = copy (dir ^ "/v1.rbu") (dir ^ "/live.rbu")
    in output (program c "reload-run" "" ((if jit then ["--jit=all"] else []) @ ["reload.rbc"])) "v1 10\nv2 1024 v1\nmismatch\nv2\n" end
  fun dynamic c which () =
    let val () = reset c
        val dir = #directory c
        fun run name flags expected = output (program c (name ^ "-run") "" (flags @ [name ^ ".rbc"])) expected
        fun replace text from into =
          let val (left, right) = Substring.position from (Substring.full text)
          in need (not (Substring.isEmpty right), "dynamic fixture replacement is missing");
             Substring.string left ^ into ^ Substring.string (Substring.triml (size from) right) end
    in case which of
      "link" => (shapeModule c; put c "client.sml" client; linked c "client" ["shape.sml", "client.sml"];
                   run "client" [] "impl 9 square 3 round\npoly\nBad ~4\n")
    | "link-jit" => (shapeModule c; put c "client.sml" client; linked c "client" ["shape.sml", "client.sml"];
                   run "client" ["--jit=all"] "impl 9 square 3 round\npoly\nBad ~4\n")
    | "mismatch" =>
        (shapeModule c; put c "client.sml" client; linked c "client" ["shape.sml", "client.sml"];
         put c "other.sml" (replace shape "val area : t -> int" "val area : t -> real" ^ "\n"
            ^ "_export structure Other : SHAPE =\nstruct\n  datatype kind = Round | Square of int\n  type t = int\n"
            ^ "  exception Bad of int\n  fun make n = n\n  fun area n = real n\n  fun kindOf _ = Round\n"
            ^ "  val name = \"other\"\n  fun twice x = (x, x)\nend");
         emit c "other" ["other.sml"]; copy (dir ^ "/other.rbu") (dir ^ "/impl.rbu");
         let val result = program c "mismatch" "" ["client.rbc"]
         in need (#status result = 1 andalso String.isSubstring "Mismatch \"impl.rbu implements another signature" (#output result ^ #errors result),
                  "dynamic signature mismatch was not rejected") end)
    | "plugin" =>
        (put c "registry.sml" "structure Registry = struct val plugins : (string * (int -> int)) list ref = ref [] end";
         put c "plugin.sml" "val () = Registry.plugins := (\"double\", fn x => 2 * x) :: !Registry.plugins";
         put c "host.sml" "val () = Dynamic.load \"plugin.rbu\"\nval () = List.app (fn (n, f) => print (n ^ \" \" ^ Int.toString (f 21) ^ \"\\n\")) (!Registry.plugins)";
         emit c "plugin" ["registry.sml", "plugin.sml"]; linked c "host" ["registry.sml", "host.sml"]; run "host" [] "double 42\n")
    | "shared-types" =>
        (List.app (fn (file, text) => put c file text)
           [("lib.sml", "structure Lib = struct datatype pt = P of int * int end"),
            ("maker.sml", "signature MAKER = sig val make : int -> Lib.pt end"),
            ("measurer.sml", "signature MEASURER = sig val norm : Lib.pt -> int end"),
            ("mk.sml", "_export structure Mk : MAKER = struct fun make n = Lib.P (n, n + 1) end"),
            ("ms.sml", "_export structure Ms : MEASURER = struct fun norm (Lib.P (a, b)) = a * a + b * b end"),
            ("both.sml", "structure M = _dynamic \"mk.rbu\" : MAKER\nstructure N = _dynamic \"ms.rbu\" : MEASURER\nval () = print (Int.toString (N.norm (M.make 3)) ^ \"\\n\")")];
         emit c "mk" ["lib.sml", "maker.sml", "mk.sml"]; emit c "ms" ["lib.sml", "measurer.sml", "ms.sml"];
         linked c "both" ["lib.sml", "maker.sml", "measurer.sml", "both.sml"]; run "both" [] "25\n")
    | "whole-refused" => (put c "shape.sml" shape; put c "client.sml" client;
          refused (compiler c which "" ["shape.sml", "client.sml", "-o", "whole.rbc"]) "is built in units (rune --units)")
    | "reload" => dynamicReload c false
    | "reload-jit" => dynamicReload c true
    | "abstract-reload" =>
        (shapeModule c;
         put c "noreload.sml" ("structure S = _dynamic \"impl.rbu\" : SHAPE\nval kept = S.make 3\n"
          ^ "val () = (Dynamic.reload \"impl.rbu\"; print \"reloaded\\n\")\n"
          ^ "         handle Dynamic.Mismatch m => print (if String.isSubstring \"abstract type\" m then \"refused\\n\" else m ^ \"\\n\")\n"
          ^ "val () = print (Int.toString (S.area kept) ^ \"\\n\")");
         linked c "noreload" ["shape.sml", "noreload.sml"]; run "noreload" [] "refused\n9\n")
    | _ => raise Failed "unknown dynamic module scenario"
    end
  val dynamicCases = ["link", "link-jit", "mismatch", "plugin", "shared-types", "whole-refused", "reload", "reload-jit", "abstract-reload"]
  val targets = ["registers", "stack"]
  fun targetVM "registers" = fromRoot "bin/runevm"
    | targetVM "stack" = fromRoot "bin/runevm-stack"
    | targetVM _ = raise Failed "unknown unit target"
  fun unitNames () = List.filter (fn name => isDir (fromRoot ("tests/units/" ^ name))) (sort (entries (fromRoot "tests/units")))
  fun unitPrefix c name build target = #directory (c : context) ^ "/" ^ name ^ "." ^ build ^ "." ^ target
  fun unitSources name =
    let val dir = "tests/units/" ^ name
        val path = fromRoot (dir ^ "/files")
        val () = need (exists path, "unit fixture has no source list: " ^ name)
    in List.map (fn file => dir ^ "/" ^ file) (lines (read path)) end
  (* the compiler's flags of a fixture, from its `flags` where it has one,
     in every build of it *)
  fun unitFlags name =
    let val path = fromRoot ("tests/units/" ^ name ^ "/flags")
    in if exists path then String.tokens Char.isSpace (read path) else [] end
  fun unitsPrepare c () =
    (reset c; List.app (fn target =>
       let val output = #directory c ^ "/load." ^ target ^ ".rbc"
           val result = compiler c ("loader-" ^ target) root ["--target=" ^ target, "tests/units/load.sml", "-o", output]
           val save = #directory c ^ "/loadsave." ^ target ^ ".rbc"
           val result2 = compiler c ("loadsave-" ^ target) root ["--target=" ^ target, "tests/units/loadsave.sml", "-o", save]
           val inventory = #directory c ^ "/inventory." ^ target ^ ".rbc"
           val result3 = compiler c ("inventory-" ^ target) root ["--target=" ^ target, "tests/units/inventory.sml", "-o", inventory]
       in success result; bytecode output; success result2; bytecode save;success result3;bytecode inventory end) targets)
  fun unitBuild c name build target () =
    let val prefix = unitPrefix c name build target
        val units = build = "units"
        val () = need (units orelse build = "whole", "unknown unit build mode")
        val () = rmTree (prefix ^ ".rbc")
        val () = if units then rmTree (prefix ^ ".files") else ()
        val flags = ["--target=" ^ target] @ (if units then ["--units", "--cache-dir", #directory c ^ "/cache",
                               "--emit-units", prefix ^ ".files"] else [])
        val compiled = compiler c (name ^ "-" ^ build ^ "-" ^ target ^ "-compile") root
                                 (flags @ unitFlags name @ unitSources name @ ["-o", prefix ^ ".rbc"])
        val () = write (prefix ^ ".compile-status", Int.toString (#status compiled) ^ "\n")
        val result = if #status compiled <> 0 then {status = 0, output = "", errors = ""} : result else
                       (bytecode (prefix ^ ".rbc"); execute c (name ^ "-" ^ build ^ "-" ^ target ^ "-run") root
                                                             [targetVM target, prefix ^ ".rbc"])
        val got = #errors compiled ^ "compile: " ^ Int.toString (#status compiled) ^ "\n"
                  ^ (if #status compiled = 0 then #output result ^ #errors result ^ "run: " ^ Int.toString (#status result) ^ "\n" else "")
        val () = write (prefix ^ ".got", got)
        val want = fromRoot ("tests/units/" ^ name ^ "/" ^ (if not units andalso exists (fromRoot ("tests/units/" ^ name ^ "/whole.expected"))
                                  then "whole.expected" else "expected"))
        val () = need (exists want andalso read want = got, "unit fixture differs: " ^ name ^ "/" ^ build ^ "/" ^ target)
        val () = if #status compiled <> 0 then () else
             (write (prefix ^ ".output", #output result); write (prefix ^ ".run-status", Int.toString (#status result) ^ "\n"))
    in () end
  fun unitFiles prefix =
    let val path = prefix ^ ".files/units"
        val () = need (exists path, "unit producer published no file list")
    in List.map fromRoot (lines (read path)) end
  fun unitLoad c name target () =
    let val prefix = unitPrefix c name "units" target
        val result = execute c (name ^ "-loaded-" ^ target) root
                    ([targetVM target, #directory c ^ "/load." ^ target ^ ".rbc"] @ unitFiles prefix)
    in need (#output result = read (prefix ^ ".output") andalso Int.toString (#status result) ^ "\n" = read (prefix ^ ".run-status"),
             "loaded unit output/status differs: " ^ name ^ "/" ^ target) end
  fun unitWarm c name target () =
    let val prefix = unitPrefix c name "units" target
        val () = rmTree (prefix ^ ".warm.rbc")
        val result = compiler c (name ^ "-warm-" ^ target) root
              (["--target=" ^ target, "--units", "--cache-dir", #directory c ^ "/cache", "--explain-rebuild"]
                    @ unitFlags name @ unitSources name @ ["-o", prefix ^ ".warm.rbc"])
    in success result; need (null (rebuilt (#errors result)), "warm unit build recompiled a source: " ^ name);
       need (same (prefix ^ ".rbc", prefix ^ ".warm.rbc"), "warm unit bytecode differs: " ^ name ^ "/" ^ target) end
  val loaderCases = ["twice", "shadowed", "not-a-unit", "cut-short", "not-loaded", "other-compile", "other-set", "inventory", "saved", "restored"]
  fun loader c target which () =
    let val files = unitFiles (unitPrefix c "twice" "units" target)
        fun part ([], _) = raise Failed "unit fixture has no named unit"
          | part (file :: rest, suffix) = if String.isSuffix suffix file then ([], file, rest)
              else let val (prefix, found, suffixes) = part (rest, suffix) in (file :: prefix, found, suffixes) end
        val (basis, a, afterA) = part (files, "-a.rbu")
        val (_, b, last) = part (afterA, "-b.rbu")
        val vm = targetVM target
        val load = #directory c ^ "/load." ^ target ^ ".rbc"
        fun run args = execute c ("loader-" ^ which ^ "-" ^ target) root (vm :: load :: args)
        fun loaded (result : result) expected =
          let val errors = List.filter (fn line => not (String.isPrefix "  in " line)) (lines (#errors result))
              val text = #output result ^ String.concat (List.map (fn line => line ^ "\n") errors)
                         ^ "status " ^ Int.toString (#status result) ^ "\n"
          in need (text = expected, "unit loader differs: " ^ which ^ "/" ^ target ^ ": " ^ text) end
        fun refused (result : result) message = need (#status result = 1 andalso String.isPrefix message (#errors result),
                                                      "unit loader did not refuse " ^ which ^ ": " ^ #errors result)
        val image = #directory c ^ "/loaded." ^ target ^ ".img"
    in case which of
      "twice" => loaded (run (basis @ [a, b, b] @ last)) "1\n2\nstatus 0\n"
    | "shadowed" => loaded (run (basis @ [a, b, a, b] @ last)) "1\n1\nstatus 0\n"
    | "not-a-unit" => loaded (run (basis @ [fromRoot "tests/units/load.sml"]))
                            "runevm: uncaught exception Fail \"Runtime.link: not a unit of Rune bytecode\"\nstatus 1\n"
    | "cut-short" =>
        let val source = BinIO.openIn a
            val bytes = BinIO.inputN (source, 100)
            val () = BinIO.closeIn source
            val path = #directory c ^ "/cut." ^ target ^ ".rbu"
            val stream = BinIO.openOut path
            val () = BinIO.output (stream, bytes)
            val () = BinIO.closeOut stream
        in refused (run (basis @ [path])) "runevm: uncaught exception Fail \"Runtime.link: " end
    | "not-loaded" => refused (run [b]) "runevm: uncaught exception Fail \"Runtime.link: the unit names "
    | "other-compile" =>
        let val others = unitFiles (unitPrefix c "across" "units" target)
            val (_, other, _) = part (others, "-b.rbu")
        in refused (run (basis @ [other])) "runevm: uncaught exception Fail \"Runtime.link: the unit names " end
    | "other-set" =>
        let val other = if target = "stack" then "registers" else "stack"
            val first = hd (unitFiles (unitPrefix c "twice" "units" other))
        in loaded (run [first]) "runevm: uncaught exception Fail \"Runtime.link: a unit of another instruction set\"\nstatus 1\n" end
    | "inventory" =>
        loaded (execute c ("loader-inventory-" ^ target) root
          ([vm,#directory c ^ "/inventory." ^ target ^ ".rbc"] @ basis @ [a,b]))
          "linked before executing\n1\n2\nPASS linked unit inventory\nstatus 0\n"
    | "saved" =>
        let val () = rmTree image
            val result = execute c ("loader-save-" ^ target) root
               ([vm, #directory c ^ "/loadsave." ^ target ^ ".rbc"] @ basis @ [a, "--save", image, b] @ last)
        in loaded result "status 0\n"; bytecode image end
    | "restored" => loaded (execute c ("loader-restore-" ^ target) root [vm, "--restore", image]) "1\nstatus 0\n"
    | _ => raise Failed "unknown unit loader scenario"
    end
end
