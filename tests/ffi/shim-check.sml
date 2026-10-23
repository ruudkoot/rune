(* Independent compilation/execution of SML-generated C adapters. *)
structure ForeignShimChecks =
struct
  open Sh
  exception Failed of string
  fun need(ok,message)=if ok then () else raise Failed message
  val directory=run ^ "/ffi-shims/" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
  fun command name args=
    let val ()=mkdirs directory val out=directory ^ "/" ^ name ^ ".out" val err=directory ^ "/" ^ name ^ ".err"
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=args,dir=SOME root,stdin="",stdout=out,stderr=err,timeout=300}
    in need(status=0,name ^ " exited " ^ Int.toString status ^ ": " ^ read err ^ read out);read out end
  fun generate()=
    let val code=directory ^ "/generate.rbc" val output=directory ^ "/adapters.c"
        val ()=ignore(command "compile-generator"[env("RUNE","bin/rune"),"--library","ffi/model","tests/ffi/generate-shims.sml","-o",code])
        val ()=ignore(command "generate"["bin/runevm",code,"--runeffi-output",output])
        val ()=ignore(command "generate-again"["bin/runevm",code,"--runeffi-output",output ^ ".again"])
        val ()=need(read output=read(output ^ ".again"),"adapter generation is not deterministic")
    in output end
  fun compiler target=
    let val clang=String.tokens Char.isSpace(env("CLANG","clang"))
        fun cross triple root=clang @ ["--target=" ^ triple,"-B" ^ root ^ "/bin","-L" ^ root ^ "/lib","-I" ^ root ^ "/include","-Wl,-rpath," ^ root ^ "/lib"]
    in case target of "asan"=>String.tokens Char.isSpace(env("CC","cc"))
      | "native"=>String.tokens Char.isSpace(env("CC","cc"))
      | "linux32"=>String.tokens Char.isSpace(env("CC","cc")) @ ["-m32"]
      | "windows32"=>String.tokens Char.isSpace(env("WINCC32","i686-w64-mingw32-gcc"))
      | "windows64"=>String.tokens Char.isSpace(env("WINCC","x86_64-w64-mingw32-gcc"))
      | "aarch64"=>cross "aarch64-linux-gnu" "/usr/aarch64-linux-gnu"
      | "ppc64"=>cross "powerpc64-linux-gnu" "/usr/powerpc64-linux-gnu"
      | _=>raise Failed "unknown adapter target" end
  fun runner "aarch64"=["qemu-aarch64","-L","/usr/aarch64-linux-gnu"]
    | runner "ppc64"=["qemu-ppc64","-L","/usr/powerpc64-linux-gnu"] | runner _=[]
  fun native target=
    let val source=generate() val windows=String.isPrefix "windows" target
        val executable=directory ^ "/oracle" ^ (if windows then ".exe" else "")
        val cc=compiler target
        val sanitize=if target="asan" then ["-fsanitize=address,undefined","-fno-omit-frame-pointer"] else []
        val common=sanitize @ ["-std=c11","-Wall","-Wextra","-Werror","-pedantic","-Itests/ffi","tests/ffi/fixture.c",source]
        val ()=ignore(command "compile-oracle"(cc @ common @ ["tests/ffi/shim_oracle.c","-o",executable]))
        val facts=String.tokens Char.isSpace(command "oracle"(runner target @ [executable]))
        val ()=need(length facts=6 andalso List.all(fn s=>isSome(Int.fromString s))facts,"native adapter oracle did not return layout facts")
        val ()=say("PASS generated C adapters: " ^ target ^ ": native prototypes, aggregates, unions, macros, inline, bitfields and pointer members\n")
        val dynamic=target="native" orelse target="asan" orelse windows
        fun winpath path=String.concat(String.tokens(fn c=>c= #"\r" orelse c= #"\n")
          (command "windows-path"["wslpath","-w",fromRoot path]))
        fun path file=if windows then winpath file else file
        fun execute vm options code library=need(String.isSubstring "PASS generated C adapters:" (command("run-" ^ OS.Path.file vm)
          (vm::options @ [path code,path library] @ facts)),"SML adapter fixture did not finish")
    in if not dynamic orelse not(RuneForeign.available()) then
         say("PASS generated C adapter oracle only: " ^ target ^ "; dynamic target support remains separate\n")
       else let val library=directory ^ (if windows then "/subject.dll" else "/subject.so")
                val ()=ignore(command "compile-library"(cc @ common @
                  (if windows then ["-shared","-Wl,--kill-at"] else ["-shared","-fPIC"]) @ ["-o",library]))
                fun one(bytecode,vm)=
                  let val output=directory ^ "/" ^ bytecode ^ ".rbc"
                      val ()=ignore(command("compile-" ^ bytecode)[env("RUNE","bin/rune"),"--library","ffi/runtime",
                        "--target=" ^ bytecode,"tests/ffi/shims.sml","-o",output])
                      val ()=execute vm ["--gc-stress","7","--gc-verify"] output library
                  in if windows orelse bytecode="stack" then () else
                    List.app(fn options=>execute vm (options @ ["--gc-stress","7","--gc-verify"])output library)
                      [["--jit=all"],["--jit=all","--jit-tier=2"]] end
                val stack=if target="windows32" then "bin/runevm-stack32.exe" else if windows then "bin/runevm-stack.exe" else if target="asan" then "bin/runevm-stack-asan" else "bin/runevm-stack"
                val regs=if target="windows32" then "bin/runevm32.exe" else if windows then "bin/runevm.exe" else if target="asan" then "bin/runevm-asan" else "bin/runevm"
                val ()=(one("stack",stack);one("registers",regs))
            in if windows orelse target="asan" then () else
              let val executable=directory ^ "/native-calls"
                  val ()=ignore(command "compile-native"["bin/runeopt",directory ^ "/stack.rbc","-o",executable])
              in need(String.isSubstring "PASS generated C adapters:" (command "native-calls"(executable::library::facts)),"native SML adapter fixture did not finish") end
            end
    end
  fun host name=
    let val expected=read(generate())
        val sources=List.concat(List.map Hosts.portable["unicode","json","language/c","ffi/model"]) @ ["tests/ffi/generate-shims.sml"]
        val result=Hosts.build{host=Hosts.get name,name="adapters",sources=sources,dir=directory ^ "/" ^ name,runDir=root,timeout=300,memory=2048}
        val output=Hosts.libraryOutput name (#output result)
        val ()=need(#built result andalso #status result=0,"host adapter generator failed: " ^ name ^ ": " ^ #messages result ^ output)
        fun between([],_,acc)=rev acc
          | between(line::rest,active,acc)=if String.isSubstring "RUNEFFI_SOURCE_BEGIN" line then between(rest,true,acc)
              else if String.isSubstring "RUNEFFI_SOURCE_END" line then rev acc
              else between(rest,active,if active then line::acc else acc)
        val actual=String.concat(List.map(fn line=>line ^ "\n")(between(String.fields(fn c=>c= #"\n")output,false,[])))
        val ()=(write(directory ^ "/host.actual.c",actual);write(directory ^ "/host.expected.c",expected))
    in need(actual=expected,"host adapter generator bytes differ: " ^ name);
       say("PASS deterministic C adapter generation: " ^ name ^ " agrees with Rune\n") end
  fun main["host",name]=host name | main[target]=native target | main _=raise Failed "expected TARGET or host HOST"
end
val ()=ForeignShimChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL generated C adapters: " ^ (case e of ForeignShimChecks.Failed s=>s | _=>General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)
