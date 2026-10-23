(* Explicit target execution. No binfmt registration or target GUI is needed.
   Every command has a bounded child and retained command/output evidence. *)
structure ForeignCrossChecks =
struct
  open Sh
  exception Failed of string
  fun need(ok,message)=if ok then () else raise Failed message
  val directory=run ^ "/ffi-cross/" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
  val serial=ref 0
  fun command name arguments=
    let val n= !serial val ()=serial:=n+1 val ()=mkdirs directory
        val output=directory ^ "/" ^ Int.toString n ^ "-" ^ name
        val ()=write(output ^ ".command.json",Json.encode(Json.Array(List.map Json.String arguments)) ^ "\n")
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=arguments,dir=SOME root,stdin="",stdout=output ^ ".out",stderr=output ^ ".err",timeout=600}
        val ()=need(status=0,name ^ " exited " ^ Int.toString status ^ ": " ^ read(output ^ ".err") ^ read(output ^ ".out"))
    in read(output ^ ".out") end
  fun digest path=Hex.fromBytes(Sha256.digest(read path))
  fun field name value=case Json.member(name,value) of SOME v=>v | NONE=>raise Failed("missing fact " ^ name)
  fun text(Json.String value)=value | text _=raise Failed "string fact"
  fun number(Json.Number value)=valOf(Int.fromString value) | number _=raise Failed "integer fact"
  fun main target=
    let val ()=need(List.exists(fn s=>s=target)["linux32","aarch64","ppc64"],"expected linux32, aarch64 or ppc64")
        val profile=case target of "linux32"=>"linux-x86" | "aarch64"=>"linux-aarch64" | _=>"linux-ppc64"
        val triple=if target="aarch64" then "aarch64-linux-gnu" else "powerpc64-linux-gnu"
        val sysroot="/usr/" ^ triple
        val cc=if target="linux32" then String.tokens Char.isSpace(env("CC","cc")) @ ["-m32","-msse2","-mfpmath=sse"] else
          String.tokens Char.isSpace(env("CLANG","clang")) @ ["--target=" ^ triple,"-B" ^ sysroot ^ "/bin","-I" ^ sysroot ^ "/include","-L" ^ sysroot ^ "/lib",
            "-Wl,-rpath," ^ sysroot ^ "/lib","-Wl,-dynamic-linker," ^ sysroot ^ "/lib/" ^ (if target="aarch64" then "ld-linux-aarch64.so.1" else "ld64.so.1")]
        val runner=case target of "linux32"=>[] | "aarch64"=>[env("QEMUA64","qemu-aarch64"),"-L",sysroot] | _=>[env("QEMUPPC","qemu-ppc64"),"-L",sysroot]
        val prefix=env(case target of "linux32"=>"FFI_LINUX32_PREFIX" | "aarch64"=>"FFI_AARCH64_PREFIX" | _=>"FFI_PPC64_PREFIX","build/deps/libffi/" ^ target ^ "/install")
        val archive=prefix ^ "/lib/libffi.a"
        val receipt=prefix ^ "/rune-ffi-dependency.json"
        val ()=ignore(command "verify-pinned"["bin/rune-build","build-ffi","libffi","--target",target,"--prefix",prefix,"--verify-only"])
        val flags=["-std=c17","-Wall","-Wextra","-Werror","-pedantic","-Itests/ffi"]
        val ffi=["-I" ^ prefix ^ "/include",archive,"-ldl","-lm"]
        fun c name sources more=
          let val output=directory ^ "/" ^ name
              val ()=ignore(command ("compile-" ^ name)(cc @ flags @ sources @ more @ ["-o",output]))
          in output end
        val factsExe=c "target-facts" ["tests/ffi/target-oracle.c"] []
        val facts=Json.decode(command "target-facts"(runner @ [factsExe]))
        val expected=Json.decode(read("ffi/targets/" ^ profile ^ ".json"))
        val ()=List.app(fn name=>need(field name facts=field name expected,profile ^ " mismatch " ^ name))["charSigned","byteOrder"]
        val ()=List.app(fn name=>let val scalar=field name(field "scalars" facts)
          in need(field "size" scalar=field name(field "widths" expected) andalso field "alignment" scalar=field name(field "alignments" expected),profile ^ " scalar mismatch " ^ name) end)
          ["char","short","int","long","longLong","pointer","wchar","float","double","bool"]
        val ()=say("PASS cross target profile: " ^ profile ^ "\n")
        val oracle=c "direct-libffi-oracle" ["-DRUNEFFI_TEST_LIBFFI","tests/ffi/fixture.c","tests/ffi/variadic.c","tests/ffi/oracle.c"] ffi
        val ()=say(command "direct-libffi-oracle"(runner @ [oracle]))
        val subject=c "subject.so" ["-shared","-fPIC","tests/ffi/fixture.c","tests/ffi/variadic.c","tests/ffi/ownership.c","tests/ffi/callback-fixture.c"] ["-pthread"]
        val rune=env("RUNE","bin/rune")
        fun compile bytecode source output libraries=ignore(command("compile-" ^ bytecode ^ "-" ^ OS.Path.file source)
          ([rune,"--target=" ^ bytecode] @ List.concat(List.map(fn library=>["--library",library])libraries) @ [source,"-o",output]))
        val suffix=if target="linux32" then "32" else "-" ^ target ^ ".bin"
        fun vm "stack"="bin/runevm-stack-ffi" ^ suffix | vm _="bin/runevm-ffi" ^ suffix
        val engines=[("stack",[]),("registers",["--jit=off"])] @
          (if target="aarch64" then [("registers",["--jit=baseline","--jit-calls=1"]),("registers",["--jit=opt","--jit-calls=1"])] else [])
        fun execute bytecode options code arguments expected=
          let val output=command("execute-" ^ bytecode)(runner @ [vm bytecode] @ options @ ["--gc-stress","7","--gc-verify",code] @ arguments)
          in need(String.isSubstring expected output,"fixture omitted completion: " ^ output);say output end
        val ()=List.app(fn(source,completion,libraries)=>List.app(fn bytecode=>
          let val output=directory ^ "/" ^ bytecode ^ "-" ^ OS.Path.file source ^ ".rbc"
              val ()=compile bytecode source output libraries
          in List.app(fn(engine,options)=>if engine=bytecode then execute bytecode options output [subject] completion else ())engines end)["stack","registers"])
          [("tests/ffi/calls.sml","PASS foreign calls:",[]),("tests/ffi/memory.sml","PASS native memory marshalling:",["ffi/runtime"]),
           ("tests/ffi/owner.sml","PASS explicit native owners:",["ffi/runtime"]),("tests/ffi/callbacks.sml","PASS foreign callbacks:",[])]
        val ()=List.app(fn(source,completion)=>List.app(fn bytecode=>let val output=directory ^ "/" ^ bytecode ^ "-" ^ OS.Path.file source ^ ".rbc"
          val ()=compile bytecode source output []
          in List.app(fn(engine,options)=>if engine=bytecode then execute bytecode options output [] completion else ())engines end)["stack","registers"])
          [("tests/lang/basis.runeforeign_variadic.sml","promoted variadic signatures retain exact types and clean up"),
           ("tests/lang/basis.runeforeign_callbackstatus.sml","callback fault snapshots reset atomically and retain resource guards")]
        val generatorCode=directory ^ "/generate-shims.rbc"
        val adapters=directory ^ "/adapters.c"
        val ()=compile "registers" "tests/ffi/generate-shims.sml" generatorCode ["ffi/model"]
        val ()=ignore(command "generate-adapters"["bin/runevm",generatorCode,"--runeffi-output",adapters])
        val shimOracle=c "shim-oracle" ["tests/ffi/fixture.c",adapters,"tests/ffi/shim_oracle.c"] []
        val layout=String.tokens Char.isSpace(command "shim-oracle"(runner @ [shimOracle]))
        val ()=need(length layout=6,"shim layout oracle")
        val shimSubject=c "shim-subject.so" ["-shared","-fPIC","tests/ffi/fixture.c",adapters] []
        val ()=List.app(fn bytecode=>let val code=directory ^ "/shims-" ^ bytecode ^ ".rbc"
            val ()=compile bytecode "tests/ffi/shims.sml" code ["ffi/runtime"]
          in List.app(fn(engine,options)=>if engine=bytecode then execute bytecode options code (shimSubject::layout) "PASS generated C adapters:" else ())engines end)["stack","registers"]
        val generated=directory ^ "/safe"
        val generator=env("RUNEFFI","bin/runeffi")
        val generation=["--config","tests/ffi/generator/safe.ffi","--target","ffi/targets/" ^ profile ^ ".json","--out",generated]
        val ()=ignore(command "generate-safe"(generator::"generate"::generation))
        val pointer=read(generated ^ "/current.build")
        val ()=ignore(command "regenerate-safe"(generator::"generate"::generation))
        val ()=need(pointer=read(generated ^ "/current.build"),"cross target regeneration nondeterministic")
        val ()=ignore(command "check-safe"(generator::"check"::generation))
        val relative=case List.find(String.isPrefix "use ")(lines pointer) of SOME line=>OS.Path.dir(String.extract(line,4,NONE)) | NONE=>raise Failed "generation pointer"
        val selected=generated ^ "/" ^ relative
        val safeSubject=c "safe.so" ["-shared","-fPIC","-Itests/ffi/generator","tests/ffi/generator/safe.c",selected ^ "/shims.c"] []
        val support=["lib/ffi/marshal/bytes_sig.sml","lib/ffi/marshal/bytes.sml","lib/ffi/runtime/owner_sig.sml","lib/ffi/runtime/owner.sml",
          "lib/ffi/runtime/generated_sig.sml","lib/ffi/runtime/generated.sml"]
        val sources=support @ List.map(fn name=>selected ^ "/" ^ name)["raw_sig.sml","raw.sml","public_sig.sml","public.sml"] @ ["tests/ffi/generator/safe-client.sml"]
        val ()=List.app(fn bytecode=>let val code=directory ^ "/safe-" ^ bytecode ^ ".rbc"
          val ()=ignore(command("compile-safe-" ^ bytecode)([rune,"--target=" ^ bytecode,"--library","ffi/runtime"] @ sources @ ["-o",code]))
          in List.app(fn(engine,options)=>if engine=bytecode then execute bytecode options code [safeSubject] "PASS generated safe registry cleanup" else ())engines end)["stack","registers"]
        val toolchain=command "compiler-version" (cc @ ["--version"])
        val emulator=if null runner then "native Linux32 process" else command "runner-version" [hd runner,"--version"]
        val record=Json.Object[("target",Json.String target),("profile_sha256",Json.String(digest("ffi/targets/" ^ profile ^ ".json"))),
          ("dependency_sha256",Json.String(digest receipt)),("static_library_sha256",Json.String(digest archive)),
          ("source_archive_sha256",field "archive_sha256"(field "config"(Json.decode(read receipt)))),
          ("compiler",Json.String toolchain),("runner",Json.String emulator),("stack_vm_sha256",Json.String(digest(vm "stack"))),
          ("register_vm_sha256",Json.String(digest(vm "registers"))),("result",Json.String "all cross fixtures passed")]
        val ()=write(directory ^ "/receipt.json",Json.encode record ^ "\n")
    in say("PASS explicit cross FFI acceptance: " ^ target ^ "; evidence " ^ directory ^ "\n") end
end
val ()=(case CommandLine.arguments() of [target]=>ForeignCrossChecks.main target | _=>raise Fail "expected TARGET") handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL cross FFI acceptance: " ^ (case e of ForeignCrossChecks.Failed why=>why | _=>General.exnMessage e) ^ "\n");OS.Process.exit OS.Process.failure)
