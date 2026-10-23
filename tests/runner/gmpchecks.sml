(* GMP tool policy is exercised through public CLIs and private artifacts;
   no test imports or mocks a Python production module. *)
structure GMPChecks =
struct
  open IntInfChecks
  fun tool key fallback=CommandWords.split (env (key,fallback))
  fun process (c : context) label working timeout overrides args : IntInfChecks.result =
    let val ()=mkdirs (#directory c)
        val ()= #sequence c := !(#sequence c)+1
        val prefix=path c (StringCvt.padLeft #"0" 3 (Int.toString (!(#sequence c))) ^ "-" ^ label)
        val ()=write (prefix ^ ".command.json",Json.encode (Json.Object [("argv",Json.Array (List.map Json.String args)),("cwd",Json.String working)]) ^ "\n")
        val status=Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (64*1024*1024),core=SOME 0} (environment overrides o List.filter (fn value => not (String.isPrefix "RUNEOPT_" value)) o unsetEnv ["GMP","GMP_PREFIX","MAKEFLAGS","MFLAGS","MAKELEVEL"])
             {cmd=args,dir=SOME working,stdin="",stdout=prefix ^ ".stdout",stderr=prefix ^ ".stderr",timeout=timeout}
        val ()=write (prefix ^ ".status",Int.toString status ^ "\n")
    in need (status<>124,"GMP process timed out: " ^ label);
       {status=status,output=read (prefix ^ ".stdout"),errors=read (prefix ^ ".stderr"),prefix=prefix} end
  fun config (c : context) () =
    let val prefix=fromRoot "build/deps/gmp/native"
        val count=ref 0
        fun check name mode location enabled succeeded=
          let val directory=path c name
              val result=process c ("configure-" ^ name) root 90 [] (tool "GMP_CONFIGURATOR" "bin/rune-build configure-gmp"
                   @ ["--mode",mode,"--prefix",location,"--out",directory])
              val ()=need ((#status result=0)=succeeded,"GMP configuration outcome differs: " ^ name ^ ": " ^ #errors result)
              val ()=if not succeeded then () else
                let val record=Json.decode (read (directory ^ "/config.json"))
                in case enabled of NONE => () | SOME expected => need (field "enabled" record=Json.Bool expected,"GMP enabled policy differs: " ^ name) end
          in count:= !count+1 end
        val ()=check "disabled" "no" (path c "missing") (SOME false) true
        val ()=check "auto-missing" "auto" (path c "missing") (SOME false) true
        val ()=check "required-missing" "yes" (path c "missing") (SOME false) false
        val ()=check "system" "auto" "" NONE true
        fun oldHeader text=
          let val changes=ref 0
              val prefix="#define __GNU_MP_VERSION_MINOR"
              fun line text=if not (String.isPrefix prefix text) then text else
                   let val tail=String.extract (text,size prefix,NONE)
                       val spaces=size tail-size (Substring.string (Substring.dropl Char.isSpace (Substring.full tail)))
                       val at=size prefix+spaces
                       val ()=need (at<size text andalso String.sub (text,at) = #"3","unexpected GMP minor-version fixture")
                   in changes:= !changes+1;String.substring (text,0,at) ^ "2" ^ String.extract (text,at+1,NONE) end
              val text=String.concatWith "\n" (List.map line (String.fields (fn ch => ch = #"\n") text))
          in need (!changes=1,"GMP header fixture did not have one version definition");text end
        val ()=if not (exists (prefix ^ "/rune-gmp.json")) then say "SKIP pinned GMP configuration fixtures: dependency not installed\n" else
          let val ()=check "pinned" "yes" prefix (SOME true) true
              val fake=path c "old-headers"
              val ()=(mkdirs (fake ^ "/include");mkdirs (fake ^ "/lib"))
              val ()=write (fake ^ "/include/gmp.h",oldHeader (read (prefix ^ "/include/gmp.h")))
              val ()=rmTree (fake ^ "/lib/libgmp.a")
              val ()=Posix.FileSys.symlink {old=prefix ^ "/lib/libgmp.a",new=fake ^ "/lib/libgmp.a"}
              val ()=check "auto-old" "auto" fake (SOME false) true
              val ()=check "required-old" "yes" fake (SOME false) false
              val ()=Incremental.copy (prefix ^ "/rune-gmp.json") (fake ^ "/rune-gmp.json")
          in check "altered-pinned" "yes" fake (SOME false) false end
    in say ("PASS GMP build configuration: " ^ Int.toString (!count) ^ " checks\n") end
  fun hash file=Hex.fromBytes (Sha256.digest (CachePlant.binary file))
  val platforms=["native","linux32","ppc64","aarch64","windows64","windows32"]
  fun dependency (c : context) requested requireAll () =
    let val ()=mkdirs (#directory c)
        val selected=if null requested then (if requireAll then platforms else ["native"]) else requested
        val ()=need (List.all (fn name => List.exists (fn x => x=name) platforms) selected,"unknown GMP dependency platform")
        val ()=mkdirs (#directory c)
        val records=ref [] : (string * Json.value) list ref
        fun platform name =
          let val prefix=fromRoot ("build/deps/gmp/" ^ name)
              val metadata=prefix ^ "/rune-gmp.json"
          in if not (exists metadata) then
               (need (not requireAll,"missing pinned GMP dependency: " ^ name);
                records:=(name,Json.Object [("result",Json.String "not installed")]) :: !records;
                say ("SKIP pinned GMP dependency " ^ name ^ ": not installed\n"))
             else
               let val record=Json.decode (read metadata)
                   val ()=List.app (fn (name,file) => need (hash file=string (field (name ^ "_sha256") record),"pinned GMP artifact differs: " ^ name))
                         [("header",prefix ^ "/include/gmp.h"),("library",prefix ^ "/lib/libgmp.a")]
                   val cfg=field "config" record
                   val ()=need (field "version" cfg=Json.String "6.3.0" andalso field "sha256" cfg=Json.String "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898",
                                  "GMP archive identity differs from pin")
                   val binary=path c (name ^ ".exe")
                   fun words key=CommandWords.split (string (field key cfg))
                   val commands=[words "cc" @ words "cflags" @ ["-I" ^ prefix ^ "/include",fromRoot "tests/intinf/gmp-division.c",prefix ^ "/lib/libgmp.a"]
                                      @ words "ldflags" @ ["-lm","-o",binary],words "runner" @ [binary]]
                   fun command (i,args)=
                     let val result=process c (name ^ "-" ^ Int.toString i) root 120 [] args
                         val ()=success result
                     in Json.Object [("stdout",Json.String (#output result)),("stderr",Json.String (#errors result))] end
                   val streams=List.map command (ListPair.zip (List.tabulate (length commands,fn i => i),commands))
                   val entry=Json.Object [("result",Json.String "pass"),("commands",Json.Array (List.map (Json.Array o List.map Json.String) commands)),
                        ("streams",Json.Array streams),("dependency",record),("binary_sha256",Json.String (hash binary))]
               in records:=(name,entry) :: !records;say ("PASS " ^ name ^ " pinned division regression\n") end
          end
        val ()=List.app platform selected
    in write (path c "report.json",Json.encode (Json.Object (List.rev (!records))) ^ "\n") end
  fun cpuFamily (c : context) selected () =
    let val selected=if null selected then ["qemu64","Conroe","Opteron_G1","max"] else selected
        val bytecode=semantic c (#smlVM c) ["--intinf=sml"]
        val version=run c "qemu-version" ["qemu-x86_64","--version"]
        val ()=success version
        val counts=ref [] : string list ref
        val entries=ref [] : (string * Json.value) list ref
        fun cpu name =
          let fun tier (level,flags)=
                let val args=["qemu-x86_64","-cpu",name,#vm c,"--intinf=gmp","--count","--intinf-stats"] @ flags @ [bytecode]
                    val result=process c ("cpu-" ^ name ^ "-" ^ level) root 180 [] args
                    val ()=output result "current: 1154 checks\noracle: 1154 checks\n"
                    val ()=correctStats result true
                    val count=case List.find (String.isPrefix "runevm: count: ") (lines (#errors result)) of SOME line => line | NONE => raise Failed "CPU family has no count"
                    val ()=counts:=count :: !counts
                in entries:=(name ^ "-" ^ level,Json.Object [("command",Json.Array (List.map Json.String args)),("exit",Json.Number (Int.toString (#status result))),("stdout",Json.String (#output result)),("stderr",Json.String (#errors result))]) :: !entries end
          in List.app tier [("off",["--jit=off"]),("1",["--jit=all","--jit-tier=1"]),("2",["--jit=all","--jit-tier=2"])] end
        val ()=List.app cpu selected
        val ()=need (not (null (!counts)) andalso List.all (fn count => count=hd (!counts)) (!counts),"IntInf counts vary between CPU families or JIT tiers")
        val report=Json.Object [("vm_sha256",Json.String (hash (#vm c))),("qemu",Json.String (case lines (#output version) of line :: _ => line | [] => "")),
              ("runs",Json.Object (List.rev (!entries))),("counts",Json.Array [Json.String (String.extract (hd (!counts),size "runevm: count: ",NONE))]),("bytecode_sha256",Json.String (hash bytecode)),("result",Json.String "pass")]
    in write (path c "report.json",Json.encode report ^ "\n");say "PASS GMP CPU families and JIT tiers\n" end
  fun sourceTree (c : context) =
    let val stage=path c "tree"
        val ()=mkdirs stage
        val tracked=process c "tracked-inputs" root 60 [] ["git","ls-files","-z"]
        val others=process c "untracked-inputs" root 60 [] ["git","ls-files","--others","--exclude-standard","-z"]
        val ()=(success tracked;success others)
        val files=String.fields (fn ch => ch = #"\000") (#output tracked ^ #output others)
        val ()=List.app (fn file => if file="" orelse not (exists (fromRoot file)) orelse isDir (fromRoot file) then () else
             (need (not (OS.Path.isAbsolute file) andalso not (String.isPrefix "../" file),"invalid source snapshot path");
              Incremental.copy (fromRoot file) (stage ^ "/" ^ file);
              Posix.FileSys.chmod (stage ^ "/" ^ file,Posix.FileSys.ST.mode (Posix.FileSys.stat (fromRoot file))))) files
        val ()=List.app (fn file => Incremental.copy (fromRoot file) (stage ^ "/" ^ file)) ["runtime/version.h","build/config.sml"]
    in stage end
  fun buildModes (c : context) prefix () =
    let val stage=sourceTree c
        val entries=ref [] : Json.value list ref
        fun one (name,mode,prefix,enabled,succeeded) =
          let val args=["make","bin/runevm","DOCTOR=no","JOBS=4","GMP=" ^ mode,"GMP_PREFIX=" ^ prefix]
              val result=process c name stage 180 [] args
              val ()=need ((#status result=0)=succeeded,"GMP Makefile mode outcome differs: " ^ name ^ ": " ^ #errors result)
              val record=[("name",Json.String name),("exit",Json.Number (Int.toString (#status result)))]
              val record=if not succeeded then record else
                let val vm=stage ^ "/bin/runevm"
                    val result=process c (name ^ "-version") stage 30 [] [vm,"--version"]
                    val ()=success result
                    val ()=need (String.isSubstring "GMP headers" (#output result)=enabled,"GMP Makefile switch did not change binary: " ^ name)
                in record @ [("version",Json.String (#output result)),("vm_sha256",Json.String (hash vm))] end
          in entries:= !entries @ [Json.Object record] end
        val ()=List.app one [("pinned","yes",fromRoot prefix,true,true),("disabled","no","",false,true),
              ("pinned-again","yes",fromRoot prefix,true,true),("automatic-missing","auto",path c "missing",false,true),
              ("required-missing","yes",path c "missing",false,false)]
    in write (path c "report.json",Json.encode (Json.Array (!entries)) ^ "\n");say "PASS isolated GMP Makefile mode switches\n" end
end
