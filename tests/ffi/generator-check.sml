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
        val ()=write(marker,"val ()=let val ()=print \"RUNEFFI-BEGIN\\n\" val status=RuneffiMain.main(CommandLine.name(),[\"inspect\",\"--config\",\"tests/ffi/generator/scalars.ffi\",\"--target\",\"ffi/targets/linux-x86_64.json\",\"--layout\",\"gen_record\",\"--constant\",\"GEN_HIGH\"]) val ()=print \"RUNEFFI-END\\n\" in OS.Process.exit status end\n")
        val sources=List.filter(fn file=>String.isSuffix ".sml" file)(lines(command true["sh","scripts/build-files.sh","runeffi.build"]))
        val result=Hosts.build{host=selectedHost,name="runeffi-generator",sources=sources @ [marker],
          dir=directory ^ "/host",runDir=root,timeout=600,memory=2500}
        val ()=need(#built result,"generator host did not build: " ^ name ^ ": " ^ #messages result)
        val expected=command true[generator,"inspect","--config","tests/ffi/generator/scalars.ffi","--target","ffi/targets/linux-x86_64.json",
          "--layout","gen_record","--constant","GEN_HIGH"]
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
  fun safe mode=
    let val output=directory ^ "/safe"
        val ()=ignore(command true[generator,"generate","--config","tests/ffi/generator/safe.ffi","--target","ffi/targets/linux-x86_64.json","--out",output])
        val pointer=read(output ^ "/current.build")
        val relative=case List.find(String.isPrefix "use ")(lines pointer) of SOME line=>OS.Path.dir(String.extract(line,4,NONE))
          | NONE=>raise Failed "missing safe generation pointer"
        val selected=output ^ "/" ^ relative
        val subject=directory ^ "/safe.so"
        val ()=ignore(command true[env("CC","cc"),"-std=c17","-Wall","-Wextra","-Werror","-shared","-fPIC","tests/ffi/generator/safe.c","-o",subject])
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
    | main["host",name]=host name
    | main["safe"]=safe "native"
    | main["safe-asan"]=safe "asan"
    | main _=raise Failed "expected native, safe, safe-asan or host HOST"
end
val ()=ForeignGeneratorChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL foreign generator: " ^ (case e of ForeignGeneratorChecks.Failed s=>s | _=>General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)
