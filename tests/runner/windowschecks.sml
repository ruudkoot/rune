(* Windows language fixtures use Lang's existing judges. Staging and process
   adapters are Windows-specific; expectations, counts and images are shared. *)
structure WindowsChecks =
struct
  open Sh
  exception Failed of string
  type family={name:string,compiler:string,compilerID:string,native:string,vms:string list,defs:string,options:string list}
  val defaults=
    [{name="stack",compiler="bin/rune-stack",compilerID="stack",native="bin/runevm-stack",
      vms=["bin/runevm-stack.exe","bin/runevm-stack32.exe"],defs="runtime/stack/opcodes.def",options=[]},
     {name="register",compiler="bin/rune",compilerID="register",native="bin/runevm",
      vms=["bin/runevm.exe","bin/runevm32.exe"],defs="runtime/register/regs.def",options=["--jit=all"]},
     {name="register-jit",compiler="bin/rune",compilerID="register",native="bin/runevm",
      vms=["bin/runevm.exe"],defs="runtime/register/regs.def",options=["--jit=all","--jit-tier=2"]}] : family list
  fun families ()=if env ("WINDOWS_SELECTED","0")<>"1" then defaults else
       [{name="selected",compiler=env ("WINDOWS_RUNE","bin/rune-stack"),compilerID="selected",
         native=env ("WINDOWS_NATIVE","bin/runevm-stack"),vms=String.fields (fn ch => ch = #"\n") (env ("WINDOWS_VMS","bin/runevm-stack.exe\nbin/runevm-stack32.exe")),
         defs=env ("WINDOWS_DEF","runtime/stack/opcodes.def"),options=[]}]
  fun family name=case List.find (fn f : family => #name f=name) (families ()) of SOME f => f | NONE => raise Failed ("unknown Windows family " ^ name)
  fun need (ok,why)=if ok then () else raise Failed why
  fun prepare () =
    let val directory=WindowsDir.directory () ^ "/sml-" ^ OS.Path.file run
        val ()=mkdirs (run ^ "/windows")
        val vms=List.foldl (fn (f : family,values) => List.foldl (fn (vm,values) =>
                    if List.exists (fn old => old=vm) values then values else vm :: values) values (#vms f)) [] (families ())
        fun probe vm =
          let val program=fromRoot vm
              val ()=need (OS.FileSys.access (program,[OS.FileSys.A_EXEC]),"Windows VM is missing: " ^ program)
              val status=Children.exec Subprocess.unlimited (fn e => e)
                   {cmd=[program,"--version"],dir=SOME directory,stdin="",stdout=run ^ "/windows/probe.out",stderr=run ^ "/windows/probe.err",timeout=30}
          in need (status=0,"Windows VM cannot start: " ^ program) end
        val ()=mkdirs directory
        val ()=List.app probe vms
    in write (run ^ "/windows/directory",directory ^ "\n");mkdirs directory end
  fun directory ()=let val path=Hosts.trim (read (run ^ "/windows/directory"))
                   in need (path<>"","Windows staging producer did not complete");path end
  fun skipped name=List.find (fn row : Expectations.line => List.exists (fn kind => kind= #category row) ["HOST-ABSENT","XC1-NA","XC2-NA","UNTESTED","UNSUPPORTED"] andalso Expectations.glob (#path row,name))
                              (Expectations.read (fromRoot "tests/windows-skip.txt"))
  fun names ()=List.filter (fn name => String.isSubstring (env ("WINDOWS_FILTER","")) name) (List.map basename (glob (fromRoot "tests/lang",".sml")))
  fun rbc compiler name=run ^ "/windows-rbc/" ^ compiler ^ "/" ^ name ^ ".rbc"
  fun logs name=run ^ "/windows/" ^ name
  fun bits result : Supervisor.result={outcome=Supervisor.Exited result,wall=Time.zeroTime,user=Time.zeroTime,system=Time.zeroTime,
                  peakResident=0,outputBytes=0,leaked=false}
  fun wanted judge status stdout stderr=case judge (bits status,{stdout=stdout,stderr=stderr}) of NONE => () | SOME (_,why) => raise Failed why
  fun environment values =
    let val existing=String.fields (fn ch => ch = #":") (env ("WSLENV",""))
        fun present name=List.exists (fn entry => hd (String.fields (fn ch => ch = #"/") entry)=name) existing
        val required=List.filter (not o present) ["TZ","RUNEVM_INTINF","RUNEVM_JIT"]
        val wslenv=String.concatWith ":" (required @ List.filter (fn field => field<>"") existing)
    in setEnv ("TZ","NST3:30NDT,M3.2.0,M11.1.0") (setEnv ("WSLENV",wslenv) (unsetEnv ["FORCE_COLOR","CLICOLOR_FORCE"] values)) end
  fun execute name working input args =
    let val dir=logs name
        val ()=mkdirs dir
        val status=Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (64*1024*1024),core=SOME 0} environment
           {cmd=args,dir=SOME working,stdin=input,stdout=dir ^ "/stdout",stderr=dir ^ "/stderr",timeout=900}
    in (status,dir) end
  fun compile id name () =
    let val f=valOf (List.find (fn f : family => #compilerID f=id) (families ()))
        val output=rbc id name
        val ()=(mkdirs (OS.Path.dir output);rmTree output)
        val (status,dir)=execute ("compile/" ^ id ^ "/" ^ name) root ""
              (fromRoot (#compiler f) :: words (fromRoot ("tests/lang/" ^ name ^ ".cargs"))
                       @ ["tests/lang/" ^ name ^ ".sml","-o",output])
    in wanted (LangChecks.compileJudge (false,name)) status (dir ^ "/stdout") (dir ^ "/stderr");
       need (exists output,"Windows compiler produced no bytecode") end
  fun runCase familyName vm name () =
    let val f=family familyName
        val vm=fromRoot vm
        val directory=directory () ^ "/" ^ familyName ^ "/" ^ OS.Path.file vm ^ "/" ^ name
        val ()=(rmTree directory;mkdirs (directory ^ "/tests/out"))
        val ()=MatrixLoad.copy (rbc (#compilerID f) name,directory ^ "/" ^ name ^ ".rbc")
        val base=fromRoot ("tests/lang/" ^ name)
        val input=if exists (base ^ ".stdin") then base ^ ".stdin" else ""
        val (status,dir)=execute (familyName ^ "/" ^ OS.Path.file vm ^ "/" ^ name) directory input
              (vm :: #options f @ words (base ^ ".vmargs") @ [name ^ ".rbc"] @ words (base ^ ".args"))
        val image=directory ^ "/tests/out/" ^ name ^ ".img"
        val ()=if not (exists (base ^ ".restore")) orelse not (exists image) then () else
          let val restored=dir ^ "/restore"
              val ()=mkdirs restored
              val status=Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (64*1024*1024),core=SOME 0} environment
                  {cmd=vm :: #options f @ words (base ^ ".restorevmargs") @ ["--restore","tests/out/" ^ name ^ ".img"]
                       @ (if exists (base ^ ".restoreargs") then "--" :: words (base ^ ".restoreargs") else []),
                   dir=SOME directory,stdin="",stdout=dir ^ "/restored",stderr=dir ^ "/restored.err",timeout=900}
              val ()=write (dir ^ "/restored.code",Int.toString status ^ "\n")
          in mkdirs (dir ^ "/tests/out");MatrixLoad.copy (image,dir ^ "/tests/out/" ^ name ^ ".img") end
    in wanted (LangChecks.runJudge (false,name)) status (dir ^ "/stdout") (dir ^ "/stderr") end
  val layoutCases=["rt.gc_stress","rt.deeprec_stack","rt.closure_capture","rt.equality_structural"]
  fun endpoint f vm suffix scope : VMOracles.endpoint =
    {name=OS.Path.file vm ^ suffix,program=fromRoot vm,directory=directory () ^ "/oracle/" ^ #name (f : family) ^ "/" ^ scope ^ "/" ^ OS.Path.file vm ^ suffix,
     windows=String.isSuffix ".exe" vm,options= #options f,environment=environment}
  fun count familyName vm name () =
    let val f=family familyName
        val scope="count/" ^ OS.Path.file vm ^ "/" ^ name
        val endpoints=[endpoint f (#native f) "-native" scope,endpoint f vm "-windows" scope]
        val options=words (fromRoot ("tests/lang/" ^ name ^ ".vmargs"))
    in VMOracles.count (logs ("count/" ^ familyName ^ "/" ^ OS.Path.file vm ^ "/" ^ name)) (rbc (#compilerID f) name) options endpoints end
  fun image familyName vm () =
    let val f=family familyName
    in VMOracles.images (logs ("image/" ^ familyName ^ "/" ^ OS.Path.file vm)) (rbc (#compilerID f) "rt.save_restore_cross")
                "tests/out/rt.save_restore_cross.img" [endpoint f (#native f) "-native-image" ("image/" ^ OS.Path.file vm),
                  endpoint f vm "-windows-image" ("image/" ^ OS.Path.file vm)] end
  fun refusals familyName vm () =
    let val f=family familyName
    in VMChecks.run {vm=vm,defs= #defs f,directory=directory () ^ "/refusals/" ^ familyName ^ "/" ^ OS.Path.file vm,
                     logs=logs ("refusals/" ^ familyName ^ "/" ^ OS.Path.file vm)} end
  (* The wide-API C helper remains an independent oracle. SML owns its
     build/staging, VM matrix, deadlines and verdicts. *)
  val textOutput=run ^ "/windows-text"
  fun textAccepted status output required =
    status=0 andalso not (List.exists (String.isPrefix "FAIL ") (lines output))
    andalso List.all (fn name => List.exists (fn line => Hosts.trim line="PASS windows.text/" ^ name) (lines output)) required
  fun textExecute name working args required =
    let val (status,dir)=execute ("text/" ^ name) working "" args
        val output=read (dir ^ "/stdout")
    in need (textAccepted status output required,
             "Windows text " ^ name ^ ": exit " ^ Int.toString status ^ "\n" ^ output ^ read (dir ^ "/stderr")) end
  fun textPrepare () =
    let val ()=mkdirs textOutput
        fun helper bits = textExecute ("build-" ^ bits) root
          [env (if bits="64" then "WINCC" else "WINCC32",
                if bits="64" then "x86_64-w64-mingw32-gcc" else "i686-w64-mingw32-gcc"),
           "-std=c17","-O2","-Wall","-Wextra","-Werror","-D__USE_MINGW_ANSI_STDIO=1","-municode","-Iruntime",
           "-o",textOutput ^ "/interop" ^ bits ^ ".exe","tests/windows/interop.c",
           "-lws2_32","-ladvapi32","-lshell32","-luser32","-lpsapi"] []
        fun probe target = textExecute ("compile-" ^ target) root
          [fromRoot (env ("RUNE","bin/rune")),"--target=" ^ target,"tests/windows/probe.sml",
           "-o",textOutput ^ "/probe-" ^ target ^ ".rbc"] []
    in List.app helper ["64","32"];List.app probe ["stack","registers"] end
  fun textStage name bits =
    let val stage=WindowsDir.directory () ^ "/text-sml-" ^ OS.Path.file run ^ "/" ^ name
        val ()=(rmTree stage;mkdirs stage)
        val ()=MatrixLoad.copy (textOutput ^ "/interop" ^ bits ^ ".exe",stage ^ "/interop.exe")
    in stage end
  fun textOracle bits () =
    let val stage=textStage ("oracle" ^ bits) bits
    in textExecute ("oracle" ^ bits) stage [stage ^ "/interop.exe"]
         ["utf16-to-utf8","reject-malformed-and-cesu8","environment-over-64k",
          "root-rmdir","registry-cleanup","spawn-explicit-wide-env","unicode-program-remove"] end
  fun textVM vm () =
    let val stack=String.isPrefix "runevm-stack" vm
        val target=if stack then "stack" else "registers"
        val compiler=if stack then "rune.stack.rbc" else "rune.rbc"
        val bits=if String.isSuffix "32.exe" vm then "32" else "64"
        val stage=textStage vm bits
        val ()=List.app (fn (source,name) => MatrixLoad.copy (source,stage ^ "/" ^ name))
          [(fromRoot ("bin/" ^ vm),"vm-\206\187.exe"),(textOutput ^ "/probe-" ^ target ^ ".rbc","probe.rbc"),
           (fromRoot ("bin/" ^ compiler),"compiler.rbc")]
        fun available name = List.exists (fn dir => OS.FileSys.access
            (OS.Path.concat (if dir="" then "." else dir,name),[OS.FileSys.A_EXEC]) handle OS.SysErr _ => false)
            (String.fields (fn ch => ch = #":") (env ("PATH","")))
        val converter=if available "wslpath" then SOME "wslpath" else if available "cygpath" then SOME "cygpath" else NONE
        val lib=case converter of NONE => fromRoot "lib" | SOME tool =>
          Hosts.trim (WindowsDir.command ("text-lib-" ^ vm) root "" [tool,"-w",fromRoot "lib"])
        val ()=textExecute (vm ^ "/probe") stage [stage ^ "/interop.exe","--vm","./vm-\206\187.exe","probe.rbc"]
          ["vm-wide-arguments","vm-wide-environment","vm-fork-status","vm-current-directory"]
    in textExecute (vm ^ "/compile") stage
         [stage ^ "/interop.exe","--compile","./vm-\206\187.exe","compiler.rbc",lib,target]
         ["native-source","windows-compiler-unicode-source","native-compile","windows-compiler-result"] end
  fun textFaults () =
    let val ok="PASS windows.text/probe\n"
        fun reject (name,status,output)=need (not (textAccepted status output ["probe"]),"text verdict accepted " ^ name)
    in need (textAccepted 0 ok ["probe"],"text verdict rejected success");
       List.app reject [("empty output",0,""),("wrong label",0,"PASS windows.text/other\n"),
         ("nonzero after PASS",7,ok),("FAIL after PASS",0,ok ^ "FAIL windows.text/later\n"),
         ("timeout",124,ok)] end
end
