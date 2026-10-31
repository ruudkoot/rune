(* Final Make recipe audit: C fixtures remain independent subjects, while
   SML schedules them, bounds execution and checks every verdict. *)
structure BuildChecks =
struct
  open Sh
  fun tagged tags tree=List.foldl (fn (tag,tree) => Test.tag tag tree) tree tags
  fun job name args after=Test.it name
    {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
     env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 1800,cap=0,cpus=1,memory=1000,
     pools=[],exclusive=false,after=after,judge=failLines} : Run.command Test.tree
  fun executable name program args=Test.it name
    {program=fromRoot program,args=program::args,env=NONE,dir=SOME ".",stdin=NONE,
     timeout=Time.fromSeconds 300,cap=0,cpus=1,memory=500,pools=[],exclusive=false,after=[],judge=failLines} : Run.command Test.tree
  val portableFiles=["runtime/register/jit/emit.c","runtime/register/jit/masm.c","runtime/register/jit/masm.h","runtime/register/jit/divplan.h",
       "runtime/register/jit/compile.c","runtime/register/jit/compile.h","runtime/register/jit/dump.c","runtime/register/jit.c"]
  fun encoderFree text =
    let fun word c=Char.isAlphaNum c orelse c = #"_"
        fun starts prefix i=i<=size text-size prefix andalso String.substring (text,i,size prefix)=prefix
        fun loop i=if i=size text then true else
          if (i=0 orelse not (word (String.sub (text,i-1)))) andalso
             List.exists (fn prefix => starts prefix i) ["x64_","a64_","X64","A64"]
          then false else loop (i+1)
    in loop 0 end
  fun asmCheck ()=List.app (fn file => if exists file andalso encoderFree (read file) then () else
      say ("FAIL JIT encoder independence: " ^ file ^ " names an encoder or is missing\n")) portableFiles
  fun asmFaults ()=List.app (fn (text,expected) => if encoderFree text=expected then () else
      say ("FAIL JIT encoder guard vector: " ^ String.toString text ^ "\n"))
      [("asm_emit",true),("prefix_x64_safe",true),("x64_bad",false),(" a64_bad",false),
       ("X64",false),("A64Assembler",false),("aX64",true),("/* X64 */",false)]
  fun directory ()=let val out=run ^ "/register-jit" in mkdirs out;out end
  fun execute label args seconds =
    let val out=directory ()
    in Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (16*1024*1024),core=SOME 0} (fn e => e)
        {cmd=args,dir=SOME root,stdin="",stdout=out ^ "/" ^ label ^ ".out",stderr=out ^ "/" ^ label ^ ".err",timeout=seconds} end
  fun compile ()=if execute "compile" [fromRoot "bin/rune",fromRoot "tests/lang/rt.deeprec_stack.sml","-o",directory () ^ "/deeprec.rbc"] 600=0
       then () else say "FAIL JIT deep recursion: compilation failed\n"
  val modes=[("all",["--jit=all"]),("tiered",["--jit=baseline","--jit-calls=1","--jit-work=1","--jit-stress=3"]),
             ("callret",["--jit=all","--jit-returns=call"])]
  fun deep name =
    let val flags=case List.find (fn (label,_) => label=name) modes of SOME (_,flags) => flags | NONE => raise Fail "unknown JIT recursion mode"
        (* POSIX sh provides only the OS stack-limit operation; arguments,
           cases, deadlines and exact output checks are owned by SML. *)
        val status=execute name (["/bin/sh","-c","ulimit -s 1024 && exec \"$@\"","jit-stack",fromRoot "bin/runevm"] @ flags @ [directory () ^ "/deeprec.rbc"]) 300
    in if status=0 andalso same (directory () ^ "/" ^ name ^ ".out","tests/lang/rt.deeprec_stack.expected") then ()
       else say ("FAIL JIT deep recursion: " ^ name ^ " differs or exits unsuccessfully\n") end
  fun compilerLayout () =
    let
      val dir = run ^ "/compiler-layout"
      val () = mkdirs (dir ^ "/nested")
      val () = write (dir ^ "/root.build", "(* outer (* nested *) comment *)\nuse nested/part.build\nfiles second.sml end\nuse nested/part.build\n")
      val () = write (dir ^ "/nested/part.build", "files first.sml end\n")
      val () = write (dir ^ "/nested/first.sml", "structure First = struct end\n")
      val () = write (dir ^ "/second.sml", "structure Second = struct end\n")
      fun invoke name args =
        let val output = dir ^ "/" ^ name ^ ".out"
            val errors = dir ^ "/" ^ name ^ ".err"
            val status = exec {cmd = args, dir = SOME root, stdin = "", stdout = output, stderr = errors, timeout = 60}
        in (status, read output, read errors) end
      val (status, listed, _) = invoke "bootstrap" ["sh", fromRoot "scripts/build-files.sh", dir ^ "/root.build"]
      val expected = [dir ^ "/nested/first.sml", dir ^ "/second.sml"]
      val () = if status = 0 andalso lines listed = expected then () else say "FAIL compiler layout: bootstrap use/order differs\n"
      val (status, compiled, _) = invoke "compiler" [fromRoot (env ("RUNE", "bin/rune")), "--build-list", dir ^ "/root.build"]
      val () = if status = 0 andalso lines compiled = expected then () else say "FAIL compiler layout: compiler build-list differs\n"
      (* functors marked to be inlined across units (docs/build.md): no file
         to either list, and the manifest's # inline: line *)
      val () = write (dir ^ "/inline.build", "inline functor Make Other end\nuse nested/part.build\nfiles second.sml end\n")
      val (status, listed, _) = invoke "inline-bootstrap" ["sh", fromRoot "scripts/build-files.sh", dir ^ "/inline.build"]
      val () = if status = 0 andalso lines listed = expected then () else say "FAIL compiler layout: bootstrap list with inline functor differs\n"
      val (status, compiled, _) = invoke "inline-compiler" [fromRoot (env ("RUNE", "bin/rune")), "--build-list", dir ^ "/inline.build"]
      val () = if status = 0 andalso lines compiled = expected then () else say "FAIL compiler layout: build-list with inline functor differs\n"
      val () = write (dir ^ "/library.build", "inline functor Make Other end\nannotate \"demand\" in use nested/part.build end\n")
      val (status, _, _) = invoke "library" [fromRoot (env ("RUNE", "bin/rune")), "--basis-index", dir]
      val () = if status = 0 andalso String.isSubstring "nested/first.sml | demand" (read (dir ^ "/MANIFEST")) then ()
               else say "FAIL compiler layout: library index did not follow annotated use\n"
      val () = if String.isSubstring "\n# inline: Make Other\n" (read (dir ^ "/MANIFEST")) then ()
               else say "FAIL compiler layout: library index did not carry the inline functors\n"
      val () = write (dir ^ "/cycle.build", "use cycle.build\n")
      val (status, _, errors) = invoke "cycle" ["sh", fromRoot "scripts/build-files.sh", dir ^ "/cycle.build"]
      val ()=if status <> 0 andalso String.isSubstring "cyclic" errors then () else say "FAIL compiler layout: cyclic use was accepted\n"
      val ()=write (dir ^ "/annotated.build","annotate \"unicode\" \"allowPrim\" in use nested/annotated.build end\n")
      val ()=write (dir ^ "/nested/annotated.build","files ../unicode.sml end\n")
      val ()=write (dir ^ "/unicode.sml","val p=_prim \"print\" : string -> unit\nval \206\187=42\nval ()=p \"annotations inherited\\n\"\n")
      val (status,_,errors)=invoke "annotated-use" [fromRoot (env ("RUNE","bin/rune")),"--no-prelude",
        "--build",dir ^ "/annotated.build","-o",dir ^ "/annotated.rbc"]
      val ()=if status=0 then () else raise Fail ("build annotations lost through use: " ^ errors)
      val (status,output,errors)=invoke "annotated-program" [fromRoot "bin/runevm",dir ^ "/annotated.rbc"]
      val ()=if status=0 andalso output="annotations inherited\n" andalso errors="" then ()
        else raise Fail "annotated build program differs"
      val view=dir ^ "/native-view"
      val ()=List.app mkdirs [view ^ "/scripts",view ^ "/build",view ^ "/lib/MLB"]
      val ()=write (view ^ "/scripts/mlkit-build-root.sh",read "scripts/mlkit-build-root.sh")
      val ()=write (view ^ "/build/config.sml","structure Config = struct val identity=\"first\" end\n")
      val ()=write (view ^ "/lib/example.sml","structure Example = struct val answer=42 end\n")
      val ()=write (view ^ "/lib/MLB/protected","original cache\n")
      val ()=write (view ^ "/build/probe-mlkit.mlb","$(SML_LIB)/basis/basis.mlb\nconfig.sml\n../lib/example.sml\n")
      fun mirror label =
        let val (status,output,errors)=invoke label ["sh",view ^ "/scripts/mlkit-build-root.sh","build/probe-mlkit.mlb"]
        in if status=0 andalso output="build/mlkit-root/build/probe-mlkit.mlb\n" then () else raise Fail ("MLKit source view: " ^ errors) end
      val ()=mirror "mirror-first"
      val private=view ^ "/build/mlkit-root"
      val ()=mkdirs (private ^ "/lib/MLB")
      val ()=write (private ^ "/lib/MLB/cached","compiled with first configuration\n")
      val ()=write (view ^ "/lib/example.sml","structure Example = struct val answer=43 end\n")
      val ()=mirror "mirror-source-edit"
      val ()=if exists (private ^ "/lib/MLB/cached") andalso
        same (private ^ "/lib/example.sml",view ^ "/lib/example.sml") then () else raise Fail "MLKit view lost unchanged-configuration reuse"
      val ()=write (view ^ "/build/config.sml","structure Config = struct val identity=\"second\" end\n")
      val ()=mirror "mirror-configuration-edit"
    in if not (exists (private ^ "/lib/MLB/cached")) andalso
        read (view ^ "/lib/MLB/protected")="original cache\n" andalso
        same (private ^ "/build/config.sml",view ^ "/build/config.sml")
       then () else raise Fail "MLKit view reused stale configuration or changed original caches" end
  fun libraryExports () =
    let
      val dir = run ^ "/library-exports"
      val lib = dir ^ "/lib with spaces"
      val scoped = lib ^ "/scoped"
      val () = (rmTree dir; mkdirs scoped)
      val () = Posix.FileSys.symlink {old = fromRoot "lib/basis", new = lib ^ "/basis"}
      val fixture = "tests/lib/exports"
      val () = List.app (fn file => write (scoped ^ "/" ^ file, read (fixture ^ "/" ^ file)))
                       (entries fixture)
      fun need (ok,message) = if ok then () else raise Fail ("library exports: " ^ message)
      fun invoke label args =
        let val log = dir ^ "/" ^ label ^ ".log"
            val status = exec {cmd = [fromRoot (env ("RUNE","bin/rune")),"--lib",lib] @ args,
                              dir = SOME root, stdin = "", stdout = log, stderr = log, timeout = 120}
        in (status,read log) end
      fun compile label flags source =
        invoke label (flags @ ["--library","scoped",source,"-o",dir ^ "/" ^ label ^ ".rbc"])
      fun result label =
        let val output = dir ^ "/" ^ label ^ ".out"
            val status = exec {cmd = [fromRoot "bin/runevm",dir ^ "/" ^ label ^ ".rbc"],
                              dir = SOME root, stdin = "", stdout = output, stderr = output, timeout = 30}
        in need (status=0 andalso read output="87\n",label ^ " has wrong output") end
      val (status,log) = invoke "index" ["--basis-index",scoped]
      val () = need (status=0,"cannot index scoped library: " ^ log)
      val manifest = read (scoped ^ "/MANIFEST")
      val () = need (String.isSubstring "structure:Api signature:API functor:Make type:exposed" manifest,"missing export metadata")
      val (status,log) = invoke "check" ["--library","scoped","--basis-check"]
      val () = need (status=0,"scoped manifest check: " ^ log)
      val modes = [("whole",["--no-cache"]),("units",["--units","--no-cache"]),
                   ("whole-units",["--units","--whole","--no-cache"])]
      fun mode (label,flags) =
        let val (status,log) = compile label flags (fixture ^ "/use.sml")
            val () = need (status=0,label ^ " does not compile: " ^ log)
            val () = result label
            fun rejected (file,reason) =
              let val (status,log) = compile (label ^ "-" ^ basename file) flags (fixture ^ "/" ^ file)
              in need (status<>0 andalso String.isSubstring reason log,label ^ " accepted " ^ file ^ ": " ^ log) end
        in List.app rejected [("private-use.sml","Hidden.value"),("private-signature.sml","unbound signature: PRIVATE"),
                              ("private-type.sml","unbound type constructor: private"),
                              ("generative-reject.sml","type constructor mismatch")] end
      val () = List.app mode modes
      val cache = ["--units","--cache-dir",dir ^ "/cache"]
      val (status,log) = compile "cold" cache (fixture ^ "/use.sml")
      val () = need (status=0,"cold cache: " ^ log)
      val (status,log) = compile "warm" ("--verify-cache" :: cache) (fixture ^ "/use.sml")
      val () = need (status=0 andalso same (dir ^ "/cold.rbc",dir ^ "/warm.rbc"),"verified cache differs: " ^ log)
      val () = result "warm"
      val () = write (dir ^ "/type-only.sml","val x : exposed = 3\n")
      val (status,log) = invoke "type-deps" ["--library","scoped","--basis-deps",dir ^ "/type-only.sml"]
      val () = need (status=0 andalso String.isSubstring "/type.sml" log andalso
                     not (String.isSubstring "/public.sml" log) andalso not (String.isSubstring "/functor.sml" log),
                     "selection ignored public demand boundaries")
      fun scopeLine line =
        if String.isPrefix "#" line orelse line="" then line
        else String.concatWith "|" (List.take (String.fields (fn c => c = #"|") line,5) @ [" structure:Missing"])
      val () = write (scoped ^ "/MANIFEST",String.concatWith "\n" (List.map scopeLine (String.fields (fn c => c = #"\n") manifest)))
      val (status,log) = invoke "missing-export" ["--library","scoped","--basis-check"]
      val () = need (status<>0 andalso String.isSubstring "exports structure Missing" log,"undeclared manifest export accepted")
      val () = write (scoped ^ "/MANIFEST",manifest)
      val build = read (scoped ^ "/library.build")
      val () = write (scoped ^ "/library.build","library (structure Missing) = use entries.build end\n")
      val (status,log) = invoke "bad-index" ["--basis-index",scoped]
      val () = need (status<>0 andalso String.isSubstring "exports structure Missing" log andalso
                     read (scoped ^ "/MANIFEST")=manifest,"invalid index replaced a valid manifest")
      val () = write (scoped ^ "/library.build",build)
      val consumer = lib ^ "/consumer"
      val () = mkdirs consumer
      val () = write (consumer ^ "/library.build","libraries scoped end\nlibrary (structure Consumer) = consumer.sml end\n")
      val () = write (consumer ^ "/consumer.sml","structure Consumer = struct val value = Api.value end\n")
      val (status,log) = invoke "consumer-index" ["--basis-index",consumer]
      val () = need (status=0,"consumer index: " ^ log)
      val () = write (dir ^ "/consumer-use.sml","val value = Consumer.value\n")
      fun consumerMode (label,flags) =
        let val (status,log) = invoke (label ^ "-consumer") (flags @ ["--library","consumer",dir ^ "/consumer-use.sml","-o",dir ^ "/" ^ label ^ "-consumer.rbc"])
        in need (status=0,"public dependency cannot be used: " ^ log) end
      val () = List.app consumerMode modes
      val () = write (consumer ^ "/consumer.sml","structure Consumer = struct val public = Api.value val private = Hidden.value end\n")
      val (status,_) = invoke "private-consumer-index" ["--basis-index",consumer]
      val () = need (status=0,"cannot index private-reference rejection fixture")
      fun privateConsumer (label,flags) =
        let val (status,log) = invoke (label ^ "-private-consumer")
              (flags @ ["--library","consumer",dir ^ "/consumer-use.sml","-o",dir ^ "/rejected.rbc"])
        in need (status<>0 andalso String.isSubstring "Hidden.value" log,"private dependency leaked into another library") end
    in List.app privateConsumer modes end
  fun compilerApi () =
    let
      val dir=run ^ "/compiler-api"
      val ()=(rmTree dir;mkdirs dir)
      val foreign=dir ^ "/foreign"
      val ()=mkdirs (foreign ^ "/basis")
      val ()=List.app (fn name =>
        if name="MANIFEST" orelse String.isSuffix ".sml" name then
          write (foreign ^ "/basis/" ^ name,read ("lib/basis/" ^ name) ^
            (if name="runeexit.sml" then "\n(* different source, same exported interface *)\n" else "")) else ())
        (entries "lib/basis")
      fun need (true,_) = () | need (false,message) = raise Fail ("compiler API: " ^ message)
      fun invoke label args =
        let val output=dir ^ "/" ^ label ^ ".out"
            val errors=dir ^ "/" ^ label ^ ".err"
            val status=exec {cmd=args,dir=SOME root,stdin="",stdout=output,stderr=errors,timeout=600}
        in (status,read output,read errors) end
      fun compile (label,flags,source) =
        let val (status,_,errors)=invoke (label ^ "-compile")
          ([fromRoot (env ("RUNE","bin/rune")),"--library","compiler"] @ flags @ [source,"-o",dir ^ "/" ^ label ^ ".rbc"])
        in need (status=0,"compilation failed: " ^ errors) end
      val ()=compile ("execute",["--units","--emit-units",dir ^ "/host-units"],"tests/compiler/api-execution.sml")
      val hostUnit=case List.find (String.isSuffix "-runeexit.rbu") (entries (dir ^ "/host-units")) of
        SOME file => dir ^ "/host-units/" ^ file | NONE => raise Fail "compiler API: host unit fixture missing"
      val (status,_,errors)=invoke "frozen"
        [fromRoot (env ("RUNE","bin/rune")),"--library","compiler","--units","--cache-dir",dir ^ "/cache",
         "--explain-rebuild","tests/compiler/api-execution.sml","-o",dir ^ "/frozen.rbc"]
      val ()=need (status=0 andalso not (List.exists
        (String.isPrefix "rune: compiled lib/compiler/") (lines errors)),
        "frozen compiler units were rebuilt: " ^ errors)
      val expected="before explicit run\n2\n3\nPASS compiler API execution\ncompiled finalizer\nhost finalizer\n"
      fun runMode (name,flags) =
        let val (status,output,errors)=invoke name ([fromRoot "bin/runevm"] @ flags @ [dir ^ "/execute.rbc",dir,foreign,hostUnit])
        in need (status=0 andalso output=expected andalso errors="",name ^ " execution differs: " ^ output ^ errors) end
      val ()=List.app runMode [("interpreter",["--jit=off"]),("jit",["--jit=all"])]
      val (status,output,errors)=invoke "program" [fromRoot "bin/runevm",dir ^ "/program.rbc"]
      val ()=need (status=0 andalso output="compiled finalizer\n" andalso errors="","written program/finalizer order differs: " ^ output ^ errors)
      val ()=compile ("whole",[],"tests/compiler/api-whole.sml")
      val (status,output,errors)=invoke "whole" [fromRoot "bin/runevm",dir ^ "/whole.rbc"]
      val ()=need (status=0 andalso output="PASS whole host execution refusal\n" andalso errors="","whole-host guard differs")
      val (status,_,errors)=invoke "cli-unit"
        [fromRoot (env ("RUNE","bin/rune")),"--units","--no-prelude","--no-cache","--emit-units",dir ^ "/cli-units",
         "tests/compiler/api-cli-source.sml","-o",dir ^ "/cli.rbc"]
      val ()=need (status=0,"CLI unit producer failed: " ^ errors)
      val input=dir ^ "/cli-units/0000-api-cli-source.rbu"
      val ()=need (exists input andalso not (exists (dir ^ "/cli-units/0000-api-cli-source.rbs")),"CLI compatibility fixture is not a plain unit")
      val ()=compile ("import",[],"tests/compiler/api-import.sml")
      val (status,output,errors)=invoke "import"
        [fromRoot "bin/runevm",dir ^ "/import.rbc",input,dir ^ "/imported.rbc"]
      val ()=need (status=0 andalso output="PASS CLI unit import\n" andalso errors="","CLI unit import failed: " ^ output ^ errors)
      val (status,output,errors)=invoke "imported" [fromRoot "bin/runevm",dir ^ "/imported.rbc"]
      val ()=need (status=0 andalso output="42 imported\n" andalso errors="","imported program differs: " ^ output ^ errors)
      val private=dir ^ "/private.sml"
      val ()=write (private,"val private=Ast.decToString\n")
      val (status,_,errors)=invoke "private"
        [fromRoot (env ("RUNE","bin/rune")),"--library","compiler",private,"-o",dir ^ "/private.rbc"]
    in need (status<>0 andalso String.isSubstring "Ast.decToString" errors,"private compiler namespace leaked") end
  fun command ["build-asm-check"]=SOME asmCheck
    | command ["build-asm-faults"]=SOME asmFaults
    | command ["build-jit-compile"]=SOME compile
    | command ["build-jit-deep",name]=SOME (fn () => deep name)
    | command ["build-compiler-layout"]=SOME compilerLayout
    | command ["build-library-exports"]=SOME libraryExports
    | command ["build-compiler-api"]=SOME compilerApi
    | command _=NONE
  val vm=Test.it "vm-refusals"
    {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-windows vm --vm \"${RUNEVM:-bin/runevm-stack}\" --out \"$RUNE_TEST_RUN/low-level/vm\""],
     env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 900,cap=0,cpus=1,memory=500,pools=[],exclusive=false,after=[],judge=failLines} : Run.command Test.tree
  val tree=Test.describe "low-level"
    [tagged ["check","test-build","covers:lib/compiler/*","covers:*.build","covers:scripts/build-files.sh","covers:scripts/mlkit-build-root.sh"]
       (job "compiler-layout" ["build-compiler-layout"] []),
     tagged ["check","test-build","test-lib","covers:lib/compiler/*","covers:tests/lib/exports/*"]
       (job "library-exports" ["build-library-exports"] []),
     tagged ["check","test-compiler-api","test-lib","covers:lib/compiler/*","covers:tests/compiler/api*.sml"]
       (job "compiler-api" ["build-compiler-api"] []),
     tagged ["check","test","test-low-level","covers:tests/compiler/*","covers:tests/runtime/*"]
       (Test.describe "basic" [vm,executable "heap" "build/heap_test" []]),
     tagged ["check","layout","test-heap","test-heap-hooks","covers:tests/runtime/*"]
       (Test.describe "heap-hooks" (List.map (fn (name,binary) => executable name binary [])
          [("default","build/heap_test"),("gc-bits","build/heap_test-gcbits"),("cards","build/heap_test-cards")])),
     tagged ["check","test-register-jit","test-register-jit-steps","covers:tests/register/*",
             "covers:tests/lang/rt.deeprec_stack.*"]
       (Test.describe "jit"
         [job "encoder-independence" ["build-asm-check"] [],
          tagged ["quick"] (job "encoder-faults" ["build-asm-faults"] []),
          executable "executable-memory" "bin/runevm" ["--jit-check"],
          executable "x64" "build/register/x64_test" [],
          executable "x64-allocation-failures" "build/register/x64_fail_test" [],
          executable "a64" "build/register/a64_test" [],
          executable "a64-allocation-failures" "build/register/a64_fail_test" [],
          executable "masm" "build/register/masm_test" [],executable "divconst" "build/register/divconst_test" [],
          job "compile-deeprec" ["build-jit-compile"] [],
          Test.describe "deeprec" (List.map (fn (name,_) => job name ["build-jit-deep",name] ["low-level/jit/compile-deeprec"]) modes)])]
end
