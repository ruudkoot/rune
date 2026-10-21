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
  fun endpoint f vm suffix : VMOracles.endpoint =
    {name=OS.Path.file vm ^ suffix,program=fromRoot vm,directory=directory () ^ "/oracle/" ^ #name (f : family) ^ "/" ^ OS.Path.file vm ^ suffix,
     windows=String.isSuffix ".exe" vm,options= #options f,environment=environment}
  fun count familyName vm name () =
    let val f=family familyName
        val endpoints=[endpoint f (#native f) "-native",endpoint f vm "-windows"]
        val options=words (fromRoot ("tests/lang/" ^ name ^ ".vmargs"))
    in VMOracles.count (logs ("count/" ^ familyName ^ "/" ^ OS.Path.file vm ^ "/" ^ name)) (rbc (#compilerID f) name) options endpoints end
  fun image familyName vm () =
    let val f=family familyName
    in VMOracles.images (logs ("image/" ^ familyName ^ "/" ^ OS.Path.file vm)) (rbc (#compilerID f) "rt.save_restore_cross")
                "tests/out/rt.save_restore_cross.img" [endpoint f (#native f) "-native-image",endpoint f vm "-windows-image"] end
  fun refusals familyName vm () =
    let val f=family familyName
    in VMChecks.run {vm=vm,defs= #defs f,directory=directory () ^ "/refusals/" ^ familyName ^ "/" ^ OS.Path.file vm,
                     logs=logs ("refusals/" ^ familyName ^ "/" ^ OS.Path.file vm)} end
end
