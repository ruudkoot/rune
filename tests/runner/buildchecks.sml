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
      (* what a host reads: the build's plan, by scripts/plan-files.sh *)
      fun hostList (label, build, flags) =
        let val (status, text, errors) = invoke (label ^ "-plan") ([fromRoot (env ("RUNE", "bin/rune"))] @ flags @ ["--plan", build])
            val () = if status = 0 then () else raise Fail ("compiler layout: no plan of " ^ build ^ ": " ^ errors)
            val () = write (dir ^ "/" ^ label ^ ".plan", text)
        in invoke label ["sh", fromRoot "scripts/plan-files.sh", dir ^ "/" ^ label ^ ".plan"] end
      val (status, listed, _) = hostList ("bootstrap", dir ^ "/root.build", [])
      val expected = [dir ^ "/nested/first.sml", dir ^ "/second.sml"]
      val () = if status = 0 andalso lines listed = expected then () else say "FAIL compiler layout: bootstrap use/order differs\n"
      val (status, compiled, _) = invoke "compiler" [fromRoot (env ("RUNE", "bin/rune")), "--build-list", dir ^ "/root.build"]
      val () = if status = 0 andalso lines compiled = expected then () else say "FAIL compiler layout: compiler build-list differs\n"
      (* functors marked to be inlined across units (docs/build.md): no file
         to either list, and the manifest's # inline: line *)
      val () = write (dir ^ "/inline.build", "inline functor Make Other end\nuse nested/part.build\nfiles second.sml end\n")
      val (status, listed, _) = hostList ("inline-bootstrap", dir ^ "/inline.build", [])
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
      val (status, _, errors) = invoke "cycle" [fromRoot (env ("RUNE", "bin/rune")), "--plan", dir ^ "/cycle.build"]
      val ()=if status <> 0 andalso String.isSubstring "uses itself" errors then () else say "FAIL compiler layout: cyclic use was accepted\n"
      (* a library's final files come last in a host's list, as in --build-list *)
      val fixtures = dir ^ "/lib"
      val () = (rmTree fixtures; mkdirs (fixtures ^ "/fx"))
      val () = Posix.FileSys.symlink {old = fromRoot "lib/basis", new = fixtures ^ "/basis"}
      val () = write (fixtures ^ "/fx/library.build", "annotate \"final\" in last.sml end\nfirst.sml\n")
      val () = write (fixtures ^ "/fx/last.sml", "val () = print \"last\\n\"\n")
      val () = write (fixtures ^ "/fx/first.sml", "structure Fx = struct val x = 1 end\n")
      val () = write (dir ^ "/finals.build", "libraries fx end\nfiles second.sml end\n")
      val (status, listed, _) = hostList ("finals", dir ^ "/finals.build", ["--lib", fixtures])
      val (_, compiled, _) = invoke "finals-compiler" [fromRoot (env ("RUNE", "bin/rune")), "--lib", fixtures, "--build-list", dir ^ "/finals.build"]
      val () = if status = 0 andalso listed = compiled andalso
                  List.map OS.Path.file (lines listed) = ["first.sml", "second.sml", "last.sml"] then ()
               else say ("FAIL compiler layout: a host's list puts a library's final file elsewhere: " ^ listed ^ "\n")
      (* and what a host cannot read it refuses: a build file, a word a plan of
         version 1 does not have, a path that is escaped *)
      fun refused (label, text, why) =
        let val () = write (dir ^ "/" ^ label ^ ".plan", text)
            val (status, listed, errors) = invoke label ["sh", fromRoot "scripts/plan-files.sh", dir ^ "/" ^ label ^ ".plan"]
        in if status <> 0 andalso listed = "" andalso String.isSubstring why errors then ()
           else say ("FAIL compiler layout: a host read " ^ label ^ ": " ^ listed ^ errors ^ "\n") end
      val () = refused ("not-a-plan", read (dir ^ "/root.build"), "not a plan of version 1")
      val () = refused ("unknown-word", "rune-plan 1\nbasis demand\nprogram\n  unit a.sml a.sml ascii\n  edge a.sml b.sml\nend\n", "has no edge")
      val () = refused ("escaped", "rune-plan 1\nbasis demand\nprogram\n  unit a%20b.sml a%20b.sml ascii\nend\n", "a path a host cannot read")
      (* a step's output a host reads as a file; a file a preprocessor makes
         what is compiled of, it cannot compile, and refuses *)
      val () = write (dir ^ "/stepped.plan", "rune-plan 2\nbasis demand\ngenerate /bin/sh .\n  argument t.sh\n  reads t.sh\n"
                                             ^ "  writes a.sml\nend\nprogram\n  unit a.sml a.sml ascii\nend\n")
      val (status, listed, errors) = invoke "stepped" ["sh", fromRoot "scripts/plan-files.sh", dir ^ "/stepped.plan"]
      val () = if status = 0 andalso listed = "a.sml\n" then ()
               else say ("FAIL compiler layout: a host did not read a plan of version 2: " ^ listed ^ errors ^ "\n")
      val () = refused ("preprocessed", "rune-plan 2\nbasis demand\npreprocessor p /bin/sh .\nend\nprogram\n"
                                        ^ "  unit a.sml a.sml ascii preprocess=p\nend\n", "a file a host cannot compile")
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
      (* --typecheck-only keeps what a library's boundary exports *)
      val program = dir ^ "/program.build"
      val () = write (program,"libraries scoped end\n\"" ^ fromRoot (fixture ^ "/use.sml") ^ "\"\n")
      val (status,log) = invoke "typecheck-library" ["--no-cache","--typecheck-only","--build",program]
      val () = need (status=0,"--typecheck-only lost a library's exports: " ^ log)
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
        if String.isPrefix "# exports:" line then "# exports: structure:Missing" else line
      val () = write (scoped ^ "/MANIFEST",String.concatWith "\n" (List.map scopeLine (String.fields (fn c => c = #"\n") manifest)))
      val (status,log) = invoke "missing-export" ["--library","scoped","--basis-check"]
      val () = need (status<>0 andalso String.isSubstring "exports structure Missing" log,"undeclared manifest export accepted")
      val () = write (scoped ^ "/MANIFEST",manifest)
      val build = read (scoped ^ "/library.build")
      val () = write (scoped ^ "/library.build","exports (structure Missing)\nuse entries.build\n")
      val (status,log) = invoke "bad-index" ["--basis-index",scoped]
      val () = need (status<>0 andalso String.isSubstring "exports structure Missing" log andalso
                     read (scoped ^ "/MANIFEST")=manifest,"invalid index replaced a valid manifest")
      val () = write (scoped ^ "/library.build",build)
      val consumer = lib ^ "/consumer"
      val () = mkdirs consumer
      (* a library with no header keeps a boundary in the older form, a block (D15) *)
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
      (* a library that uses what a boundary it is written on hides fails at
         its own index, and not only at its client's compile (E28); the
         manifest stays as it was, and that compile fails as well *)
      val (status,log) = invoke "private-consumer-index" ["--basis-index",consumer]
      val () = need (status<>0 andalso String.isSubstring "uses Hidden, which the boundary of" log,
                     "the index did not notice a name a boundary hides: " ^ log)
      fun privateConsumer (label,flags) =
        let val (status,log) = invoke (label ^ "-private-consumer")
              (flags @ ["--library","consumer",dir ^ "/consumer-use.sml","-o",dir ^ "/rejected.rbc"])
        in need (status<>0 andalso String.isSubstring "Hidden.value" log,"private dependency leaked into another library") end
    in List.app privateConsumer modes end
  (* The plan of every build file of the tree (D5): printed, read back and
     printed again, the same bytes, and its unit lines the files --build-list
     gives, which an awk reads with no Rune *)
  fun planRoundTrip () =
    let
      val dir = run ^ "/plan-round-trip"
      val () = (rmTree dir; mkdirs dir)
      val skipped = ["out", ".rune", "cache", "node_modules", ".git"]
      fun builds base =
        List.concat (List.map (fn name =>
          let val path = if base = "." then name else base ^ "/" ^ name
          in if List.exists (fn s => s = name) skipped orelse OS.FileSys.isLink (fromRoot path) then []
             else if isDir (fromRoot path) then builds path
             else if String.isSuffix ".build" name then [path] else []
          end) (entries (fromRoot base)))
      val all = List.filter (fn f => String.isSuffix ".build" f) (entries root)
                @ List.concat (List.map builds ["lib", "src", "tools", "tests", "examples", "ffi"])
      fun invoke label args =
        let val output = dir ^ "/" ^ label ^ ".out"
            val errors = dir ^ "/" ^ label ^ ".err"
            val status = exec {cmd = fromRoot (env ("RUNE", "bin/rune")) :: args, dir = SOME root, stdin = "",
                               stdout = output, stderr = errors, timeout = 120}
        in (status, read output, read errors) end
      fun unitPaths text =
        List.mapPartial (fn line => case String.tokens Char.isSpace line of "unit" :: _ :: path :: _ => SOME path | _ => NONE) (lines text)
      val sorted = sort
      val failed = ref 0
      fun one (build, i) =
        let
          val label = Int.toString i
          (* a variable at the start of a path is from the build given *)
          val up = String.concatWith "/" (List.map (fn _ => "..") (List.tl (String.fields (fn c => c = #"/") build)))
          val up = if up = "" then "." else up
          val vars = ["--path", "SDL_GENERATED=" ^ up ^ "/lib/ffi/sdl/generated/native",
                      "--path", "WIN32_GENERATED=" ^ up ^ "/lib/ffi/win32/generated/64"]
          val (status, text, errors) = invoke label (["--no-warnings", "--plan"] @ vars @ [build])
          val stored = dir ^ "/" ^ label ^ ".plan"
          val () = write (stored, text)
          val (again, reprinted, _) = invoke (label ^ "-again") ["--plan", stored]
          val (listed, list, _) = invoke (label ^ "-list") (["--no-warnings"] @ vars @ ["--build-list", build])
          fun fail why = (failed := !failed + 1; say ("FAIL plan " ^ build ^ ": " ^ why ^ "\n"))
        in
          if status <> 0 then fail ("not planned: " ^ errors)
          else if again <> 0 orelse reprinted <> text then fail "its text does not read back as it is"
          else if listed <> 0 orelse sorted (lines list) <> sorted (unitPaths text) then fail "its units are not the files --build-list gives"
          else ()
        end
      val () = ListPair.app one (all, List.tabulate (length all, fn i => i))
    in
      if !failed = 0 then say ("plan-round-trip: OK (" ^ Int.toString (length all) ^ " build files)\n") else ()
    end

  (* The plans the other SML systems read their lists from (docs/building.md,
     How a host gets its list; the build-system roadmap's M11): each plan
     committed at the top is what the compiler prints of its build, byte for
     byte, so that a plan edited by hand, or one a build file has changed
     since, is caught; and what a host reads of it is what --build-list
     gives. *)
  fun plans () =
    let
      val dir = run ^ "/plans"
      val () = (rmTree dir; mkdirs dir)
      val rune = fromRoot (env ("RUNE", "bin/rune"))
      fun invoke label args =
        let val output = dir ^ "/" ^ label ^ ".out"
            val errors = dir ^ "/" ^ label ^ ".err"
            val status = exec {cmd = args, dir = SOME root, stdin = "", stdout = output, stderr = errors, timeout = 120}
        in (status, read output, read errors) end
      val committed = sort (List.filter (String.isSuffix ".plan") (entries root))
      val () = List.app (fn p => if List.exists (fn c => c = p) committed then () else say ("FAIL plans: no " ^ p ^ "\n"))
                 ["rune.plan", "runedoc.plan", "runeopt.plan", "runeisa.plan", "runeffi.plan"]
      (* what is wrong with TEXT as the plan of BUILD *)
      fun wrong (label, build, text) =
        let val (status, printed, errors) = invoke label [rune, "--plan", build]
        in if status <> 0 then SOME ("no plan of " ^ build ^ ": " ^ errors)
           else if printed <> text then SOME ("not what rune --plan " ^ build ^ " prints; `make plans` prints it again")
           else NONE end
      fun one plan =
        let
          val build = String.substring (plan, 0, size plan - size ".plan") ^ ".build"
          val () = case wrong (plan, build, read (fromRoot plan)) of
                     NONE => () | SOME why => say ("FAIL plans: " ^ plan ^ ": " ^ why ^ "\n")
          val (hosted, listed, errors) = invoke (plan ^ "-host") ["sh", fromRoot "scripts/plan-files.sh", plan]
          val (status, compiled, _) = invoke (plan ^ "-list") [rune, "--build-list", build]
        in
          if hosted = 0 andalso status = 0 andalso listed = compiled then ()
          else say ("FAIL plans: what a host reads of " ^ plan ^ " is not what rune --build-list " ^ build ^ " gives " ^ errors ^ "\n")
        end
      val () = List.app one committed
      (* the check catches a hand edit: a unit taken out of rune.plan *)
      val text = read (fromRoot "rune.plan")
      val edited = String.concatWith "\n" (List.filter (fn l => not (String.isSubstring "/pickle.sml " l)) (String.fields (fn c => c = #"\n") text))
    in
      if edited <> text andalso isSome (wrong ("hand-edit", "rune.build", edited)) then
        say ("plans: " ^ Int.toString (length committed) ^ " plans as the compiler prints them\n")
      else say "FAIL plans: a hand edit of rune.plan was not caught\n"
    end

  (* The compiler's identity (docs/building.md, How a host gets its list; the
     build-system roadmap's D14 and M11), in a tree of the test's own in which
     rune.build reaches lib/unicode, lib/json and lib/digest through
     `libraries`, as E12 had it. An edit of lib/unicode gives another identity,
     and compiler B, so edited, takes none of compiler A's entries: it prints
     234 for U+00E9, as it does with no cache, where with the identity of the
     awk's list, which lost the libraries, it took A's and printed 233. Two
     makes with no edit give one identity, though the closure holds the file
     that holds it; and a plan that a build file has changed since is refused.
     A second compiler, on a toy, has its own identity, over its own closure:
     an edit of its own source changes its identity and not rune's, and it
     takes none of its old self's entries. *)
  fun identity () =
    let
      val dir = run ^ "/identity"
      val tree = dir ^ "/tree"
      val () = (rmTree dir; List.app (fn d => mkdirs (tree ^ "/" ^ d)) ["lib/unicode", "lib/compiler", "runtime", "toy"])
      fun need (true, _) = () | need (false, message) = raise Fail ("identity: " ^ message)
      (* what the test is about: said, and the test goes on *)
      val failed = ref 0
      fun check (true, _) = () | check (false, message) = (failed := !failed + 1; say ("FAIL identity: " ^ message ^ "\n"))
      fun link path = Posix.FileSys.symlink {old = fromRoot path, new = tree ^ "/" ^ path}
      (* the tree's own: its build files, lib/unicode/utf8.sml, which it
         edits, and lib/compiler/config.sml, which gen-version.sh writes; the
         rest is the checkout's, its scripts among them *)
      val () = List.app link ["scripts", "src", "lib/basis", "lib/json", "lib/digest"]
      val () = List.app (fn (d, own) => List.app (fn f => if f = own then () else link (d ^ "/" ^ f)) (entries (fromRoot d)))
                 [("lib/unicode", "utf8.sml"), ("lib/compiler", "config.sml")]
      val utf8 = read (fromRoot "lib/unicode/utf8.sml")
      val () = write (tree ^ "/lib/unicode/utf8.sml", utf8)
      val written = String.fields (fn c => c = #"\n") (read (fromRoot "rune.build"))
      val through =
        if List.exists (String.isPrefix "libraries ") written then written
        else "libraries unicode json digest end" ::
             List.filter (fn l => not (List.exists (fn p => String.isPrefix p l) ["  lib/unicode/", "  lib/json/", "  lib/digest/"])) written
      val () = write (tree ^ "/rune.build", String.concatWith "\n" through)
      val () = need (List.exists (fn l => l = "build/config.sml") through, "rune.build names build/config.sml on no line of its own")
      (* the toy loads a Config of its own first, which a step of its own
         declares, as rune.build's first step declares build/config.sml
         (docs/build.md, Generated sources) *)
      fun toyLine l =
        if l = "build/config.sml" then ["toy/config.sml", "toy/toy.sml"]
        else if String.isPrefix "generate scripts/gen-version.sh " l
        then ["generate scripts/gen-version.sh (--config, toy.plan, toy/config.sml)"]
        else if String.isSubstring "outputs build/config.sml end" l then ["  outputs toy/config.sml end"]
        else [l]
      val () = write (tree ^ "/toy.build", String.concatWith "\n" (List.concat (List.map toyLine through)))
      val toy = "structure Toy = struct val name = \"toy\" end\n"
      val () = write (tree ^ "/toy/toy.sml", toy)
      fun invoke (label, cmd) =
        let val output = dir ^ "/" ^ label ^ ".out"
            val errors = dir ^ "/" ^ label ^ ".err"
            val status = execEnv (setEnv ("GIT_CEILING_DIRECTORIES", dir))
                           {cmd = cmd, dir = SOME tree, stdin = "", stdout = output, stderr = errors, timeout = 900}
        in (status, read output, read errors) end
      fun rune (label, args) = invoke (label, [fromRoot (env ("RUNE", "bin/rune")), "--lib", tree ^ "/lib"] @ args)
      fun planned name =
        let val (status, text, errors) = rune (name ^ "-plan", ["--plan", name ^ ".build"])
        in need (status = 0, "no plan of " ^ name ^ ".build: " ^ errors); write (tree ^ "/" ^ name ^ ".plan", text) end
      fun generate (label, args) =
        let val (status, _, errors) = invoke (label, ["sh", "scripts/gen-version.sh"] @ args)
        in need (status = 0, "gen-version.sh " ^ String.concatWith " " args ^ ": " ^ errors) end
      fun identityIn file =
        case List.find (String.isPrefix "  val identity = ") (lines (read (tree ^ "/" ^ file))) of
          SOME line => line | NONE => raise Fail ("identity: none in " ^ file)
      fun compiler (name, build) =
        let val (status, _, errors) = rune (name, ["--units", "--cache-dir", dir ^ "/building", "--build", build, "-o", dir ^ "/" ^ name ^ ".rbc"])
        in need (status = 0, "compiler " ^ name ^ " is not built: " ^ errors) end
      val program = dir ^ "/p.sml"
      val () = write (program, "val () = print (Int.toString (WideChar.ord #\"\195\169\") ^ \"\\n\")\n")
      (* what compiler NAME's program prints, compiled in units, with the
         cache CACHE or none *)
      fun prints (name, cache) =
        let
          val label = name ^ "-" ^ (case cache of SOME c => OS.Path.file c | NONE => "cold")
          val (status, _, errors) =
            invoke (label, [fromRoot "bin/runevm", dir ^ "/" ^ name ^ ".rbc", "--lib", tree ^ "/lib", "--unicode", "--units"]
                           @ (case cache of SOME c => ["--cache-dir", c, "--explain-rebuild"] | NONE => ["--no-cache"])
                           @ [program, "-o", dir ^ "/" ^ label ^ ".rbc"])
          val () = need (status = 0, label ^ ": " ^ errors)
          val (_, output, _) = invoke (label ^ "-run", [fromRoot "bin/runevm", dir ^ "/" ^ label ^ ".rbc"])
        in output end
      (* Utf8.decode, last, giving U+00EA for U+00E9 *)
      val decode = "  val decode = fn a => case decode a of SOME (233, k) => SOME (234, k) | r => r\n"

      (* E12 *)
      val () = planned "rune"
      val () = need (String.isSubstring "\nlibrary unicode lib/unicode\n" (read (tree ^ "/rune.plan")),
                     "rune.build does not reach lib/unicode through libraries")
      fun configs () = (read (tree ^ "/build/config.sml"), read (tree ^ "/lib/compiler/config.sml"))
      val () = generate ("make-1", [])
      val first = configs ()
      val () = generate ("make-2", [])
      val () = check (configs () = first, "two makes with no edit gave two identities")
      val a = identityIn "build/config.sml"
      val () = compiler ("A", "rune.build")
      val body = Substring.string (Substring.dropr Char.isSpace (Substring.full utf8))
      val () = need (String.isSuffix "\nend" body, "lib/unicode/utf8.sml does not end with its structure's end")
      val () = write (tree ^ "/lib/unicode/utf8.sml", String.substring (body, 0, size body - 3) ^ decode ^ "end\n")
      val () = generate ("make-B", [])
      val () = check (identityIn "build/config.sml" <> a, "an edit of lib/unicode, reached through libraries, left the identity as it was")
      val () = compiler ("B", "rune.build")
      val shared = SOME (dir ^ "/cache")
      val () = need (prints ("A", shared) = "233\n", "compiler A does not print 233")
      val () = need (prints ("B", NONE) = "234\n", "compiler B with no cache does not print 234")
      val () = check (prints ("B", shared) = "234\n", "compiler B took compiler A's entry: it prints 233, what A compiled, where it prints 234 with no cache")

      (* a plan that a build file has changed since is refused, and nothing is written *)
      val kept = configs ()
      val runeBuild = read (tree ^ "/rune.build")
      val () = write (tree ^ "/rune.build", runeBuild ^ "\n(* an edit *)\n")
      val (status, _, errors) = invoke ("stale", ["sh", "scripts/gen-version.sh"])
      val () = check (status <> 0 andalso String.isSubstring "rune.plan is stale" errors andalso String.isSubstring "make plans" errors,
                      "a stale plan was not refused: " ^ errors)
      val () = check (configs () = kept, "the identity of a stale plan was written")
      val () = write (tree ^ "/rune.build", runeBuild)

      (* a second compiler: Rune's driver with a source of its own,
         toy/toy.sml, whose Config gen-version.sh --config writes *)
      val () = write (tree ^ "/lib/unicode/utf8.sml", utf8)
      val () = generate ("make-toy-A", [])
      val () = check (identityIn "build/config.sml" = a, "lib/unicode as it was does not give the identity it gave")
      val () = planned "toy"
      val config = ["--config", "toy.plan", "toy/config.sml"]
      val () = generate ("toy-1", config)
      val t = identityIn "toy/config.sml"
      val () = generate ("toy-2", config)
      val () = check (identityIn "toy/config.sml" = t, "two makes of the toy with no edit gave two identities")
      val () = check (t <> a, "the toy has rune's identity")
      val () = compiler ("toyA", "toy.build")
      val () = write (tree ^ "/toy/toy.sml", toy ^ "structure Utf8 = struct open Utf8\n" ^ decode ^ "end\n")
      val () = generate ("toy-B", config)
      val () = generate ("make-toy-B", [])
      val () = check (identityIn "toy/config.sml" <> t, "an edit of the toy's own source left its identity as it was")
      val () = check (identityIn "build/config.sml" = a, "an edit of the toy's own source changed rune's identity")
      val () = compiler ("toyB", "toy.build")
      val toys = SOME (dir ^ "/toy-cache")
      val () = need (prints ("toyA", toys) = "233\n", "toy A does not print 233")
      val () = need (prints ("toyB", NONE) = "234\n", "toy B with no cache does not print 234")
      val () = check (prints ("toyB", toys) = "234\n", "toy B took toy A's entry: it prints 233, what A compiled, where it prints 234 with no cache")
    in if !failed = 0 then say "identity: the closure's, one per compiler\n" else () end

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
      (* selection by uses, through the API: a library that fails where a
         selection takes it (tests/compiler/api-selection.sml) *)
      val selection=dir ^ "/selection"
      val ()=mkdirs (selection ^ "/m")
      val ()=write (selection ^ "/m/library.build","annotate \"demand\" in e.sml end\n")
      val ()=write (selection ^ "/m/e.sml","structure E = struct val v = 1 + \"not an int\" end\n")
      val ()=Posix.FileSys.symlink {old=fromRoot "lib/basis",new=selection ^ "/basis"}
      val (status,_,errors)=invoke "selection-index"
        [fromRoot (env ("RUNE","bin/rune")),"--lib",selection,"--no-warnings","--basis-index",selection ^ "/m"]
      val ()=need (status=0,"selection fixture: " ^ errors)
      val ()=compile ("selection",[],"tests/compiler/api-selection.sml")
      val (status,output,errors)=invoke "selection" [fromRoot "bin/runevm",dir ^ "/selection.rbc",selection]
      val ()=need (status=0 andalso output="PASS API selection\n" andalso errors="","API selection differs: " ^ output ^ errors)
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
    | command ["build-library-model"]=SOME LibraryModel.run'
    | command ["build-namespaces"]=SOME Namespaces.run'
    | command ["build-plan-round-trip"]=SOME planRoundTrip
    | command ["build-plans"]=SOME plans
    | command ["build-identity"]=SOME identity
    | command ["build-compiler-api"]=SOME compilerApi
    | command _=NONE
  val vm=Test.it "vm-refusals"
    {program="/bin/sh",args=["sh","-c","exec \"$RUNE_TEST_ROOT\"/bin/rune-windows vm --vm \"${RUNEVM:-bin/runevm-stack}\" --out \"$RUNE_TEST_RUN/low-level/vm\""],
     env=NONE,dir=SOME ".",stdin=NONE,timeout=Time.fromSeconds 900,cap=0,cpus=1,memory=500,pools=[],exclusive=false,after=[],judge=failLines} : Run.command Test.tree
  val tree=Test.describe "low-level"
    [tagged ["check","test-build","covers:lib/compiler/*","covers:*.build","covers:scripts/plan-files.sh","covers:scripts/mlkit-build-root.sh"]
       (job "compiler-layout" ["build-compiler-layout"] []),
     tagged ["check","test-build","test-lib","covers:lib/compiler/*","covers:tests/lib/exports/*"]
       (job "library-exports" ["build-library-exports"] []),
     tagged ["check","test-build","test-lib","covers:lib/compiler/*","covers:src/driver/*","covers:tests/runner/librarymodel.sml"]
       (job "library-model" ["build-library-model"] []),
     tagged ["check","test-build","test-lib","covers:lib/compiler/*","covers:src/driver/*","covers:lib/basis/library.build",
             "covers:tests/runner/librarymodel.sml"]
       (job "namespaces" ["build-namespaces"] []),
     tagged ["check","test-build","covers:lib/compiler/*","covers:src/driver/*","covers:*.build"]
       (job "plan-round-trip" ["build-plan-round-trip"] []),
     tagged ["check","quick","test-build","covers:*.build","covers:*.plan","covers:scripts/plan-files.sh","covers:lib/compiler/*"]
       (job "plans" ["build-plans"] []),
     tagged ["check","test-build","test-incremental","covers:*.build","covers:*.plan","covers:scripts/gen-version.sh",
             "covers:scripts/plan-files.sh","covers:lib/compiler/*","covers:src/driver/*"]
       (job "identity" ["build-identity"] []),
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
