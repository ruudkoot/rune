(* Generator publication and execution checks use independent C and the
   repository's existing bounded child-process/host coordination. *)
structure ForeignGeneratorChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok,message)=if ok then () else raise Failed message
  val directory=run ^ "/ffi-generator/" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
  val counter=ref 0
  fun command expected arguments=
    let val n= !counter val ()=counter:=n+1 val ()=mkdirs directory
        val output=directory ^ "/command-" ^ Int.toString n
        val errors=output ^ ".err"
        val status=Children.exec Subprocess.unlimited (fn e=>e){cmd=arguments,dir=SOME root,stdin="",stdout=output,stderr=errors,timeout=600}
        val ()=need((status=0)=expected,"command status " ^ Int.toString status ^ ": " ^ String.concatWith " " arguments ^ "\n" ^ read errors ^ read output)
    in read output ^ (if expected then "" else read errors) end
  val generator=env("RUNEFFI","bin/runeffi")
  val options=["--config",directory ^ "/input/scalars.ffi","--target","ffi/targets/linux-x86_64.json",
    "--out",directory ^ "/generated","--layout","gen_record","--constant","GEN_HIGH","--constant","GEN_NEGATIVE"]
  fun generate operation=command true (generator::operation::options)
  fun current ()=read(directory ^ "/generated/current.build")
  fun setPath pointer=case List.find(String.isPrefix "use ")(lines pointer) of
      SOME line=>directory ^ "/generated/" ^ OS.Path.dir(String.extract(line,4,NONE))
    | NONE=>raise Failed "missing immutable generation pointer"
  fun native ()=
    let val ()=mkdirs(directory ^ "/input")
        val ()=List.app(fn file=>write(directory ^ "/input/" ^ file,read("tests/ffi/generator/" ^ file)))
          ["scalars.ffi","scalars.h","transitive.h"]
        val ()=say(generate "generate") val first=current()
        val ()=ignore(generate "generate")
        val ()=need(first=current(),"second generation changed publication")
        val ()=ignore(generate "check")
        val inspection=Json.decode(generate "inspect")
        val ()=need(isSome(Json.member("manifest",inspection)),"inspection omitted declaration/layout report")
        val set=setPath first
        val ()=need(not(String.isSubstring root(read(set ^ "/dependencies.json"))),"generated dependency manifest leaked checkout path")
        val subject=directory ^ "/subject.so"
        val ()=ignore(command true [env("CC","cc"),"-std=c17","-Wall","-Wextra","-Werror","-shared","-fPIC",
          "tests/ffi/generator/scalars.c","-o",subject])
        val bytecode=directory ^ "/client.rbc"
        val ()=ignore(command true ([env("RUNE","bin/rune"),"--library","ffi/runtime",
          "lib/ffi/runtime/generated_sig.sml","lib/ffi/runtime/generated.sml"] @
          List.map(fn file=>set ^ "/" ^ file)["raw_sig.sml","raw.sml","public_sig.sml","public.sml"] @
          ["tests/ffi/generator/client.sml","-o",bytecode]))
        val ()=say(command true [env("RUNEVM","bin/runevm"),"--gc-stress","7","--gc-verify",bytecode,subject])
        val apiSources=case Json.member("artifacts",inspection) of SOME(Json.Array values)=>
              List.mapPartial(fn Json.String path=>if String.isSuffix "/public_sig.sml" path andalso String.isPrefix "api/" path then SOME path else NONE | _=>NONE)values
            | _=>raise Failed "inspection artifacts"
        val api=case apiSources of [path]=>OS.Path.dir path | _=>raise Failed "signature identity"
        val nativeBuild=directory ^ "/native.build"
        val mockBuild=directory ^ "/mock.build"
        val client=fromRoot "tests/ffi/generator/client.sml"
        val ()=write(nativeBuild,"use generated/current.build\n" ^ client ^ "\n")
        val ()=write(mockBuild,"generated/" ^ api ^ "/public_sig.sml\nimplements GeneratedScalars = " ^
          fromRoot "tests/ffi/generator/mock.sml" ^ " end\ngenerated/" ^ api ^ "/virtual.sml\n" ^ client ^ "\n")
        val cache=directory ^ "/cache"
        val nativeBytecode=directory ^ "/native-build.rbc"
        val mockBytecode=directory ^ "/mock-build.rbc"
        val support=["lib/ffi/runtime/generated_sig.sml","lib/ffi/runtime/generated.sml"]
        val ()=write(nativeBuild,String.concat(List.map(fn f=>fromRoot f ^ "\n")support) ^ "use generated/current.build\n" ^ client ^ "\n")
        val ()=ignore(command true[env("RUNE","bin/rune"),"--library","ffi/runtime","--cache-dir",cache,"--build",nativeBuild,"-o",nativeBytecode])
        val ()=say(command true[env("RUNEVM","bin/runevm"),nativeBytecode,subject])
        val ()=ignore(command true[env("RUNE","bin/rune"),"--library","ffi/runtime","--cache-dir",cache,"--build",mockBuild,"--explain-rebuild","-o",mockBytecode])
        val explanation=read(directory ^ "/command-" ^ Int.toString(!counter-1) ^ ".err")
        val ()=need(String.isSubstring("from the cache " ^ client)explanation,"implementation switch recompiled the unchanged virtual client: " ^ explanation)
        val ()=say(command true[env("RUNEVM","bin/runevm"),mockBytecode,"unused-mock-library"])
        val originalHeader=read(directory ^ "/input/transitive.h")
        val ()=write(directory ^ "/input/transitive.h",originalHeader ^ "\n#define GEN_CHANGED 1\n")
        val stale=command false (generator::"check"::options)
        val ()=need(String.isSubstring "missing generated file" stale orelse String.isSubstring "stale" stale,"transitive dependency edit was not diagnosed")
        val ()=need(first=current(),"check changed publication")
        val ()=ignore(generate "generate") val second=current()
        val ()=need(first<>second,"transitive header edit did not invalidate generation")
        val ()=write(directory ^ "/input/scalars.ffi","{}")
        val ()=ignore(command false (generator::"generate"::options))
        val ()=need(second=current(),"failed policy generation changed publication")
        val ()=write(directory ^ "/input/scalars.ffi",read "tests/ffi/generator/scalars.ffi")
        val final=setPath second
        val original=read(final ^ "/raw.sml")
        val ()=write(final ^ "/raw.sml",original ^ "\n(* edited generated file *)\n")
        val edited=command false (generator::"check"::options)
        val ()=need(String.isSubstring "changed or stale" edited,"edited artifact not diagnosed")
        val ()=write(final ^ "/raw.sml",original)
        val ()=ignore(generate "check")
        val ()=OS.FileSys.remove(final ^ "/raw.sml")
        val missing=command false (generator::"check"::options)
        val ()=need(String.isSubstring "missing generated file" missing,"missing artifact not diagnosed")
        val ()=write(final ^ "/raw.sml",original)
        val ()=ignore(generate "check")
    in say "PASS deterministic regeneration, transitive invalidation, unchanged check, failed publication and edited/missing artifacts\n" end
  fun host name=
    let val ()=mkdirs directory
        val noRegions=name="mlkit-no-ri"
        val actualName=if noRegions then "mlkit" else name
        val original=Hosts.get actualName
        val selectedHost=if not noRegions then original else
          let val wrapper=directory ^ "/mlkit-no-ri"
              val ()=write(wrapper,"#!/bin/sh\nexec " ^ quote(#program original) ^ " -no_ri \"$@\"\n")
              val ()=Posix.FileSys.chmod(wrapper,Posix.FileSys.S.flags[Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr])
          in {name="mlkit",program=wrapper,library= #library original} end
        val marker=directory ^ "/entry.sml"
        val inspectionArguments=["inspect","--config","tests/ffi/generator/scalars.ffi","--target","ffi/targets/linux-x86_64.json", "--layout","gen_record","--constant","GEN_HIGH"]
        val safeArguments=["inspect","--config","tests/ffi/generator/safe.ffi","--target","ffi/targets/linux-x86_64.json"]
        fun smlList values="[" ^ String.concatWith "," (List.map(fn text=>"\"" ^ String.toString text ^ "\"")values) ^ "]"
        val ()=write(marker,"val ()=let val ()=print \"RUNEFFI-BEGIN\\n\" val first=RuneffiMain.main(CommandLine.name()," ^ smlList inspectionArguments ^ ") " ^
          "val second=RuneffiMain.main(CommandLine.name()," ^ smlList safeArguments ^ ") val ()=print \"RUNEFFI-END\\n\" " ^
          "in OS.Process.exit(if OS.Process.isSuccess first andalso OS.Process.isSuccess second then OS.Process.success else OS.Process.failure) end\n")

        val sources=List.filter(fn file=>String.isSuffix ".sml" file)(lines(command true["sh","scripts/build-files.sh","runeffi.build"]))
        val result=Hosts.build{host=selectedHost,name="runeffi-generator",sources=sources @ [marker],
          dir=directory ^ "/host",runDir=root,timeout=600,memory=2500}
        val ()=need(#built result,"generator host did not build: " ^ name ^ ": " ^ #messages result)
        val expected=command true(generator::inspectionArguments) ^ command true(generator::safeArguments)
        val actual= #output result
        (* Native interpreters print elaboration chatter. Explicit markers
           delimit the complete payload, including every internal blank line. *)
        fun afterMarker []=raise Failed "host omitted inspection marker"
          | afterMarker(line::rest)=if line="RUNEFFI-BEGIN" then rest else afterMarker rest
        fun throughMarker []=raise Failed "host omitted completion marker"
          | throughMarker(line::rest)=if line="RUNEFFI-END" then [] else line::throughMarker rest
        val payload=(SOME(String.concatWith "\n" (throughMarker(afterMarker(String.fields(fn c=>c= #"\n")actual))) ^ "\n")handle Failed _=>NONE)
        val passed= #status result=0 andalso payload=SOME expected
        val deviation=Expectations.find(Expectations.read "tests/ffi/generator-deviations.txt",
          {way="native:" ^ name,path="generator.inspect",label=NONE})
    in case deviation of NONE=>
         (need(passed,"generator host " ^ name ^ " status " ^ Int.toString(#status result) ^ ": " ^ actual);
          say("PASS generator inspection agreement on " ^ name ^ "\n"))
       | SOME line=>
         (need(not passed,"stale generator host deviation: " ^ Expectations.describe line);
          need(#status result<>125 andalso #status result<>124,"generator host did not complete its supervised process");
          say("EXPLAINED generator " ^ name ^ ": " ^ #category line ^ ": " ^ #reason line ^
            " (status " ^ Int.toString(#status result) ^ "; " ^ directory ^ "/host)\n"))
    end
  fun publication ()=
    let val ()=mkdirs directory
        val output=directory ^ "/fault-publication"
        fun arguments operation output constant=[generator,operation,"--config","tests/ffi/generator/scalars.ffi",
          "--target","ffi/targets/linux-x86_64.json","--out",output,"--constant",constant]
        fun generate output constant=ignore(command true(arguments "generate" output constant))
        fun check output constant=ignore(command true(arguments "check" output constant))
        val ()=generate output "GEN_HIGH"
        val first=read(output ^ "/current.build")
        val status=Children.exec{addressSpace=NONE,cpuTime=SOME 60,fileSize=SOME 512,core=SOME 0}(fn e=>e)
          {cmd=arguments "generate" output "GEN_NEGATIVE",dir=SOME root,stdin="",stdout=directory ^ "/interrupted.out",
           stderr=directory ^ "/interrupted.err",timeout=60}
        val ()=need(status<>0,"file-size fault did not interrupt generation")
        val ()=need(first=read(output ^ "/current.build"),"interrupted artifact write changed current.build")
        val ()=check output "GEN_HIGH"
        val ()=generate output "GEN_NEGATIVE"
        val second=read(output ^ "/current.build")
        val ()=need(first<>second,"fault fixture did not produce distinct complete generations")
        val ()=check output "GEN_NEGATIVE"
        fun start arguments name=
          let val mode=Posix.FileSys.S.flags[Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr]
              val input=Posix.FileSys.openf("/dev/null",Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags[])
              val out=Posix.FileSys.creat(directory ^ "/" ^ name ^ ".out",mode)
              val err=Posix.FileSys.creat(directory ^ "/" ^ name ^ ".err",mode)
              fun close()=(Posix.IO.close input;Posix.IO.close out;Posix.IO.close err)
              fun fd value=SysWord.toInt(Posix.FileSys.fdToWord value)
              val pid=(Subprocess.spawn{program=generator,args=arguments,env=NONE,search=false,dir=SOME root,
                stdin=SOME(fd input),stdout=SOME(fd out),stderr=SOME(fd err),group=false,limits=Subprocess.unlimited}
                handle error=>(close();raise error))
          in close();(pid,name) end
        fun stop(pid,_)=(Posix.Process.kill(Posix.Process.K_PROC(Posix.Process.wordToPid(SysWord.fromInt pid)),Posix.Signal.kill)
              handle OS.SysErr _=>();ignore(Subprocess.wait(SOME pid)) handle OS.SysErr _=>())
        fun race name constants allowed=
          let val output=directory ^ "/" ^ name
              val children=ListPair.map(fn(i,constant)=>start(arguments "generate" output constant)(name ^ Int.toString i))
                (List.tabulate(length constants,fn i=>i),constants)
              val live=ref children
              val started=Runtime.clock()
              fun observe()=if exists(output ^ "/current.build") then
                    let val current=read(output ^ "/current.build")
                    in need(List.exists(fn pointer=>pointer=current)allowed,"concurrent publication exposed partial current.build") end else ()
              fun wait [] failed=if null failed then () else raise Failed(String.concatWith "\n" failed)
                | wait pending failed=
                  let val ()=observe()
                      val ()=if Time.>(Time.-(Runtime.clock(),started),Time.fromSeconds 120) then
                        (List.app stop pending;live:=[];raise Failed "concurrent publication timed out") else ()
                      fun poll([],remaining,failed)=(remaining,failed)
                        | poll((entry as(pid,name))::rest,remaining,failed)=case Subprocess.poll(SOME pid) of
                            NONE=>poll(rest,entry::remaining,failed)
                          | SOME{status=Posix.Process.W_EXITED,...}=>poll(rest,remaining,failed)
                          | SOME _=>poll(rest,remaining,("publication writer failed: " ^ name ^ ": " ^ read(directory ^ "/" ^ name ^ ".err"))::failed)
                      val(remaining,failed)=poll(pending,[],failed)
                      val ()=live:=remaining
                  in if null remaining then wait [] failed else (OS.Process.sleep(Time.fromMilliseconds 1);wait remaining failed) end
              val ()=(wait children [] handle error=>(List.app stop(!live);live:=[];raise error))
              val current=read(output ^ "/current.build")
              val ()=need(List.exists(fn pointer=>pointer=current)allowed,"concurrent writers did not publish a complete allowed generation")
              val constant=if current=first then "GEN_HIGH" else "GEN_NEGATIVE"
          in check output constant end
        val ()=race "concurrent-same" ["GEN_HIGH","GEN_HIGH"] [first]
        val ()=race "concurrent-different" ["GEN_HIGH","GEN_NEGATIVE"] [first,second]
    in say "PASS interrupted write preserves complete publication; concurrent same/different writers publish complete immutable sets\n" end
  fun windows bits=
    let val ()=need(bits="32" orelse bits="64","Windows width must be 32 or 64")
        val stage=WindowsDir.directory() ^ "/runeffi-generator-" ^ bits ^ "-" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
        val ()=mkdirs(stage ^ "/input")
        fun copy source destination=
          let val input=BinIO.openIn source val output=BinIO.openOut destination
          in ((BinIO.output(output,BinIO.inputAll input);BinIO.closeIn input;BinIO.closeOut output)
            handle error=>(BinIO.closeIn input handle _=>();BinIO.closeOut output handle _=>();raise error)) end
        val ()=List.app(fn name=>copy("tests/ffi/generator/" ^ name)(stage ^ "/input/" ^ name))
          ["scalars.ffi","scalars.h","transitive.h","safe.ffi","safe.h"]
        val ()=List.app(fn target=>copy("ffi/targets/" ^ target ^ ".json")(stage ^ "/" ^ target ^ ".json"))
          ["linux-x86_64","windows-x86","windows-x86_64"]
        val bytecode=stage ^ "/runeffi.rbc"
        val ()=copy(env("RUNEFFI_RBC","bin/runeffi.rbc"))bytecode
        fun winpath path=Hosts.trim(String.translate(fn #"\r"=>"" | c=>str c)(command true["wslpath","-w",path]))
        val vm=fromRoot(env(if bits="32" then "RUNEVM_WIN32" else "RUNEVM_WIN64",if bits="32" then "bin/runevm32.exe" else "bin/runevm.exe"))
        fun native arguments=command true(vm::winpath bytecode::arguments)
        val expected=command true[generator,"inspect","--config",stage ^ "/input/safe.ffi","--target",stage ^ "/linux-x86_64.json"]
        val actual=native["inspect","--config",winpath(stage ^ "/input/safe.ffi"),"--target",winpath(stage ^ "/linux-x86_64.json")]
        fun normalize text=String.translate(fn #"\r"=>"" | c=>str c)text
        val ()=need(normalize actual=expected,"Windows " ^ bits ^ " complete generator inspection differs from Linux")
        val target=if bits="32" then "windows-x86" else "windows-x86_64"
        val config=stage ^ "/input/scalars.ffi" val profile=stage ^ "/" ^ target ^ ".json"
        val output=stage ^ "/generated"
        fun options path=["--config",path config,"--target",path profile,"--out",path output,
          "--constant","GEN_HIGH","--constant","GEN_NEGATIVE","--layout","gen_record"]
        val ()=ignore(native("generate"::options winpath))
        val first=read(output ^ "/current.build")
        val ()=ignore(native("generate"::options winpath))
        val ()=need(first=read(output ^ "/current.build"),"Windows regeneration changed immutable generation")
        val ()=ignore(native("check"::options winpath))
        val ()=ignore(command true(generator::"check"::options(fn path=>path)))
    in say("PASS Windows " ^ bits ^ " CLI full inspection agrees with Linux; native target generate/check/regeneration and cross-host artifact check\n") end
  fun safe mode=
    let val output=directory ^ "/safe"
        val ()=ignore(command true[generator,"generate","--config","tests/ffi/generator/safe.ffi","--target","ffi/targets/linux-x86_64.json","--out",output])
        val pointer=read(output ^ "/current.build")
        val relative=case List.find(String.isPrefix "use ")(lines pointer) of SOME line=>OS.Path.dir(String.extract(line,4,NONE))
          | NONE=>raise Failed "missing safe generation pointer"
        val selected=output ^ "/" ^ relative
        val subject=directory ^ "/safe.so"
        val shim=selected ^ "/shims.c"
        val ()=ignore(command true([env("CC","cc"),"-std=c17","-Wall","-Wextra","-Werror","-shared","-fPIC","-Itests/ffi/generator",
          "tests/ffi/generator/safe.c"] @ (if exists shim then [shim] else []) @
          (if mode="asan" then ["-fsanitize=address,undefined","-fno-omit-frame-pointer"] else []) @ ["-o",subject]))
        val support=["lib/ffi/marshal/bytes_sig.sml","lib/ffi/marshal/bytes.sml","lib/ffi/runtime/owner_sig.sml","lib/ffi/runtime/owner.sml",
          "lib/ffi/runtime/generated_sig.sml","lib/ffi/runtime/generated.sml"]
        val sources=support @ List.map(fn file=>selected ^ "/" ^ file)["raw_sig.sml","raw.sml","public_sig.sml","public.sml"] @ ["tests/ffi/generator/safe-client.sml"]
        fun one target vm options=
          let val bytecode=directory ^ "/safe-" ^ target ^ ".rbc"
              val ()=ignore(command true([env("RUNE","bin/rune"),"--target=" ^ target,"--library","ffi/runtime"] @ sources @ ["-o",bytecode]))
              val output=command true(vm::options @ ["--gc-stress","7","--gc-verify",bytecode,subject])
              val ()=need(String.isSubstring "PASS generated safe registry cleanup" output,"generated safe fixture did not complete")
          in say output;bytecode end
    in if mode="asan" then
         (ignore(one "stack" (env("RUNEVM_STACK_ASAN","bin/runevm-stack-asan")) []);
          ignore(one "registers" (env("RUNEVM_ASAN","bin/runevm-asan")) ["--jit=all","--jit-tier=2"]))
       else let val stack=one "stack" (env("RUNEVM_STACK","bin/runevm-stack")) []
                val _=one "registers" (env("RUNEVM","bin/runevm")) []
                val _=one "registers" (env("RUNEVM","bin/runevm")) ["--jit=off"]
                val _=one "registers" (env("RUNEVM","bin/runevm")) ["--jit=all","--jit-tier=2"]
                val native=directory ^ "/safe-native"
                val ()=ignore(command true[env("RUNEOPT","bin/runeopt"),stack,"-o",native])
            in say(command true[native,subject]) end
    end
  fun main["native"]=native()
    | main["publication"]=publication()
    | main["windows",bits]=windows bits
    | main["host",name]=host name
    | main["safe"]=safe "native"
    | main["safe-asan"]=safe "asan"
    | main _=raise Failed "expected native, publication, windows BITS, safe, safe-asan or host HOST"
end
val ()=ForeignGeneratorChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL foreign generator: " ^ (case e of ForeignGeneratorChecks.Failed s=>s | _=>General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)
