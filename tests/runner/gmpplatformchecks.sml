(* Platform bytecode, fork and image matrix. Builds preserve the disabled
   payloads before enabling GMP, so both sides have independently recorded
   binary identities throughout every producer/consumer combination. *)
structure GMPPlatformChecks =
struct
  open IntInfChecks
  val platformInfo=[("native","runevm","runevm-sml",true),("linux32","runevm32","runevm32",false),
       ("ppc64","runevm-ppc64","runevm-ppc64",false),("aarch64","runevm-aarch64","runevm-aarch64",true),
       ("windows64","runevm.exe","runevm.exe",true),("windows32","runevm32.exe","runevm32.exe",false)]
  fun prepare (c : context) prefix jobs () =
    let val ()=need (jobs>0,"cross preparation needs positive jobs")
        val commands=[["make","-j",Int.toString jobs,"windows","portability","bin/runevm-sml","GMP=no"],
                      ["make","-j",Int.toString jobs,"windows","portability","vm","boot","GMP=yes","GMP_PREFIX=" ^ fromRoot prefix]]
        val ()=mkdirs (#directory c)
        val ()=write (path c "commands.json",Json.encode (Json.Array (List.map (Json.Array o List.map Json.String) commands)) ^ "\n")
        val disabled=GMPChecks.process c "disabled" root 1800 [] (hd commands)
        val ()=success disabled
        val free=path c "sml-vms"
        val ()=mkdirs free
        val binaries=["runevm-sml","runevm32","runevm-ppc64","runevm-ppc64.bin","runevm-aarch64","runevm-aarch64.bin","runevm.exe","runevm32.exe"]
        fun preserve name=
          let val source=fromRoot ("bin/" ^ name)
              val target=free ^ "/" ^ name
          in Incremental.copy source target;Posix.FileSys.chmod (target,Posix.FileSys.ST.mode (Posix.FileSys.stat source)) end
        val ()=List.app preserve binaries
        val ()=write (free ^ "/hashes.json",Json.encode (Json.Object (List.map (fn name => (name,Json.String (GMPChecks.hash (free ^ "/" ^ name)))) binaries)) ^ "\n")
        val ()=List.app (fn platform => List.app (fn file => Incremental.copy (fromRoot ("build/gmp/" ^ platform ^ "/" ^ file))
                         (free ^ "/configs/" ^ platform ^ "/" ^ file)) ["config.json","config.h","linked.json"])
                    ["linux32","ppc64","aarch64","windows64","windows32"]
        val enabled=GMPChecks.process c "enabled" root 1800 [] (List.nth (commands,1))
        val ()=success enabled
    in say ("PASS preserved GMP-free platform binaries in " ^ free ^ "\n") end
  fun cross (c : context) free selected () =
    let val selected=if null selected then platformInfo else
             (need (List.all (fn name => List.exists (fn (p,_,_,_) => p=name) platformInfo) selected,"unknown cross platform");
              List.filter (fn (name,_,_,_) => List.exists (fn wanted => wanted=name) selected) platformInfo)
        val free=fromRoot free
        val semantics=semantic c (#smlVM c) ["--intinf=sml"]
        val fixtures=field "fragments" (fixture "platform")
        fun compile name=IntInfChecks.compile c name (string (field name fixtures)) "registers" ["--allow-prim"]
        val image=compile "image"
        val limit=compile "limit"
        val fork=compile "fork"
        fun run label directory args=GMPChecks.process c label directory 180 [] args
        val windows=if List.exists (fn (name,_,_,_) => String.isPrefix "windows" name) selected then
             let val suffix=SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
             in SOME (WindowsDir.directory () ^ "/intinf-cross-" ^ suffix) end else NONE
        val reports=ref [] : (string * Json.value) list ref
        val imageReports=ref [] : Json.value list ref
        val images=ref [] : (string * string) list ref
        val consumers=ref [] : (string * string * string list * bool) list ref
        val counts=ref [] : (string * string) list ref
        fun report status=Json.Object [("platforms",Json.Object (List.rev (!reports))),("images",Json.Array (List.rev (!imageReports))),
              ("commands",Json.Number (Int.toString (!(#sequence c)))),("result",Json.String status),
              ("semantic_bytecode_sha256",Json.String (GMPChecks.hash semantics))]
        fun save status=write (path c "report.json",Json.encode (report status) ^ "\n")
        fun platform (name,binary,freeBinary,jit) =
          let val vm=fromRoot ("bin/" ^ binary)
              val freeVM=free ^ "/" ^ freeBinary
              val directory=if String.isPrefix "windows" name then valOf windows ^ "/" ^ name else path c name
              val ()=mkdirs directory
              val ()=List.app (fn (file,name) => Incremental.copy file (directory ^ "/" ^ name))
                    [(semantics,"checks.rbc"),(image,"image.rbc"),(limit,"limit.rbc"),(fork,"fork.rbc")]
              fun version (label,vm)=
                let val result=run (name ^ "-" ^ label ^ "-version") directory [vm,"--version"]
                    val ()=success result
                    val ()=need (String.isSubstring "GMP headers " (#output result)=(label="enabled"),"cross platform enabled/disabled binary was not preserved: " ^ name)
                in (label,Json.String (#output result)) end
              val versions=List.map version [("enabled",vm),("disabled",freeVM)]
              val tierInfo=[("off",["--jit=off"])] @ (if jit then [("1",["--jit=all","--jit-tier=1"]),("2",["--jit=all","--jit-tier=2"])] else [])
              val localCounts=ref [] : (string * Json.value) list ref
              val nativeStats=ref [] : (string * Json.value) list ref
              fun backend (label,vm,mode) =
                let val common=[vm,"--intinf=" ^ mode,"--heap-limit","536870912","--intinf-stats"]
                    val tierCounts=ref [] : string list ref
                    fun tier (tier,flags)=
                      let val result=run (name ^ "-" ^ label ^ "-" ^ tier) directory
                              (common @ ["--intinf-max-bits","1048576","--count"] @ flags @ ["checks.rbc"])
                          val ()=output result "current: 1154 checks\noracle: 1154 checks\n"
                          val ()=correctStats result (label="gmp")
                          val count=case List.find (String.isPrefix "runevm: count: ") (lines (#errors result)) of
                               SOME text => String.extract (text,size "runevm: count: ",NONE) | NONE => raise Failed "missing cross instruction counts"
                      in tierCounts:=count :: !tierCounts;localCounts:=(label ^ "/" ^ tier,Json.String count) :: !localCounts;
                         nativeStats:=(label ^ "/" ^ tier,Json.String (#errors result)) :: !nativeStats end
                    val ()=List.app tier tierInfo
                    val ()=need (not (null (!tierCounts)) andalso List.all (fn count => count=hd (!tierCounts)) (!tierCounts),"cross JIT tiers disagree")
                    val ()=counts:=((if label="gmp" then "gmp" else "sml"),hd (!tierCounts)) :: !counts
                    val ()=rejected (run (name ^ "-" ^ label ^ "-limit") directory (common @ ["--intinf-max-bits","1024","limit.rbc"])) "intinf magnitude limit exceeded"
                    val ()=List.app (fn emulated => output (run (name ^ "-" ^ label ^ "-fork") directory
                         (common @ (if emulated then ["--emulate-fork"] else []) @ ["fork.rbc"])) "child pass\nparent pass\n") [false,true]
                    val ()=if label="sml" then () else
                      let val result=run (name ^ "-" ^ label ^ "-save") directory
                                      (common @ ["--intinf-max-bits","2048","--intinf-gmp-memory","8192","image.rbc"])
                          val ()=output result "saved\n"
                          val saved=path c (name ^ "-" ^ label ^ ".img")
                      in Incremental.copy (directory ^ "/saved.img") saved;images:=(name ^ "/" ^ label,saved) :: !images end
                in consumers:=(name ^ "/" ^ label,directory,common,label="gmp") :: !consumers end
              val ()=List.app backend [("gmp",vm,"gmp"),("sml",vm,"sml"),("free",freeVM,"auto")]
              val ()=rejected (run (name ^ "-unavailable-gmp") directory [freeVM,"--intinf=gmp","checks.rbc"]) "requested GMP backend is unavailable"
              val entry=Json.Object [("versions",Json.Object versions),("jit",Json.Bool jit),("counts",Json.Object (List.rev (!localCounts))),
                  ("native_stats",Json.Object (List.rev (!nativeStats))),("vm_sha256",Json.String (GMPChecks.hash vm)),("free_vm_sha256",Json.String (GMPChecks.hash freeVM))]
          in reports:=(name,entry) :: !reports;save "running";say ("PASS " ^ name ^ " arithmetic, limits, forks and image production\n") end
        val ()=List.app platform selected
        val ()=List.app (fn mode => let val values=List.map #2 (List.filter (fn (kind,_) => kind=mode) (!counts))
                  in need (not (null values) andalso List.all (fn value => value=hd values) values,"cross platform counts vary: " ^ mode) end) ["gmp","sml"]
        fun restore (producer,source) =
          let fun consumer (consumer,directory,common,gmp) =
                let val ()=Incremental.copy source (directory ^ "/restore.img")
                    fun limits (bits,memory)=
                      let val result=run "cross-restore" directory (common @ ["--intinf-max-bits",Int.toString bits,
                            "--intinf-gmp-memory",Int.toString memory,"--restore","restore.img"])
                          val expected="restored " ^ Bool.toString gmp ^ " " ^ Int.toString (Int.min (bits,2048)) ^ "\n"
                      in output result expected;need (String.isSubstring ("GMP memory limit " ^ Int.toString (Int.min (memory,8192)) ^ ",") (#errors result),
                                                         "saved/current memory cap did not narrow") end
                    val ()=List.app limits [(1024,4096),(4096,16384)]
                in imageReports:=Json.Object [("producer",Json.String producer),("consumer",Json.String consumer),
                        ("limits",Json.String "stricter saved and invocation pass")] :: !imageReports end
          in List.app consumer (List.rev (!consumers));save "running";say ("PASS " ^ producer ^ " restores on every consumer\n") end
        val ()=List.app restore (List.rev (!images))
    in save "pass";say ("PASS IntInf cross-platform: " ^ Int.toString (!(#sequence c)) ^ " bounded subprocesses\n") end
end
