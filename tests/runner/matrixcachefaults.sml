(* Real cache imports, including the legacy CRC sidecar. Counter wrappers
   expose whether the compiler actually ran; library edits remain private. *)
structure MatrixCacheFaults =
struct
  open Sh
  fun need (ok,why)=if ok then () else raise Fail ("matrix cache: " ^ why)
  fun copyTree source target=if isDir source then
       (mkdirs target;List.app (fn name => copyTree (source ^ "/" ^ name) (target ^ "/" ^ name)) (entries source))
       else MatrixLoad.copy (source,target)
  fun fixture mode () =
    let val compiler=fromRoot "bin/compiler"
        val source=run ^ "/source.sml"
        val cfg : MatrixModel.config={spec="rune",id="rune",library=MatrixModel.RuneBasis,target=MatrixModel.Stack,
             compiler=MatrixModel.Rune compiler,command=compiler,vm=env ("CACHE_FIXTURE_VM",""),extra="",version="fixture"}
        val cache=run ^ "/cache/cached.dir"
        val ()=if mode="create" orelse mode="other-vm" then MatrixPrepare.prepare cfg run else ()
    in if mode="legacy-key" then
         (mkdirs (run ^ "/legacy");write (cache ^ "/prog.key",MatrixLoad.legacyKey (run ^ "/legacy") [source]))
       else
         let val ctx=MatrixPrepare.context cfg run [] MatrixLoad.NoImage
             val result=MatrixLoad.load ctx (run ^ "/work/cached.dir") MatrixLoad.Run [source]
         in need (#loaded result andalso #status result=0 andalso String.isSubstring "SUMMARY 1 checks, 0 failed" (#output result),
                  "actual cache program did not run: " ^ #messages result ^ #output result) end
    end
  fun one () =
    let val dir=run ^ "/matrix-cache-faults"
        val privateRoot=dir ^ "/root with spaces"
        val ()=(MatrixLoad.remove dir;mkdirs (privateRoot ^ "/bin"))
        val ()=copyTree (fromRoot "lib/basis") (privateRoot ^ "/lib/basis")
        val ()=List.app (fn dir => copyTree (fromRoot dir) (privateRoot ^ "/" ^ dir)) ["tests/basis/host","tests/basis/xc2","tools/generate/data"]
        val ()=List.app (fn file => MatrixLoad.copy (fromRoot file,privateRoot ^ "/" ^ file))
             ["runtime/prims.def","tests/runner/matrixmodel.sml","tests/runner/matrixprobe.sml",
              "tests/runner/matrixload.sml","tests/runner/matrixprepare.sml","tests/runner/matrixsuite.sml"]
        val otherVM=dir ^ "/other-vm"
        val ()=write (otherVM,"#!/bin/sh\nexec " ^ quote (fromRoot "bin/runevm-stack") ^ " --gc-stress 101 \"$@\"\n")
        val ()=Posix.FileSys.chmod (otherVM,Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr])
        val compiler=privateRoot ^ "/bin/compiler"
        val counter=dir ^ "/compiler-calls"
        val ()=write (compiler,"#!/bin/sh\nprintf 'compile\\n' >> " ^ quote counter ^ "\nexec " ^ quote (fromRoot "bin/rune-mlton")
                             ^ " --target=stack --lib " ^ quote (privateRoot ^ "/lib") ^ " \"$@\"\n")
        val ()=Posix.FileSys.chmod (compiler,Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.ixusr])
        val source=dir ^ "/source.sml"
        val text="val () = print \"PASS cache/fixture\\nSUMMARY 1 checks, 0 failed\\n\"\n"
        val ()=write (source,text)
        val cache=dir ^ "/cache/cached.dir"
        val ()=mkdirs cache
        val payload=env ("RUNE_MATRIX_FIXTURE_TOOL",fromRoot "bin/rune-matrix.rbc")
        fun invoke mode =
          let val ()=write (counter,"")
              val environment=setEnv ("RUNE_TEST_ROOT",privateRoot) o setEnv ("RUNE_TEST_RUN",dir)
                     o setEnv ("CACHE_FIXTURE_VM",if mode="other-vm" then otherVM else fromRoot "bin/runevm-stack")
                     o setEnv ("RUNE_MATRIX_BYTECODE",if mode="create" then "" else dir ^ "/cache")
              val status=Children.exec {addressSpace=NONE,cpuTime=SOME 60,fileSize=SOME (64*1024*1024),core=SOME 0} environment
                 {cmd=[fromRoot "bin/runevm",payload,"matrix-cache-fixture",mode],dir=SOME root,stdin="",
                  stdout=dir ^ "/" ^ mode ^ ".out",stderr=dir ^ "/" ^ mode ^ ".err",timeout=60}
              val ()=need (status=0,"fixture failed: " ^ mode ^ ": " ^ read (dir ^ "/" ^ mode ^ ".out") ^ read (dir ^ "/" ^ mode ^ ".err"))
          in length (lines (read counter)) end
        val ()=need (invoke "create"=1,"cold import did not compile exactly once")
        val key=read (dir ^ "/work/cached.dir/prog.key")
        val ()=MatrixLoad.copy (dir ^ "/work/cached.dir/prog.rbc",dir ^ "/original.rbc")
        fun restore ()=(MatrixLoad.copy (dir ^ "/original.rbc",cache ^ "/prog.rbc");write (cache ^ "/prog.key",key))
        val ()=restore ()
        val ()=need (invoke "v2-hit"=0,"valid version-2 bytecode was recompiled")
        val ()=need (invoke "other-vm"=0,"changing only the execution VM invalidated reusable bytecode")
        val ()=need (invoke "legacy-key"=0,"legacy checksum adapter invoked the compiler")
        val ()=need (invoke "legacy-hit"=0,"valid legacy bytecode was recompiled")
        val ()=write (cache ^ "/prog.key","planted wrong key\n")
        val ()=need (invoke "bad-key"=1,"bad sidecar was trusted")
        val ()=restore ()
        val ()=write (cache ^ "/prog.rbc","")
        val ()=need (invoke "empty-payload"=1,"empty cached bytecode was trusted")
        val ()=restore ()
        val saved=OS.FileSys.modTime compiler
        val ()=OS.FileSys.setTime (compiler,SOME (Time.+ (OS.FileSys.modTime (cache ^ "/prog.rbc"),Time.fromSeconds 2)))
        val ()=need (invoke "newer-compiler"=1,"bytecode older than its compiler was trusted")
        val ()=OS.FileSys.setTime (compiler,SOME saved)
        val library=privateRoot ^ "/lib/basis/list.sml"
        val saved=OS.FileSys.modTime library
        val ()=OS.FileSys.setTime (library,SOME (Time.+ (OS.FileSys.modTime (cache ^ "/prog.rbc"),Time.fromSeconds 2)))
        val ()=need (invoke "newer-library"=1,"bytecode older than its library was trusted")
        val ()=OS.FileSys.setTime (library,SOME saved)
        val saved=OS.FileSys.modTime source
        (* Change a same-length label while keeping the old timestamp. *)
        val ()=write (source,"val () = print \"PASS cache/changed\\nSUMMARY 1 checks, 0 failed\\n\"\n")
        val ()=OS.FileSys.setTime (source,SOME saved)
        val ()=need (invoke "changed-source"=1,"source content changed without invalidating bytecode")
    in say "PASS matrix legacy/version-2 cache import and invalidation\n" end
end
