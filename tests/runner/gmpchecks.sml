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
        val status=Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (64*1024*1024),core=SOME 0} (environment overrides o unsetEnv ["GMP","GMP_PREFIX","MAKEFLAGS","MFLAGS","MAKELEVEL"])
             {cmd=args,dir=SOME working,stdin="",stdout=prefix ^ ".stdout",stderr=prefix ^ ".stderr",timeout=timeout}
        val ()=write (prefix ^ ".status",Int.toString status ^ "\n")
    in need (status<>124,"GMP process timed out: " ^ label);
       {status=status,output=read (prefix ^ ".stdout"),errors=read (prefix ^ ".stderr"),prefix=prefix} end
  fun config (c : context) () =
    let val prefix=fromRoot "build/deps/gmp/native"
        val count=ref 0
        fun check name mode location enabled succeeded=
          let val directory=path c name
              val result=process c ("configure-" ^ name) root 90 [] (tool "GMP_CONFIGURATOR" "python3 scripts/configure-gmp.py"
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
end
