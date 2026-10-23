(* Model acceptance uses original headers and the existing bounded host
   harness. Native compiler discovery only locates standard include input. *)
structure ForeignModelChecks =
struct
  open Sh
  exception Failed of string
  fun need(ok,message)=if ok then () else raise Failed message
  fun field name value=case Json.member(name,value) of SOME v=>v | NONE=>raise Failed("missing " ^ name)
  fun string(Json.String s)=s | string _=raise Failed "expected string"
  fun array(Json.Array values)=values | array _=raise Failed "expected array"
  val directory=run ^ "/ffi-model/" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
  fun command name args =
    let val ()=mkdirs directory val output=directory ^ "/" ^ name ^ ".out" val errors=output ^ ".err"
        val status=Children.exec Subprocess.unlimited (fn e=>e){cmd=args,dir=SOME root,stdin="",stdout=output,stderr=errors,timeout=600}
        val ()=need(status=0,name ^ ": " ^ read errors ^ read output)
    in read output end
  fun roots target = if String.isPrefix "windows" target then
      let val sdk=env("RUNEFFI_WINDOWS_SDK","/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0")
          val compiler=env("RUNEFFI_MSVC_INCLUDE","/mnt/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.40.33807/include")
      in [sdk ^ "/um",sdk ^ "/shared",sdk ^ "/ucrt",compiler] end
    else [Hosts.trim(command "standard-include" (String.tokens Char.isSpace(env("CC","cc")) @ ["-print-file-name=include"])),
          "/usr/include/x86_64-linux-gnu","/usr/include"]
  fun inventory target library =
    let val output=directory ^ "/" ^ target ^ "-" ^ library ^ ".json"
        val inputs=(if library="sdl" then [fromRoot "ffi/sdl/upstream"] else []) @ roots target
        val text=command (target ^ "-" ^ library) (["bin/rune-ffi-model","inventory","ffi/targets/" ^ target ^ ".json",
          "ffi/" ^ library ^ "/inventory.json",output] @ inputs)
        val report=Json.decode(read output)
        val entries=array(field "coverage" report)
        val ()=List.app(fn entry=>need(not(List.exists(fn state=>state=string(field "state" entry))["generated","shimmed"]),
          "inspection claimed executable generation"))entries
        val ()=List.app(fn entry=>if string(field "state" entry)="unselected" then () else
          need(exists(string(field "file" (field "source" entry))),"selected declaration lost its original source"))entries
    in say text end
  val golden="tests/ffi/model/projected_sig.sml"
  val contracts=["ffi/contracts/sdl.sml","ffi/contracts/win32.sml",golden]
  val basis=run ^ "/ffi-model/golden-basis"
  fun prepare ()=
    (ignore(command "prepare-host-basis" ["bin/rune-generate","host-basis",basis]);
     write(basis ^ "/selected",command "projection-basis-dependencies" [env("RUNE","bin/rune"),"--basis-deps","tests/ffi/model/basis_imports.sml"]);
     List.app(fn file=>
       let val path=basis ^ "/basis/" ^ file
           fun line text=if Hosts.trim text="val two32 = IntInf.fromInt 4294967296" then
             "    val two32 = IntInf.<< (IntInf.fromInt 1, 0w32)" else text
       in write(path,String.concatWith "\n" (List.map line (String.fields(fn c=>c= #"\n")(read path)))) end)
       ["int64.sml","word64.sml"])
  fun host name =
    let val ()=mkdirs directory
        val prelude=List.filter(fn path=>path<>"")(lines(read(basis ^ "/prelude")))
        val probe=directory ^ "/precision.sml"
        val ()=write(probe,"val ()=print(\"HOST-PRECISION \" ^ (case Int.precision of NONE=>\"0\" | SOME n=>Int.toString n) ^ \"\\n\")\n")
        val precisionProbe=Hosts.build{host=Hosts.get name,name="precision",sources=[probe],
          dir=directory ^ "/precision",runDir=root,timeout=600,memory=2048}
        val ()=need(#built precisionProbe andalso #status precisionProbe=0,"host precision probe failed")
        val precision=case List.find(String.isPrefix "HOST-PRECISION ")(lines(#output precisionProbe)) of
          SOME line=>valOf(Int.fromString(String.extract(line,15,NONE))) | NONE=>raise Failed "missing host precision"
        (* The shared host matrix also retains native providers where a
           Rune type aliases a default integer that is too narrow. *)
        val omitted=if precision>0 andalso precision<=32 then ["int32.sml","seal_int32.sml"] else []
        val ()=write(directory ^ "/native-providers",String.concatWith "\n" omitted ^ "\n")
        val sources=List.map(fn file=>basis ^ "/basis/" ^ file)
          (List.filter(fn file=>not(List.exists(fn omitted=>omitted=file)omitted))(lines(read(basis ^ "/selected"))))
        val marker=directory ^ "/host-marker.sml"
        val done=directory ^ "/host-done.sml"
        val ()=write(marker,"val runeFfiHostDone = fn () => TextIO.print \"PASS foreign projection signatures and shared abstract types\\n\"\n")
        val ()=write(done,"val ()=runeFfiHostDone()\n")
        val result=Hosts.build{host=Hosts.get name,name="ffi-projections",sources=marker :: prelude @ sources @ contracts @ [done],
          dir=directory ^ "/host",runDir=root,timeout=600,memory=2048}
        val ()=need(#built result andalso #status result=0,"projection signatures on " ^ name ^ ": " ^ #messages result ^ #output result)
        val ()=need(String.isSubstring "PASS foreign projection signatures" (#output result),"host did not finish projections")
    in say("PASS foreign projection signatures on " ^ name ^ " with Rune Basis\n") end
  fun noRegionInference subject =
    let val host=Hosts.get "mlkit"
        val wrapper=directory ^ "/mlkit-no-ri"
        val ()=mkdirs directory
        val ()=write(wrapper,"#!/bin/sh\nexec " ^ quote(#program host) ^ " -no_ri \"$@\"\n")
        val ()=Posix.FileSys.chmod(wrapper,Posix.FileSys.S.flags[Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr])
        val sources=List.concat(List.map Hosts.portable["unicode","json","language/c","ffi/model"])
          @ (if subject="target" then Hosts.portable "test/unit" else [])
          @ ["tests/lib/ffi/model/" ^ subject ^ ".sml"]
        val result=Hosts.build{host={name="mlkit",program=fromRoot wrapper,library= #library host},name="policy-no-ri",
          sources=sources,dir=directory ^ "/no-ri",runDir=root,timeout=600,memory=2048}
        val ()=need(#built result andalso #status result=0,"MLKit -no_ri: " ^ #messages result ^ #output result)
        val marker=if subject="target" then "SUMMARY 19 tests, 19 passed" else "PASS foreign policy:"
    in need(String.isSubstring marker (#output result),"MLKit -no_ri did not finish");
       say("PASS foreign " ^ subject ^ " on MLKit -no_ri; default region inference remains HOST-BUG\n") end
  fun native ()=
    let val ()=inventory "linux-x86_64" "sdl"
        val output=directory ^ "/fixture.json"
        val ()=say(command "fixture" (["bin/rune-ffi-model","policy","ffi/targets/linux-x86_64.json","tests/ffi/fixture.ffi",output,
          fromRoot "tests/ffi"] @ roots "linux-x86_64"))
        val compiled=directory ^ "/golden.rbc"
        val ()=ignore(command "compile-golden" ([env("RUNE","bin/rune")] @ contracts @ ["-o",compiled]))
        val ()=say(command "sdl-policy" (["bin/rune-ffi-model","policy","ffi/targets/linux-x86_64.json",
          "tests/ffi/model/sdl.ffi",directory ^ "/sdl-policy.json",fromRoot "ffi/sdl/upstream"] @ roots "linux-x86_64"))
    in ignore(command "golden" ["bin/runevm",compiled]);
       say "PASS foreign projection signatures and shared abstract types on Rune\n" end
  fun main["native"]=native()
    | main["windows",bits]=(need(bits="32" orelse bits="64","expected Windows width");
        let val target=if bits="32" then "windows-x86" else "windows-x86_64"
        in inventory target "win32";inventory target "sdl";
           say(command ("win32-policy-" ^ bits)(["bin/rune-ffi-model","policy","ffi/targets/" ^ target ^ ".json",
             "tests/ffi/model/win32.ffi",directory ^ "/win32-policy.json"] @ roots target)) end)
    | main["model-nori"]=noRegionInference "policy"
    | main["target-nori"]=noRegionInference "target"
    | main["goldens-prepare"]=prepare()
    | main["goldens",name]=host name
    | main _=raise Failed "expected native, windows 32|64, goldens-prepare, or goldens HOST"
end
val ()=ForeignModelChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL foreign model: " ^ (case e of ForeignModelChecks.Failed s=>s | _=>General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)
